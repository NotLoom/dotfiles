-- Cursor theme overrides — the DMS "cursor" fragment.
--
-- Normally written by DMS (Settings → Cursor). The values below are what its
-- live settings still report: theme "System Default", size 24.

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    cursor = {
        sync_gsettings_theme = true,
    },
})
