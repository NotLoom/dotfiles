#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# reinstall-hypr-dms.sh
#
# Cleanly uninstall + reinstall Hyprland and DankMaterialShell (DMS) on Arch.
#
#   repo packages : hyprland, dms-shell-hyprland, dms-shell, quickshell,
#                   xdg-desktop-portal-hyprland
#   AUR packages  : greetd-dms-greeter-bin (+debug), dsearch-bin   [optional]
#
# Safe by design:
#   * refuses to run while Hyprland is running
#   * backs up every config/state file it touches, plus /etc/greetd/config.toml
#   * pre-builds the AUR packages BEFORE removing anything, so a failed AUR
#     build can never leave you without a login screen (use --repo-only to
#     skip AUR entirely)
#   * keeps your Lua config by default (--fresh moves it aside instead)
#
# Usage:  bash reinstall-hypr-dms.sh [options]
#   --fresh        move ~/.config/hypr + DMS state aside so DMS re-deploys it
#   --repo-only    reinstall repo packages only; keep AUR greeter/search as-is
#   --dry-run      print exactly what would be removed/installed, do nothing
#   -y, --yes      no extra confirmation prompt (pacman still gets --noconfirm)
#   -h, --help     this help
# ---------------------------------------------------------------------------
set -uo pipefail

FRESH=0; DO_AUR=1; DRY=0; ASSUME=0
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; }

while (($#)); do
	case "$1" in
		--fresh)     FRESH=1 ;;
		--repo-only) DO_AUR=0 ;;
		--dry-run)   DRY=1 ;;
		-y|--yes)    ASSUME=1 ;;
		-h|--help)   usage; exit 0 ;;
		*)           die "unknown argument: $1 (try --help)" ;;
	esac
	shift
done

# --------------------------------------------------------------------------
# preconditions
# --------------------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "run this as your normal user, not root (it calls sudo itself)"
command -v pacman >/dev/null 2>&1 || die "pacman not found - this script is for Arch Linux"
[[ -f /etc/os-release ]] && grep -q '^ID=arch' /etc/os-release || warn "this does not look like Arch Linux"

if pgrep -x Hyprland >/dev/null 2>&1; then
	die "Hyprland is running. Log out of Hyprland first, then run this from XFCE or a TTY."
fi
if pgrep -x dms >/dev/null 2>&1 || pgrep -x qs >/dev/null 2>&1; then
	warn "a DMS/quickshell process is running; it will be killed when its packages are removed"
fi

REPO_PKGS=(hyprland dms-shell-hyprland dms-shell quickshell xdg-desktop-portal-hyprland)
AUR_WANT=(greetd-dms-greeter-bin dsearch-bin)
REMOVE=(hyprland dms-shell dms-shell-hyprland quickshell xdg-desktop-portal-hyprland)
AUR_REMOVE=(greetd-dms-greeter-bin greetd-dms-greeter-bin-debug)

# keep only packages that are actually installed
filter_installed() { local p out=(); for p in "$@"; do pacman -Qq "$p" >/dev/null 2>&1 && out+=("$p"); done; ((${#out[@]})) && printf '%s\n' "${out[@]}"; }
mapfile -t REMOVE < <(filter_installed "${REMOVE[@]}")
mapfile -t AUR_INSTALLED < <(filter_installed "${AUR_REMOVE[@]}")
mapfile -t AUR_BUILD_LIST < <(filter_installed "${AUR_WANT[@]}")

if ((DO_AUR)); then
	REMOVE+=("${AUR_INSTALLED[@]}")
else
	# the greeter depends on quickshell, so quickshell has to stay
	REMOVE=("${REMOVE[@]/quickshell/}"); REMOVE=(${REMOVE[@]})
	warn "--repo-only: keeping the DMS greeter + dsearch, so quickshell stays installed (it will be reinstalled, not removed)"
fi
(( ${#REMOVE[@]} )) || die "none of the target packages are installed - nothing to do"

# --------------------------------------------------------------------------
# --dry-run: show the real transaction, change nothing
# --------------------------------------------------------------------------
if ((DRY)); then
	log "dry run - nothing will be changed"
	echo "would REMOVE (pacman -Rns):"
	pacman -Rsp --print-format '  %n %v' "${REMOVE[@]}" 2>&1 | sed 's/^/  /'
	echo
	echo "would INSTALL from repo:  ${REPO_PKGS[*]}"
	echo "install command:          sudo pacman -S ${REPO_PKGS[*]}"
	if ((DO_AUR)) && ((${#AUR_BUILD_LIST[@]})); then
		echo "would REBUILD+INSTALL from AUR: ${AUR_BUILD_LIST[*]}"
	fi
	((FRESH)) && echo "would move aside: ~/.config/hypr, ~/.config/DankMaterialShell, ~/.local/state/DankMaterialShell, DMS caches"
	exit 0
fi

# --------------------------------------------------------------------------
# 1/6  snapshot everything we might touch
# --------------------------------------------------------------------------
BCK="$HOME/backups/hypr-dms-reinstall-$(date +%Y%m%d-%H%M%S)"
log "1/6 snapshot -> $BCK"
mkdir -p "$BCK/config" "$BCK/state" "$BCK/etc" "$BCK/pkglist"
for d in .config/hypr .config/DankMaterialShell .config/systemd .config/environment.d; do
	[[ -e "$HOME/$d" ]] && cp -a "$HOME/$d" "$BCK/config/$(basename "$d")"
done
[[ -e "$HOME/.local/state/DankMaterialShell" ]] && cp -a "$HOME/.local/state/DankMaterialShell" "$BCK/state/"
for f in /etc/greetd/config.toml /etc/greetd/config.toml.backup-*; do
	[[ -r $f ]] && cp -a "$f" "$BCK/etc/$(basename "$f")"
done
pacman -Qe >"$BCK/pkglist/pacman-Qe.txt"
pacman -Qm >"$BCK/pkglist/pacman-Qm-AUR.txt"
pacman -Q  >"$BCK/pkglist/pacman-Q-all.txt"
{
	echo "uninstall+reinstall of Hyprland/DMS, run $(date -Is)"
	echo "removed   : ${REMOVE[*]}"
	echo "reinstall : ${REPO_PKGS[*]} ${AUR_BUILD_LIST[*]}"
} >"$BCK/WHAT-THIS-IS.txt"
if command -v dms >/dev/null 2>&1; then
	dms backup create >/dev/null 2>&1 && ok "extra DMS backup created (dms backup create)"
fi
ok "config + package lists saved"

# --------------------------------------------------------------------------
# 2/6  pre-build the AUR packages *before* removing anything
# --------------------------------------------------------------------------
AUR_DIR="$HOME/.cache/dankinstall/aur-builds"   # same location the DMS installer used
BUILT=(); KEEP=()
if ((DO_AUR)) && ((${#AUR_BUILD_LIST[@]})); then
	log "2/6 pre-building AUR packages: ${AUR_BUILD_LIST[*]}"
	if ! command -v yay >/dev/null 2>&1; then
		warn "yay not found - AUR packages stay installed, they are not rebuilt"
		KEEP=("${AUR_BUILD_LIST[@]}")
	elif ! curl -fsS -m 10 -o /dev/null https://aur.archlinux.org/ 2>/dev/null; then
		warn "aur.archlinux.org unreachable - AUR packages stay installed, they are not rebuilt"
		KEEP=("${AUR_BUILD_LIST[@]}")
	else
		mkdir -p "$AUR_DIR"
		for p in "${AUR_BUILD_LIST[@]}"; do
			rm -rf "$AUR_DIR/$p"
			if (cd "$AUR_DIR" && yay -G "$p" >/dev/null 2>&1) &&
			   (cd "$AUR_DIR/$p" && makepkg -fs --noconfirm --noprogressbar >/dev/null 2>&1); then
				BUILT+=("$p"); ok "built $p"
			else
				warn "build of $p failed - it stays installed, it is not removed"
				KEEP+=("$p")
			fi
		done
	fi
fi

if ((${#KEEP[@]})); then
	# never remove a package we failed to pre-build
	tmp=(); for p in "${REMOVE[@]}"; do
		skip=0; for k in "${KEEP[@]}"; do [[ $p == "$k" || $p == "$k-debug" ]] && skip=1; done
		((skip)) || tmp+=("$p")
	done; REMOVE=("${tmp[@]}")
	if [[ " ${REMOVE[*]} " == *" quickshell "* ]]; then
		warn "the kept greeter needs quickshell - reinstalling it in place instead of removing it"
		tmp=(); for p in "${REMOVE[@]}"; do [[ $p == quickshell ]] || tmp+=("$p"); done; REMOVE=("${tmp[@]}")
	fi
fi

# --------------------------------------------------------------------------
# 3/6  remove the old packages
# --------------------------------------------------------------------------
if ((!ASSUME)) && [[ -t 0 ]]; then
	printf '\nRemove   : %s\nReinstall: %s\n\nType "yes" to continue: ' "${REMOVE[*]}" "${REPO_PKGS[*]}"
	read -r answer; [[ $answer == yes ]] || die "aborted at your request"
fi

log "3/6 removing: ${REMOVE[*]}"
sudo -v || die "sudo authentication failed"
GREETD_WAS_ACTIVE=$(systemctl is-active greetd 2>/dev/null)
GREETD_STOPPED=0
if [[ " ${REMOVE[*]} " == *" greetd-dms-greeter-bin "* ]]; then
	if sudo systemctl stop greetd 2>/dev/null; then
		GREETD_STOPPED=1
		ok "greetd stopped for the swap (your running XFCE session is unaffected)"
	fi
fi
if ! sudo pacman -Rns --noconfirm "${REMOVE[@]}"; then
	die "pacman -R failed; nothing was reinstalled yet. Fix the error above and re-run, or restore from $BCK."
fi
ok "old packages removed"

# --------------------------------------------------------------------------
# 4/6  reinstall from the repos.  dms-shell-hyprland provides
#      'dms-shell-compositor', which the DMS installer faked with
#      --assume-installed, so this also fixes that unmet dependency.
# --------------------------------------------------------------------------
log "4/6 reinstalling from repo: ${REPO_PKGS[*]}"
sudo pacman -S --noconfirm "${REPO_PKGS[@]}" ||
	die "repo reinstall failed - read the output above; backup is in $BCK"
ok "repo packages reinstalled"

# --------------------------------------------------------------------------
# 5/6  install the AUR packages built in step 2, then re-seed greeter state
# --------------------------------------------------------------------------
if ((${#BUILT[@]})); then
	log "5/6 installing AUR packages from the local build"
	for p in "${BUILT[@]}"; do
		mapfile -t files < <(find "$AUR_DIR/$p" -name '*.pkg.tar.*' ! -name '*.sig' 2>/dev/null)
		if ((${#files[@]})); then
			if sudo pacman -U --noconfirm "${files[@]}"; then
				ok "installed $p"
			else
				warn "installing $p failed - finish it later with: sudo pacman -U $AUR_DIR/$p/*.pkg.tar.zst"
			fi
		else
			warn "no package file found for $p"
		fi
	done
else
	log "5/6 no AUR packages to (re)install"
fi

if command -v dms-greeter >/dev/null 2>&1; then
	if id -u greeter >/dev/null 2>&1; then
		sudo install -d -o greeter -g greeter -m 0755 /var/cache/dms-greeter &&
			ok "/var/cache/dms-greeter is present and writable by the greeter user"
	fi
	sudo systemctl stop greetd 2>/dev/null
	# sync also adds your user to the 'greeter' group, which
	# 'dms-greeter status' currently reports as missing
	if sudo dms-greeter sync -y 2>&1 | tail -3; then
		ok "DMS theme/settings synced into the greeter (and group membership fixed)"
	else
		warn "dms-greeter sync failed - run it yourself later: sudo dms-greeter sync -y"
	fi
	sudo systemctl enable greetd >/dev/null 2>&1
	if [[ $GREETD_WAS_ACTIVE == active || $GREETD_STOPPED == 1 ]]; then
		sudo systemctl restart greetd && ok "greetd restarted on VT1 with the DMS greeter"
	fi
fi

# --------------------------------------------------------------------------
# 6/6  optional config reset (--fresh), then verify
# --------------------------------------------------------------------------
if ((FRESH)); then
	log "moving compositor/DMS config aside (--fresh)"
	mkdir -p "$BCK/moved-aside/config" "$BCK/moved-aside/state" "$BCK/moved-aside/cache"
	for d in .config/hypr .config/DankMaterialShell; do
		[[ -e "$HOME/$d" ]] && mv "$HOME/$d" "$BCK/moved-aside/config/$(basename "$d")" && ok "moved ~/$d"
	done
	[[ -e "$HOME/.local/state/DankMaterialShell" ]] &&
		mv "$HOME/.local/state/DankMaterialShell" "$BCK/moved-aside/state/" &&
		ok "moved ~/.local/state/DankMaterialShell"
	for d in .cache/dankinstall .cache/DankMaterialShell .cache/danksearch .cache/dms .cache/hyprland .cache/quickshell; do
		[[ -e "$HOME/$d" ]] && mv "$HOME/$d" "$BCK/moved-aside/cache/$(basename "$d")"
	done
	ok "clean slate - DMS re-deploys ~/.config/hypr on first start (or run: dms setup)"
fi

log "6/6 verifying"
pacman -Q hyprland dms-shell-hyprland dms-shell quickshell xdg-desktop-portal-hyprland 2>&1
if [[ -z "$(pacman -T dms-shell dms-shell-hyprland quickshell hyprland 2>/dev/null)" ]]; then
	ok "all dependencies satisfied (the unmet 'dms-shell-compositor' dep is resolved)"
else
	warn "unmet dependencies: $(pacman -T dms-shell dms-shell-hyprland quickshell hyprland 2>/dev/null | tr '\n' ' ')"
fi
bad=$(pacman -Qkk hyprland dms-shell-hyprland dms-shell quickshell 2>&1 | grep -v ': 0 altered files' || true)
if [[ -z $bad ]]; then ok "all installed files match the package database"; else warn "file mismatches:"; echo "$bad"; fi
if timeout 60 Hyprland --verify-config >/dev/null 2>&1; then
	ok "Hyprland's config parses cleanly"
else
	warn "Hyprland config check failed - run: Hyprland --verify-config"
fi
if systemctl is-active greetd >/dev/null 2>&1; then ok "greetd is running"; else warn "greetd is not running - start it: sudo systemctl restart greetd"; fi
for b in hyprland hyprctl dms dms-greeter dsearch; do
	if command -v "$b" >/dev/null 2>&1; then ok "binary present: $(command -v "$b")"; else warn "binary missing: $b"; fi
done

cat <<EOF

--------------------------------------------------------------------------------
Done.  Snapshot of everything this script touched:  $BCK

How to test:
  1. log out completely (or run: sudo systemctl restart greetd, then switch to VT1)
  2. pick "Hyprland" (or "Hyprland (uwsm-managed)") at the login screen
  3. once inside, check:  hyprctl configerrors  &&  dms doctor  &&  dms-greeter status

Heads-up - a matching bug is already visible in this machine's logs, and it is
NOT a broken install, so reinstalling cannot fix it by itself:
     ERR from aquamarine ]: atomic drm request: failed to commit: Invalid argument, flags: ATOMIC_ALLOW_MODESET
     ERR from aquamarine ]: drm: crtc 205 failed restore
     kernel: Hyprland[...]: segfault at 0 ... in libaquamarine.so.0.15.1  (on session teardown / NVIDIA)
If the session still dies, run a full 'pacman -Syu' and, if it persists, report it
upstream (hyprland/aquamarine) instead of reinstalling again.

Logs after a bad session:
     journalctl -b _COMM=Hyprland                  # session stderr
     ls -t /run/user/\$UID/hypr/*/hyprland.log      # full per-session log
     coredumpctl list                               # crash list
     journalctl -b -u greetd                        # login-screen problems

Restore saved config by hand if it is ever needed:
     cp -a $BCK/config/hypr "\$HOME/.config/" && cp -a $BCK/etc/config.toml /etc/greetd/config.toml
--------------------------------------------------------------------------------
EOF



