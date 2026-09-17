# Hyprland dotfiles

My Arch Linux desktop setup using Hyprland, UWSM, and Quickshell, with Adwaita dark styling and Papirus icons. Quickshell provides the bar, launcher, notifications, system controls, media controls, and an Obsidian TODO widget.

See [KEYBINDS.md](KEYBINDS.md) for shortcuts and the [Quickshell README](quickshell/README.md) for shell details.

## Repository structure

- `install/`: the installer, package list, and internal Quickshell installation helper.
- `hypr/`: monitors, shortcuts, window rules, lock screen, wallpaper, and helper scripts.
- `quickshell/`: shell components, panels, services, and theme.
- `gtk-3.0/`, `gtk-4.0/`, `gtkrc-2.0`, `icons/`: desktop appearance.
- `uwsm/`, `xdg-desktop-portal/`: session environment and desktop portals.
- `alacritty.toml`, `zshrc`: terminal and shell settings.
- `Pictures/`: wallpapers.
- `dbus-1/`, `systemd/`, `scripts/`: service definitions and optional maintenance tools. Vencord maintenance is not installed automatically.

## What it installs

- **Desktop:** Hyprland, UWSM, Quickshell, lock screen, wallpaper, monitor controls, and shaders.
- **Apps:** Brave Origin, Alacritty, Thunar, Zed, Obsidian, and Spotify.
- **Integration:** PipeWire audio, Wi-Fi/Bluetooth controls, Tailscale, authentication prompts, desktop portals, screenshots, and clipboard tools.
- **Appearance and shell:** fonts, icons, GTK themes, Zsh plugins, and Oh My Zsh.

The full list is in [install/packages.txt](install/packages.txt). The installer also sets up yay and its build tools, copies the dotfiles and wallpapers, and installs Quickshell's service. Missing browser, file-manager, and editor defaults are filled without replacing existing valid choices.

VMware, games, unrelated personal apps, Flatpaks, kernels, bootloaders, and graphics drivers are excluded. Existing packages are not removed. No Brave policy is installed.

## Install

Requires an installed **x86_64 Arch Linux** system with internet, working graphics drivers, and a regular user with sudo access. Run from a TTY before starting Hyprland:

```sh
sudo pacman -Syu --needed git python
git clone https://github.com/maxgreene123/hyprland-dotfiles.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
python3 install/install.py
```

Already cloned the repo? Run `python3 install/install.py` from its root.

The installer upgrades Arch, installs the selected packages, and backs up replaced configs. Package-manager prompts remain interactive. A package failure stops installation before replacing configs.

Other options:

```sh
# Preview without changes
python3 install/install.py --dry-run

# Copy dotfiles only; packages and Oh My Zsh must already be installed
python3 install/install.py --config-only

# Restore the previous Quickshell files from an existing snapshot
python3 install/install.py --rollback-quickshell
```

After installation, log in through **Hyprland (UWSM)**. Adjust monitor names in `hypr/hyprland.lua` if your outputs differ from `DP-2` and `HDMI-A-1`. To use Zsh as your login shell, run `chsh -s /usr/bin/zsh`.

Network services, account sign-ins, your Obsidian vault, and boot settings remain your responsibility. The installer does not restart the current desktop or enable system services.

File backups are stored in `~/.local/state/dotfiles/installs/`. Quickshell snapshots are stored in `~/.local/state/maxshell/installs/`. Quickshell rollback restores only its files; log out and back in afterward.
