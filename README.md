# Hyprland dotfiles

Current Arch Linux desktop configuration using Hyprland Lua, UWSM, Quickshell, Adwaita dark styling, and Papirus-Dark icons.

## Layout

- `hypr/`: compositor, lock screen, wallpaper, and helper scripts.
- `quickshell/`: bar, launcher, quick controls, notifications, network controls, and app defaults.
- `dbus-1/services/`, `systemd/user/quickshell.service`: notification activation and shell startup.
- `gtk-3.0/`, `gtk-4.0/`, `gtkrc-2.0`, `icons/`: dark theme and cursor defaults.
- `uwsm/`, `xdg-desktop-portal/`: session environment and portal selection.
- `alacritty.toml`, `zshrc`: terminal configuration, autosuggestions, and syntax highlighting.
- `scripts/vencord-maintain`, `systemd/user/`: Vencord maintenance at 09:00 and 21:00 local time. Missed runs are caught up after login.
- `packages.txt`, `flatpak-packages.txt`: installed explicit Arch/AUR packages and system Flatpak apps. These describe this machine, not a minimal dependency list.

## Installation notes

Review files before copying them. Paths, monitor names, wallpaper locations, and the CS2 plugin settings are specific to `/home/maxgreene`, DP-2, and HDMI-A-1. Adapt them for another machine. Package lists can include locally built packages that are unavailable from repositories.

Copy configuration directories into `~/.config/`, `alacritty.toml` into `~/.config/alacritty/`, `zshrc` to `~/.zshrc`, `gtkrc-2.0` to `~/.gtkrc-2.0`, and `icons/default/` into `~/.local/share/icons/`. Oh My Zsh must already be installed for this shell configuration.

Set the desktop preference once:

```sh
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
gsettings set org.gnome.desktop.interface cursor-theme Adwaita
gsettings set org.gnome.desktop.interface cursor-size 24
```

Install the shell after copying `hypr/` and `uwsm/` into `~/.config/`:

```sh
python3 quickshell/scripts/session.py install
```

The installer copies Quickshell into `~/.config/quickshell` and installs its user
service and D-Bus activation. Hyprland starts that service once per session.
Waybar, Rofi, and Mako are replaced; remove those packages and old autostarts.
Existing app associations and network profiles are preserved.

`Super+R` opens the launcher. `[SET]` or `Super+N` opens quick controls with
notifications below. Wi-Fi/Bluetooth and Apps have separate SET tabs.
`Super+Comma` opens Apps; Lock stays in the SET header.

Launch Hyprland through UWSM. Portals use D-Bus/systemd activation; no portal startup script is needed. The CS2 plugin is package-managed, so disable Topgrade's `hyprpm` step if using this setup.

Optional Vencord maintenance:

```sh
install -Dm755 scripts/vencord-maintain ~/.local/bin/vencord-maintain
mkdir -p ~/.config/systemd/user
cp systemd/user/vencord-maintain.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now vencord-maintain.timer
```

The script supports Discord's `~/.config/discord/app-*` layout and uses the official Vencord installer. Restart Discord after repairs to load changes.
