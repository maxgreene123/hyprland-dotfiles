# Quickshell

A compact Hyprland shell matching the former Waybar theme.
Adapted from [tripathiji1312/quickshell](https://github.com/tripathiji1312/quickshell)
at `0940abdb65749b1796aa4755eea35a161f92cb64`; MIT attribution is in `LICENSE`.

## Controls

- `[MENU]` / `Super+R`: application launcher.
- `[SET]` / `Super+N`: quick controls with notifications below.
- `SET → Wi-Fi / Bluetooth`: network and device controls.
- `SET → Other` / `Super+Comma`: default apps, file types, and Monitors (hyprmoncfg).
- `SET → Quick controls → Lock`: Hyprlock, beside the other session actions. Clock: calendar and media.
- `Super+Shift+L`: dashboard with CPU, memory, and GPU usage on one line; App launcher appears above Control center.
- `Super+Shift+J` / `Super+Shift+K`: vibrance on / off.
- `Alt+Tab` / `Alt+Shift+Tab`: cycle the window switcher with icons; release Alt to switch, `Alt+Escape` to cancel.
- Dashboard TODO widget: view, add, toggle, undo, or open the vault's existing `TODO.md` below the calendar.

Panels follow the clicked or focused monitor. Clocks use 12-hour time.
Spotify artwork, Papirus-Dark icons, and square panels share `config/Theme.qml`.
DP-2 uses workspaces 1–10; HDMI-A-1 uses 11–20.
The bar shows app names and `[playback icon Song - Artist]` up to 480px wide.
The SET label stays `[SET]` regardless of unread notification count.

The window switcher is adapted from [omarchy-altswitch](https://github.com/Pablo-Merino/omarchy-altswitch); see `modules/switcher/LICENSE`. The TODO widget is inspired by [obsidian-daily-qs](https://github.com/LucaNerlich/obsidian-daily-qs), adapted to an existing TODO file with a Python helper. It detects the open Obsidian vault, with optional `OBSIDIAN_VAULT_ROOT` or `OBSIDIAN_TODO_FILE` overrides. It does not create daily notes. Full shortcut reference: `../KEYBINDS.md`.

## Installation

Dependencies: Quickshell 0.3.1+, Qt 6.10+, Python/PyGObject, UWSM, iwd,
BlueZ/Blueman, PipeWire/WirePlumber, Papirus-Dark, and JetBrainsMono Nerd Font.

```sh
python3 scripts/session.py install
```

From a TTY without a running graphical session, add `--no-start`. This installs
the files without contacting systemd, D-Bus, or the compositor. The full dotfiles
restore script (`../scripts/install.py`) uses this mode.

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
- `modules/bar/Tray.qml`: tray icons, filtering, and menu interactions.
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

Run these from the repository’s `quickshell/` directory. Tests are excluded
from the installed config.

```sh
python3 tests/test_bridge.py
python3 tests/test_session.py
python3 tests/test_todos.py
lua tests/test_altswitch.lua
QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORM=offscreen dbus-run-session \
  --config-file=tests/session-bus.conf -- python3 tests/test_notifications.py
```

For a preview without claiming notifications or bar space:
`MAXSHELL_PREVIEW=1 quickshell -p .`.

## Resource use

Bar metrics refresh every five seconds. Network changes arrive through iwd
signals, with a 60-second reconciliation timer as a fallback. The TODO helper
refreshes every ten seconds while the dashboard is open, and immediately when
opening the dashboard or editing a task. Hidden panels are unloaded.

The tray hides VMware, Bluetooth, and NetworkManager icons. Bluetooth and
network controls remain available in SET. VMware itself and its virtual machines
are not removed.
