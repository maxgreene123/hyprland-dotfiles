#!/usr/bin/env python3
"""Restore this desktop on an installed Arch Linux system."""
import argparse
import datetime
import importlib.util
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TARGET_HOME = Path.home()
CONFIG = TARGET_HOME / '.config'
STATE = Path(os.environ.get('XDG_STATE_HOME', TARGET_HOME / '.local/state')) / 'dotfiles'
BOOTSTRAP = ['base-devel', 'git', 'python', 'python-gobject', 'grim', 'slurp', 'libnotify', 'xdg-utils', 'dconf', 'gsettings-desktop-schemas']


def run(*args, **kwargs):
    print('+ ' + shlex.join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def files_to_install():
    files = []
    for directory in ['hypr', 'gtk-3.0', 'gtk-4.0', 'uwsm', 'xdg-desktop-portal']:
        files.extend((source, CONFIG / source.relative_to(ROOT))
                     for source in sorted((ROOT / directory).rglob('*')) if source.is_file())
    for directory, destination in [('Pictures', TARGET_HOME / 'Pictures'),
                                   ('icons', TARGET_HOME / '.local/share/icons')]:
        files.extend((source, destination / source.relative_to(ROOT / directory))
                     for source in sorted((ROOT / directory).rglob('*')) if source.is_file())
    files.extend((ROOT / source, destination) for source, destination in [
        ('alacritty.toml', CONFIG / 'alacritty/alacritty.toml'),
        ('zshrc', TARGET_HOME / '.zshrc'),
        ('gtkrc-2.0', TARGET_HOME / '.gtkrc-2.0'),
        ('scripts/vencord-maintain', TARGET_HOME / '.local/bin/vencord-maintain'),
        ('systemd/user/vencord-maintain.service', CONFIG / 'systemd/user/vencord-maintain.service'),
        ('systemd/user/vencord-maintain.timer', CONFIG / 'systemd/user/vencord-maintain.timer'),
    ])
    return files


def check_destination(path):
    for parent in path.parents:
        if parent == TARGET_HOME:
            break
        if parent.is_symlink():
            raise RuntimeError(f'Configuration parent is a symlink: {parent}. Resolve it before installing.')
    if path.is_dir() and not path.is_symlink():
        raise RuntimeError(f'Expected a file, found a directory: {path}')


def save_existing(path, backup):
    check_destination(path)
    if path.exists() or path.is_symlink():
        saved = backup / 'home' / path.relative_to(TARGET_HOME)
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, saved, follow_symlinks=False)
        # Replace links themselves, never write through them.
        path.unlink()
    path.parent.mkdir(parents=True, exist_ok=True)


def install_files(backup):
    files = files_to_install()
    timer = CONFIG / 'systemd/user/timers.target.wants/vencord-maintain.timer'
    plugin = TARGET_HOME / '.local/lib/hyprland/libhyprcsgo.so'
    for _, destination in files:
        check_destination(destination)
    check_destination(timer)
    check_destination(plugin)
    for source, destination in files:
        save_existing(destination, backup)
        shutil.copy2(source, destination)
        if source.parts[-2:] == ('gtk-3.0', 'bookmarks'):
            destination.write_text(destination.read_text().replace('file:///home/maxgreene', TARGET_HOME.as_uri()))
        elif source.suffix in {'.conf', '.sh'}:
            text = destination.read_text()
            if '/home/maxgreene' in text:
                destination.write_text(text.replace('/home/maxgreene', str(TARGET_HOME)))
    for name in ['Desktop', 'Documents', 'Downloads', 'Music', 'Pictures', 'Screenshots', 'Videos']:
        (TARGET_HOME / name).mkdir(exist_ok=True)
    save_existing(timer, backup)
    timer.symlink_to('../vencord-maintain.timer')
    if Path('/usr/lib/libhyprcsgo.so').exists():
        save_existing(plugin, backup)
        plugin.symlink_to('/usr/lib/libhyprcsgo.so')


def install_quickshell():
    spec = importlib.util.spec_from_file_location('dotfiles_session', ROOT / 'quickshell/scripts/session.py')
    session = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(session)
    session.install(start=False)


def install_packages(backup):
    repositories = subprocess.run(['pacman-conf', '--repo-list'], check=True, text=True, capture_output=True).stdout.splitlines()
    if 'multilib' not in repositories:
        saved = '/etc/pacman.conf.before-dotfiles-' + backup.name
        run('sudo', 'cp', '-a', '/etc/pacman.conf', saved)
        run('sudo', 'tee', '-a', '/etc/pacman.conf', input='\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n', text=True)
    run('sudo', 'pacman', '-Syu', '--needed', *BOOTSTRAP)
    if not shutil.which('yay'):
        with tempfile.TemporaryDirectory(prefix='dotfiles-yay-') as temporary:
            checkout = Path(temporary) / 'yay'
            run('git', 'clone', 'https://aur.archlinux.org/yay.git', checkout)
            run('makepkg', '-si', cwd=checkout)
    result = subprocess.run(['bash', str(ROOT / 'install-packages.sh')])
    if result.returncode not in (0, 2):
        raise RuntimeError('Package installation failed. Fix the reported error and rerun the installer.')
    run('bash', ROOT / 'flatpak-packages.sh')
    ohmyzsh = TARGET_HOME / '.oh-my-zsh'
    if not (ohmyzsh / 'oh-my-zsh.sh').is_file():
        if ohmyzsh.exists() or ohmyzsh.is_symlink():
            raise RuntimeError(f'Incomplete Oh My Zsh installation: {ohmyzsh}. Move it aside and rerun.')
        run('git', 'clone', '--depth=1', 'https://github.com/ohmyzsh/ohmyzsh.git', ohmyzsh)
    return result.returncode


def desktop_preferences():
    # Store settings from a TTY without needing a running graphical session.
    settings = {
        'color-scheme': 'prefer-dark', 'gtk-theme': 'Adwaita-dark',
        'icon-theme': 'Papirus-Dark', 'cursor-theme': 'Adwaita', 'cursor-size': '24',
    }
    for key, value in settings.items():
        run('dbus-run-session', '--', 'gsettings', 'set', 'org.gnome.desktop.interface', key, value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='Print the plan without writes, downloads, or package changes.')
    parser.add_argument('--config-only', action='store_true', help='Restore user files only; dependencies and Oh My Zsh must already exist.')
    args = parser.parse_args()
    print('Restore target:', TARGET_HOME)
    print('Replaced files are backed up under:', STATE / 'installs')
    for source, destination in files_to_install():
        print(f'  {source.relative_to(ROOT)} -> {destination}')
    print('  Quickshell configuration, user service, and D-Bus activation (start at next Hyprland login)')
    print('  Vencord timer enabled for future logins; packaged CS2 plugin linked when available')
    if not args.config_only:
        print('  Enable multilib; upgrade Arch; bootstrap yay; install packages.txt and Flatpak apps')
        print('  Install Oh My Zsh; set desktop theme; apply brave.json as a managed browser policy')
    if args.dry_run:
        return 0
    if os.geteuid() == 0:
        parser.error('Run as your regular user, not root. The installer uses sudo for system changes.')
    if Path(os.environ.get('XDG_CONFIG_HOME', CONFIG)) != CONFIG:
        parser.error('These dotfiles require the standard ~/.config path.')
    if not args.config_only and ('ID=arch\n' not in Path('/etc/os-release').read_text() or os.uname().machine != 'x86_64'):
        parser.error('The package list targets x86_64 Arch Linux.')
    backup = STATE / 'installs' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True, mode=0o700)
    print('Backup:', backup, flush=True)
    status = 0 if args.config_only else install_packages(backup)
    if not shutil.which('quickshell'):
        raise RuntimeError('Install quickshell before restoring configuration.')
    install_files(backup)
    install_quickshell()
    if not args.config_only:
        desktop_preferences()
        policy = Path('/etc/brave/policies/managed/brave.json')
        if policy.exists() or policy.is_symlink():
            run('sudo', 'cp', '-a', policy, str(policy) + '.before-dotfiles-' + backup.name)
            run('sudo', 'rm', '--', policy)
        run('sudo', 'install', '-Dm644', ROOT / 'brave.json', policy)
    print('\nDotfiles installed. File backups:', backup / 'home')
    print('Quickshell backup:', STATE.parent / 'maxshell/last-install')
    print('Log out and launch Hyprland through UWSM. No running session or network services were restarted.')
    print('To make Zsh your login shell, run: chsh -s /usr/bin/zsh')
    print('Network profiles, account sign-ins, bootloader setup, and personal documents require separate restoration.')
    if not (TARGET_HOME / '.oh-my-zsh/oh-my-zsh.sh').is_file():
        print('Oh My Zsh is missing; run the full installer before using the restored .zshrc.')
    if status:
        print('Some packages were unavailable. Review:', STATE / 'missing-packages.txt')
    return status


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'Install failed: {error}', file=sys.stderr)
        sys.exit(1)
