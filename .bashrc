#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
source /usr/share/nvm/init-nvm.sh

# --- dotfiles backup --------------------------------------------------------
# The backup repo lives in ~/.dotfiles (git dir) and tracks files in place in
# $HOME (work tree), so nothing is copied or symlinked. See ~/.dotfiles/README.md
dotfiles() { command git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" "$@"; }

# Commit changes to already-tracked dotfiles and push the backup to the remote.
dotfiles-save() {
	local msg="${1:-update $(date '+%Y-%m-%d %H:%M')}"
	if dotfiles diff --quiet --cached && dotfiles diff --quiet; then
		echo "dotfiles: nothing to commit"
	else
		dotfiles add --update &&
			dotfiles commit --quiet --message "dotfiles: $msg" &&
			echo "dotfiles: committed ($msg)"
	fi
	if dotfiles remote get-url origin >/dev/null 2>&1; then
		dotfiles push --quiet origin main &&
			echo "dotfiles: synced with $(dotfiles remote get-url origin)"
	fi
}
