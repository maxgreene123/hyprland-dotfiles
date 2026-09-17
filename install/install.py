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
BOOTSTRAP = ['base-devel', 'git', 'python']
PACKAGE_LIST = ROOT / 'install/packages.txt'


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
    plugin = TARGET_HOME / '.local/lib/hyprland/libhyprcsgo.so'
    for _, destination in files:
        check_destination(destination)
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
    if Path('/usr/lib/libhyprcsgo.so').exists():
        save_existing(plugin, backup)
        plugin.symlink_to('/usr/lib/libhyprcsgo.so')


def quickshell_installer():
    spec = importlib.util.spec_from_file_location('dotfiles_session', ROOT / 'install/quickshell.py')
    session = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(session)
    return session


def read_packages():
    packages = []
    for line in PACKAGE_LIST.read_text().splitlines():
        name = line.split('#', 1)[0].strip()
        if not name:
            continue
        if name.startswith('-') or any(c.isspace() for c in name):
            raise ValueError(f'Invalid package name: {name!r}')
        if name not in packages:
            packages.append(name)
    if not packages:
        raise ValueError('The desktop package list is empty.')
    return packages


def install_requested_packages(packages):
    missing = [name for name in packages if subprocess.run(
        ['pacman', '-Qq', name], stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, check=False).returncode != 0]
    if missing:
        run('yay', '-S', '--needed', *missing)


def install_packages():
    packages = read_packages()
    run('sudo', 'pacman', '-Syu', '--needed', *BOOTSTRAP)
    if not shutil.which('yay'):
        with tempfile.TemporaryDirectory(prefix='dotfiles-yay-') as temporary:
            checkout = Path(temporary) / 'yay'
            run('git', 'clone', 'https://aur.archlinux.org/yay.git', checkout)
            run('makepkg', '-si', cwd=checkout)
    install_requested_packages(packages)
    ohmyzsh = TARGET_HOME / '.oh-my-zsh'
    if not (ohmyzsh / 'oh-my-zsh.sh').is_file():
        if ohmyzsh.exists() or ohmyzsh.is_symlink():
            raise RuntimeError(f'Incomplete Oh My Zsh installation: {ohmyzsh}. Move it aside and rerun.')
        run('git', 'clone', '--depth=1', 'https://github.com/ohmyzsh/ohmyzsh.git', ohmyzsh)


def desktop_preferences():
    # Store settings from a TTY without needing a running graphical session.
    settings = {
        'color-scheme': 'prefer-dark', 'gtk-theme': 'Adwaita-dark',
        'icon-theme': 'Papirus-Dark', 'cursor-theme': 'Adwaita', 'cursor-size': '24',
    }
    for key, value in settings.items():
        run('dbus-run-session', '--', 'gsettings', 'set', 'org.gnome.desktop.interface', key, value)


def default_apps():
    import gi
    gi.require_version('Gio', '2.0')
    from gi.repository import Gio

    roles = {
        'brave-origin.desktop': ['x-scheme-handler/http', 'x-scheme-handler/https', 'text/html', 'application/xhtml+xml'],
        'thunar.desktop': ['inode/directory'],
        'dev.zed.Zed.desktop': ['text/plain'],
    }
    for desktop_id, types in roles.items():
        app = Gio.DesktopAppInfo.new(desktop_id)
        if app is None:
            raise RuntimeError(f'Missing desktop entry: {desktop_id}')
        for mime in types:
            if Gio.AppInfo.get_default_for_type(mime, False) is None:
                if not app.set_as_default_for_type(mime):
                    raise RuntimeError(f'Could not set a default for {mime}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='Print the plan without writes, downloads, or package changes.')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--rollback-quickshell', action='store_true', help='Restore the previous Quickshell files without starting services.')
    mode.add_argument('--config-only', action='store_true', help='Restore user files only; dependencies and Oh My Zsh must already exist.')
    args = parser.parse_args()
    if args.rollback_quickshell:
        if args.dry_run:
            print('Restore the last Quickshell installation without starting services.')
            return 0
        if os.geteuid() == 0:
            parser.error('Run as your regular user, not root.')
        session = quickshell_installer()
        marker = session.STATE / 'last-install'
        if not marker.is_file():
            raise RuntimeError('No Quickshell installation backup found.')
        session.restore(Path(marker.read_text().strip()), start=False)
        marker.unlink()
        print('Previous Quickshell files restored. Log out and back in to use them.')
        return 0
    print('Restore target:', TARGET_HOME)
    print('Replaced files are backed up under:', STATE / 'installs')
    for source, destination in files_to_install():
        print(f'  {source.relative_to(ROOT)} -> {destination}')
    print('  Quickshell configuration, user service, and D-Bus activation (start at next Hyprland login)')
    print('  Existing packaged CS2 plugin linked only when already installed')
    if not args.config_only:
        print('  Upgrade Arch; bootstrap yay; install desktop dependencies from install/packages.txt:')
        print('  ' + ' '.join(read_packages()))
        print('  Install Oh My Zsh, set desktop theme and missing app defaults')
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
    if not args.config_only:
        install_packages()
    if not shutil.which('quickshell'):
        raise RuntimeError('Install quickshell before restoring configuration.')
    install_files(backup)
    quickshell_installer().install(start=False)
    if not args.config_only:
        desktop_preferences()
        default_apps()
    print('\nDotfiles installed. File backups:', backup / 'home')
    print('Quickshell backup:', STATE.parent / 'maxshell/last-install')
    print('Log out and launch Hyprland through UWSM. No running session or network services were restarted.')
    print('To make Zsh your login shell, run: chsh -s /usr/bin/zsh')
    print('Network profiles, account sign-ins, bootloader setup, and personal documents require separate restoration.')
    if not (TARGET_HOME / '.oh-my-zsh/oh-my-zsh.sh').is_file():
        print('Oh My Zsh is missing; run the full installer before using the restored .zshrc.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'Install failed: {error}', file=sys.stderr)
        sys.exit(1)
