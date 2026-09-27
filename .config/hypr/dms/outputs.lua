-- Monitor layout — the DMS "outputs" fragment.
--
-- Normally written by DMS from its Display settings; this copy was rebuilt by
-- hand on 2026-09-27 after ~/.config/hypr was lost, and switched to the high
-- refresh mode the same day.
--
-- The only connected output is the internal panel (AUO 184X2.B156HAN). Its EDID
-- advertises exactly two modes:
--     1920x1080  60.10 Hz   (base block, EDID-preferred)
--     1920x1080 165.01 Hz   (DisplayID block; panel range 60-165 Hz)
-- so `mode` below is the 165 Hz one, at native scale.
--
-- vrr is deliberately not set; add `vrr = 1` if you want variable refresh
-- (it can flicker on some internal panels).

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@165.01",
    position = "0x0",
    scale    = 1.0,
})
