# Quickshell

A compact Hyprland shell matching the former Waybar theme.
Adapted from [tripathiji1312/quickshell](https://github.com/tripathiji1312/quickshell)
at `0940abdb65749b1796aa4755eea35a161f92cb64`; MIT attribution is in `LICENSE`.

## Controls

- `[MENU]` / `Super+R`: application launcher.
- `[SET]` / `Super+N`: quick controls with notifications below.
- `SET → Wi-Fi / Bluetooth`: network and device controls.
- `SET → Apps` / `Super+Comma`: default apps and file types.
- `SET → Lock`: Hyprlock. Clock: calendar and media.

Panels follow the clicked or focused monitor. Clocks use 12-hour time.
Spotify artwork, Papirus-Dark icons, and square panels share `config/Theme.qml`.
DP-2 uses workspaces 1–10; HDMI-A-1 uses 11–20.

## Installation

Dependencies: Quickshell 0.3.1+, Qt 6.10+, Python/PyGObject, UWSM, iwd,
BlueZ/Blueman, PipeWire/WirePlumber, Papirus-Dark, and JetBrainsMono Nerd Font.

```sh
python3 scripts/session.py install
```

Installs into `~/.config/quickshell`, `~/.config/systemd/user`, and
`~/.local/share/dbus-1/services`. Hyprland Lua starts `quickshell.service`.
The dotfiles repository includes the matching startup and shortcut bindings.
App associations and existing iwd profiles remain unchanged.

```sh
systemctl --user restart quickshell.service
journalctl --user -u quickshell.service -b
python3 ~/.config/quickshell/scripts/session.py rollback
```

Rollback restores the last Quickshell installation. Retired Waybar/Rofi/Mako
files are archived separately under `~/.local/state/maxshell/retired-*`.

## Source

- `modules/`: bar, launcher, SET pages, dashboard, and volume overlay.
- `components/`: shared controls and notification cards.
- `services/`: native integrations and shared state.
- `scripts/desktop_bridge.py`: GIO defaults, iwd, and system metrics.
- `integration/`: user service and notification activation.

Wi-Fi passwords use stdin and D-Bus. Existing enterprise profiles work;
creating enterprise profiles is outside this UI. Notifications stay in memory,
up to 80. DND retains history; normal popups hide after five seconds.

IPC target `shell`: `launcher`, `controls`, `notifications`, `connections`,
`settings`, `dashboard`, `close`, `status`, and `dnd(bool)`.

## Checks

```sh
python3 tests/test_bridge.py
python3 tests/test_session.py
QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORM=offscreen dbus-run-session \
  --config-file=tests/session-bus.conf -- python3 tests/test_notifications.py
```

For a preview without claiming notifications or bar space:
`MAXSHELL_PREVIEW=1 quickshell -p .`.
