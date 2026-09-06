-- Monitors

local monMain = "DP-2"       -- 1080p144, workspaces 1-10
local monSide = "HDMI-A-1"   -- 4K60,     workspaces 11-20

hl.monitor({ output = monMain, mode = "1920x1080@144", position = "0x0",    scale = 1 })
hl.monitor({ output = monSide, mode = "3840x2160@60",  position = "1920x0", scale = 1.5 })

hl.config({
    xwayland = {
        force_zero_scaling = true,
        use_nearest_neighbor = false,
    },
})

-- My programs

local terminal    = "uwsm app -- alacritty"
local fileManager = "uwsm app -- thunar"
local browser     = "uwsm app -- brave-origin"
local editor      = "uwsm app -- zeditor"
local menu        = 'rofi -show drun -show-icons -run-command "uwsm app -- {cmd}"'

local scripts     = os.getenv("HOME") .. "/.config/hypr/scripts"

-- Autostart

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- blueman-applet")
    hl.exec_cmd("uwsm app -- mako")
    hl.exec_cmd("uwsm app -- wl-gammarelay-rs")
    hl.exec_cmd("uwsm app -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("uwsm app -- hyprpaper")
    hl.exec_cmd("uwsm app -- waybar")
    hl.exec_cmd("uwsm app -- tailscale systray")
end)

-- Environment variables

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Look and feel

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

        blur = {
            enabled = false,
            size    = 3,
            passes  = 1,
        },

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
    },

    animations = {
        enabled = false,
    },
})

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-- Misc

hl.config({
    misc = {
        force_default_wallpaper = 0,
    },
})

-- Bypass compositing for fullscreen games.
hl.config({
    render = {
        direct_scanout = true,
    },
})

-- Plugins

hl.plugin.load(os.getenv("HOME") .. "/.local/lib/hyprland/libhyprcsgo.so")

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
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
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

-- Window management
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

-- Disable damage tracking to prevent shader flicker.
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd(scripts .. "/vibrance.sh on"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd(scripts .. "/vibrance.sh off"))

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
    local key = i % 10 -- 10 maps to key 0

    hl.bind(mainMod .. " + " .. key,                 hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,         hl.dsp.window.move({ workspace = i }))

    hl.bind(mainMod .. " + ALT + " .. key,           hl.dsp.focus({ workspace = i + 10 }))
    hl.bind(mainMod .. " + ALT + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i + 10 }))
end

-- Windows and workspaces

-- Assign workspaces to monitors.
for ws = 1, 10 do
    hl.workspace_rule({ workspace = ws, monitor = monMain })
end

for ws = 11, 20 do
    hl.workspace_rule({ workspace = ws, monitor = monSide })
end

hl.window_rule({
    name  = "cs2",
    match = { class = "cs2" },

    immediate  = true,
    fullscreen = true,
})
