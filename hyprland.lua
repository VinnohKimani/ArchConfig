-- Hyprland loads this file when it is started without a config, and it prefers
-- it over hyprland.conf. HyDE loads it too, last, as the override layer below.
-- The block keeps the two apart: hyde.lua sets `hyde` on its first line, so it
-- runs only when this file is the entry point and HyDE has not been loaded.
if not hyde then
    local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
    local entry = share .. "/hypr/hyde.lua"
    local handle = io.open(entry, "r")
    if not handle then
        error("HyDE is not installed at " .. entry .. ". Run install.sh -r, or point Hyprland at your own config.")
    end
    handle:close()
    dofile(entry)
    return
end

-- ============================================================================
-- MacBook Pro 2015 (MacBookPro12,1) — User Overrides & Keybindings (HyDE Lua)
-- ============================================================================

local MOD = hyde.config.modifiers.main -- "SUPER"

-- ----------------------------------------------------------------------------
-- 1. MONITORS & COMPACT SCALING
-- ----------------------------------------------------------------------------
-- Internal Retina Display (2560x1600): 1.6 scale yields an exact 1600x1000
-- integer logical grid (down from the oversized scale=2.0 auto default).
hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@60",
    position = "0x0",
    scale    = 1.6,
})

-- External Monitors & Projectors: Strict integer scale 1 to prevent Intel Iris
-- KMS DRM page-flip commit lockups ("Cannot commit when a page-flip is awaiting").
for _, ext in ipairs({ "HDMI-A-1", "HDMI-A-2", "DP-1", "DP-2", "" }) do
    hl.monitor({
        output   = ext,
        mode     = "preferred",
        position = "auto",
        scale    = 1,
    })
end

-- ----------------------------------------------------------------------------
-- 2. COMPACT UI SIZING, GAPS & DEFAULT APPS
-- ----------------------------------------------------------------------------
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")

hyde.config.ui.cursor_size = 20
hyde.config.ui.font_size = 9
hyde.config.ui.document_font_size = 9
hyde.config.ui.monospace_font_size = 8

-- Primary Browser & IDE shortcuts (Super + B / Super + C)
hyde.config.app.browser = "hyde-shell open --fall brave web-browser"
hyde.config.app.editor  = "hyde-shell open --fall antigravity code-editor"

hl.config({
    general = {
        gaps_in           = 3,
        gaps_out          = 6,
        border_size       = 1,
        resize_on_border  = true,
        allow_tearing     = false,
        layout            = "dwindle",
    },
    decoration = {
        rounding          = 8,
        rounding_power    = 2,
        active_opacity    = 0.96,
        inactive_opacity  = 0.88,
        fullscreen_opacity = 1.0,
    },
})

-- ----------------------------------------------------------------------------
-- 2B. macOS ANIMATIONS (SMOOTH WORKSPACE SWITCH & APP LAUNCH/QUIT)
-- ----------------------------------------------------------------------------
hl.curve("macOpen",   { type = "spring", mass = 1, stiffness = 110, dampening = 16 })
hl.curve("macBounce", { type = "spring", mass = 1, stiffness = 80,  dampening = 10 })
hl.curve("macSmooth", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1.0} } })

hl.animation({ leaf = "windows",          enabled = true, speed = 8, spring = "macOpen",   style = "popin 90%" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 8, spring = "macOpen",   style = "popin 90%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 7, spring = "macBounce", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 5, bezier = "macSmooth", style = "slide" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 6, bezier = "macSmooth", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesIn",     enabled = true, speed = 6, bezier = "macSmooth", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesOut",    enabled = true, speed = 6, bezier = "macSmooth", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "macSmooth", style = "slidefade 20%" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade",             enabled = true, speed = 8, bezier = "default" })

-- ----------------------------------------------------------------------------
-- 3. MACBOOK TRACKPAD (bcm5974) CALIBRATION & ANTI-TAB-DRAG FIX
-- ----------------------------------------------------------------------------
-- Disables tap-and-drag and drag_lock so tapping tabs never tears them into
-- new windows. Uses adaptive acceleration (0.2 sensitivity) for smooth cursor
-- control instead of HyDE's flat profile.
hl.config({
    input = {
        kb_layout       = "us",
        follow_mouse    = 1,
        natural_scroll  = true,
        sensitivity     = 0.2,
        accel_profile   = "adaptive",

        touchpad = {
            natural_scroll          = true,
            tap_to_click            = true,
            tap_and_drag            = false,
            drag_lock               = 0,
            scroll_factor           = 1.0,
            clickfinger_behavior    = true,
            disable_while_typing    = true,
            middle_button_emulation = true,
        },
    },
})

hl.device({
    name           = "bcm5974",
    natural_scroll = true,
    sensitivity    = 0.2,
    accel_profile  = "adaptive",
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- ----------------------------------------------------------------------------
-- 4. STARTUP DAEMONS
-- ----------------------------------------------------------------------------
hl.on("hyprland.start", function()
    -- Realtime event-driven MagSafe charger plug/unplug notifier
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/battery-monitor.sh")
    -- Ensure sound card is on Analog Stereo Duplex (not Pro Audio) and route via MacBook DSP EQ
    hl.exec_cmd("pactl set-card-profile alsa_card.pci-0000_00_1b.0 output:analog-stereo+input:analog-stereo && pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-stereo 100% && pactl set-default-sink effect_input.macbook_dsp")
end)

-- ----------------------------------------------------------------------------
-- 5. KEYBINDINGS & MACBOOK HARDWARE KEYS
-- ----------------------------------------------------------------------------

-- A. Screen Brightness (Physical F1 / F2 keys — works directly without fn/Super)
-- Calls brightnesscontrol.sh which adjusts intel_backlight and sends an interactive
-- Dunst notification with +/- delta, percentage, and progress bar.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("hyde-shell brightnesscontrol i"), {
    description = "[Hardware Controls|Brightness] increase screen brightness (+5%)",
    locked      = true,
    repeating   = true,
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("hyde-shell brightnesscontrol d"), {
    description = "[Hardware Controls|Brightness] decrease screen brightness (-5%)",
    locked      = true,
    repeating   = true,
})

-- B. Keyboard Backlight (Physical F5 / F6 keys — works directly without fn/Super)
-- Calls kbd_brightnesscontrol.sh which adjusts smc::kbd_backlight and sends an
-- interactive Dunst notification with +/- delta, percentage, and progress bar.
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("hyde-shell kbd_brightnesscontrol i"), {
    description = "[Hardware Controls|Brightness] increase keyboard backlight (+10%)",
    locked      = true,
    repeating   = true,
})
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("hyde-shell kbd_brightnesscontrol d"), {
    description = "[Hardware Controls|Brightness] decrease keyboard backlight (-10%)",
    locked      = true,
    repeating   = true,
})

-- C. MacBook Mission Control (F3) & Launchpad (F4) physical keys
hl.bind("XF86LaunchA", hl.dsp.exec_cmd(hyde.sh.menu.windows()), {
    description = "[Launcher|MacBook Keys] Mission Control window switcher",
})
hl.bind("XF86LaunchB", hl.dsp.exec_cmd(hyde.sh.menu.apps()), {
    description = "[Launcher|MacBook Keys] Launchpad application finder",
})

-- D. External Display & Projector Mode Switcher (Super + P)
-- Matches `locked = true` from key_binds.lua so hyde.binds.dedup unbinds the old Super + P
hl.bind(MOD .. " + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/display-switch.sh"), {
    description = "[Hardware Controls|Display] projector & monitor mode switcher",
    locked      = true,
})

-- E. Screenshot Shortcuts (Super + Shift + S for Snip, Print for Fullscreen)
-- Auto-saves to ~/Pictures/Screenshots/, copies to clipboard, and notifies.
-- Unbinds the default scratchpad move on Super + Shift + S first, then binds screenshot snip.
hl.unbind(MOD .. " + SHIFT + S")
hl.bind(MOD .. " + SHIFT + S", hl.dsp.exec_cmd(hyde.sh.screenshot.snip()), {
    description = "[Utilities|Screenshot] snip area to clipboard & ~/Pictures/Screenshots",
})
-- Preserve moving focused window to scratchpad on Super + Ctrl + Shift + S
hl.bind(MOD .. " + CTRL + SHIFT + S", hl.dsp.window.move({ workspace = "special" }), {
    description = "[Workspaces|Special workspace] move focused window to scratchpad",
})

-- F. Screen Recording (Super + Alt + R)
hl.bind(MOD .. " + ALT + R", hl.dsp.exec_cmd("obs --startrecording"), {
    description = "[Utilities] start OBS screen recording",
})

-- G. Smart Floating Window Toggle + Center (Super + Alt + W)
local toggle_float_center = function()
    hl.dsp.window.float({ action = "toggle" })()
    local win = hl.get_active_window()
    if win and win.floating then
        hl.dsp.window.resize({ width = "80%", height = "80%" })()
        hl.dsp.window.center()()
    end
end
hl.bind(MOD .. " + ALT + W", toggle_float_center, {
    description = "[Window Management] toggle float, resize 80% & center",
})

-- H. Interactive Notification Controls (Super + N / Super + Shift + N)
hl.bind(MOD .. " + N", hl.dsp.exec_cmd("dunstctl close-all"), {
    description = "[Notifications] dismiss all notifications",
})
hl.bind(MOD .. " + SHIFT + N", hl.dsp.exec_cmd("dunstctl history-pop"), {
    description = "[Notifications] recall last notification from history",
})

-- I. Laptop Lid Switch -> Guarded Safe Suspend
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/safe-suspend.sh"), {
    description = "[Hardware Controls|Power] guarded suspend on lid close",
    locked      = true,
})
