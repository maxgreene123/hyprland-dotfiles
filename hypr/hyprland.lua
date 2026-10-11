-- Monitors

local monMain = "DP-2"     -- 1080p280, workspaces 1-10
local monSide = "HDMI-A-1" -- 4K60, workspaces 11-20

-- The EDID mode list omits this 280 Hz timing.
hl.monitor({ output = monMain, mode = "modeline 628 1920 1968 2028 2040 1080 1090 1092 1100 +hsync -vsync", position = "0x123", scale = 1, vrr = 1 })
hl.monitor({ output = monSide, mode = "3840x2160@60", position = "1920x0", scale = 1.5 })

-- Programs

local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"
local terminal = "uwsm app -- alacritty"
local defaultApp = "python3 " .. string.format("%q", home .. "/.config/quickshell/scripts/desktop_bridge.py") .. " --launch-role "
local fileManager = defaultApp .. "files"
local browser = defaultApp .. "browser"
local editor = defaultApp .. "editor"
local menu = "quickshell ipc call shell launcher"

-- Autostart

hl.on("hyprland.start", function()
    -- Bridge legacy tray icons to SNI.
    hl.exec_cmd("uwsm app -- xembedsniproxy")
    hl.exec_cmd("uwsm app -- blueman-applet")
    hl.exec_cmd("uwsm app -- wl-gammarelay-rs")
    hl.exec_cmd("uwsm app -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("uwsm app -- hyprpaper")
    hl.exec_cmd("systemctl --user start quickshell.service")
    hl.exec_cmd("uwsm app -- tailscale systray")
end)

-- Environment

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Appearance and rendering

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        layout        = "dwindle",
        allow_tearing = true,
    },

    decoration = {
        rounding = 1,

        blur = { enabled = false },
        shadow = { enabled = false },
    },

    animations = {
        enabled = false,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
    },

    render = {
        direct_scanout = true,
    },

    cursor = {
        no_hardware_cursors = true,
    },

    xwayland = {
        force_zero_scaling = true,
        use_nearest_neighbor = false,
    },
})

-- Plugins

local csgoPlugin = home .. "/.local/lib/hyprland/libhyprcsgo.so"
local csgoFile = io.open(csgoPlugin, "r")
if csgoFile then
    csgoFile:close()
    hl.plugin.load(csgoPlugin)
end

if hl.plugin.csgo_vulkan_fix then
    hl.config({
        plugin = {
            csgo_vulkan_fix = {
                fix_mouse = true,
            },
        },
    })

    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "cs2", w = 1280, h = 960 })
end

-- Input

hl.config({
    input = {
        kb_layout     = "us",
        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "flat",

        touchpad = {
            natural_scroll       = true,
            clickfinger_behavior = 1,
        },
    },
})

-- Keybindings

local mainMod = "SUPER"

-- Applications
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("uwsm app -- " .. scripts .. "/screenshot.sh"))

-- Quickshell panels
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("quickshell ipc call shell notifications"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("quickshell ipc call shell settings"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("quickshell ipc call shell dashboard"))

-- Window management
dofile(scripts .. "/altswitch.lua")

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Session
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mainMod .. " + CTRL + Q",  hl.dsp.exec_cmd("uwsm app -- /usr/bin/hyprlock"))

-- Colour temperature
local function gammaTemp(kelvin)
    return hl.dsp.exec_cmd(
        "busctl --user -- set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q " .. kelvin
    )
end
hl.bind(mainMod .. " + SHIFT + N", gammaTemp(2500))
hl.bind(mainMod .. " + SHIFT + M", gammaTemp(6500))

-- Vibrance
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.exec_cmd(scripts .. "/vibrance.sh on"))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd(scripts .. "/vibrance.sh off"))

-- Move windows
local moveKeys = { a = "l", d = "r", w = "u", s = "d" }
for key, direction in pairs(moveKeys) do
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

-- Resize windows
local resizeKeys = {
    left  = { x = -40, y =   0 },
    right = { x =  40, y =   0 },
    up    = { x =   0, y = -40 },
    down  = { x =   0, y =  40 },
}
for key, delta in pairs(resizeKeys) do
    hl.bind(mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.resize({ x = delta.x, y = delta.y, relative = true }))
end

-- ALT selects side-monitor workspaces; SHIFT moves windows.
for i = 1, 10 do
    local key = i % 10

    hl.bind(mainMod .. " + " .. key,               hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,       hl.dsp.window.move({ workspace = i }))

    hl.bind(mainMod .. " + ALT + " .. key,         hl.dsp.focus({ workspace = i + 10 }))
    hl.bind(mainMod .. " + ALT + SHIFT + " .. key, hl.dsp.window.move({ workspace = i + 10 }))
end

-- Windows and workspaces

for ws = 1, 10 do
    hl.workspace_rule({ workspace = ws, monitor = monMain, default = ws == 1, persistent = ws == 1 })
end

for ws = 11, 20 do
    hl.workspace_rule({ workspace = ws, monitor = monSide, default = ws == 11, persistent = ws == 11 })
end

hl.window_rule({
    name       = "cs2",
    match      = { class = "cs2" },
    immediate  = true,
    fullscreen = true,
})
