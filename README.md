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
- `scripts/install.py`: restore packages, configuration, wallpapers, and user services after reinstalling Arch.

## Restore after a reset

Start with an installed x86_64 Arch Linux system, working internet, and a regular user with sudo access. Run this from that user's TTY before starting Hyprland:

```sh
sudo pacman -Syu --needed git python
git clone https://github.com/maxgreene123/hyprland-dotfiles.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
python3 scripts/install.py --dry-run
python3 scripts/install.py
```

The installer enables multilib, performs a full Arch upgrade, bootstraps yay if needed, and installs the Arch/AUR and system Flatpak lists. It also installs the Python/GIO and screenshot dependencies, Oh My Zsh, the tracked configuration and wallpapers, desktop theme preferences, and `brave.json` as a managed browser policy. Package-manager prompts remain interactive so you can review AUR builds and conflicts. Already installed packages and generated `*-debug` packages are skipped.

Unavailable packages do not block the remaining package installation. Their names are saved to `~/.local/state/dotfiles/missing-packages.txt`; the installer finishes restoring configuration and exits with status 2. Review this file and install replacements or your original local builds. Any package build or installation failure stops the installer with status 1; fix it and rerun. Repeated runs preserve existing packages and create a new file backup.

Existing user files are backed up under `~/.local/state/dotfiles/installs/<timestamp>/home/` before replacement. Unrelated files and app associations are preserved. Quickshell has its own complete backup, recorded in `~/.local/state/maxshell/last-install`. System files changed by the installer receive adjacent `.before-dotfiles-<timestamp>` backups. A symlinked parent configuration directory stops file installation rather than writing into its target.

The installer adjusts the old `/home/maxgreene` wallpaper, screenshot, and bookmark paths to your current home. Monitor assignments remain DP-2 and HDMI-A-1, and the package list includes this machine's AMD graphics and bootloader packages. Adapt these for different hardware. The CS2 plugin is linked from its installed package. Quickshell starts at your next Hyprland login; the Vencord timer is enabled for future logins. No current session is restarted.

After installation, choose **Hyprland (UWSM)** at login, or start it through UWSM from a TTY. Run `chsh -s /usr/bin/zsh` if Zsh is not your login shell. This script restores the tracked desktop files and packages; it does not install Arch, partition disks, configure the bootloader, enable system/network services, or restore personal documents, credentials, network profiles, and account sign-ins. Keep separate backups of those.

If packages and Oh My Zsh are already installed, restore only user files without downloads, root changes, or starting services:

```sh
python3 scripts/install.py --config-only
```

To recover an individual overwritten file, copy its matching path from the printed `home/` backup back into your home directory. To roll back Quickshell from a TTY:

```sh
python3 ~/hyprland-dotfiles/quickshell/scripts/session.py rollback --no-start
```

The bootstrap follows [yay's installation instructions](https://github.com/Jguer/yay#installation) and [Arch's multilib setup](https://wiki.archlinux.org/title/Official_repositories#multilib). Browser policy placement follows [Brave's Linux policy documentation](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy).

## Manual installation

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
`Super+Comma` opens Apps; Lock is beside Suspend, Log out, and Power off in quick controls.
`Super+Shift+L` opens the dashboard with CPU, memory, and GPU usage on one line. App launcher appears above Control center.
`Super+Shift+J` turns vibrance on; `Super+Shift+K` turns it off.

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

## Installer checks

These checks use temporary directories and fake package commands; they do not install packages or change your desktop:

```sh
python3 tests/test_install.py
python3 quickshell/tests/test_session.py
bash -n install-packages.sh flatpak-packages.sh
```
