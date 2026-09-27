-- DMS Window Rules — managed by DankMaterialShell
-- Do not edit manually; changes may be overwritten

-- DMS-RULE: id=dms_rule_0, name=
hl.window_rule({ match = { class = "^settings-editor$" }, float = true })

-- DMS-RULE: id=dms_rule_1, name=
hl.window_rule({ match = { class = "^(org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" }, float = true })

-- DMS-RULE: id=dms_rule_2, name=
hl.window_rule({ match = { class = "^(nm-connection-editor|nm-applet)$" }, float = true })

-- DMS-RULE: id=dms_rule_3, name=
hl.window_rule({ match = { class = "^blueman-manager$" }, float = true })

-- DMS-RULE: id=dms_rule_4, name=
hl.window_rule({ match = { class = "^xdg-desktop-portal-gtk$" }, float = true })

-- DMS-RULE: id=dms-floating-windows, name=DMS Floating Windows
hl.window_rule({ match = { class = "^com.danklinux.dms$" }, float = true })
