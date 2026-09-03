-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "3840x2160@60", position = "auto", scale = omarchy_monitor_scale })

-- TCL 4K TV over HDMI: 10-bit color (less banding), keep fixed 60Hz for low latency.
-- NOTE: VRR deliberately NOT enabled — TCL TVs over HDMI don't reliably support
-- adaptive sync and enabling it can cause flicker/black-screen instability.
hl.monitor({ output = "HDMI-A-2", mode = "3840x2160@60", position = "0x0", scale = omarchy_monitor_scale, bitdepth = 10 })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
