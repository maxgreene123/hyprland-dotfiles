#!/usr/bin/env python3
"""Install Quickshell in XDG folders, or restore its last installation."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
DATA = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
STATE = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'maxshell'
DEST = CONFIG / 'quickshell'
UNIT = CONFIG / 'systemd/user/quickshell.service'
ACTIVATION = DATA / 'dbus-1/services/org.freedesktop.Notifications.service'
LEGACY = DATA / 'dbus-1/services/fr.emersion.mako.service'
MAKO_UNIT = CONFIG / 'systemd/user/mako.service'
PATHS = [DEST, UNIT, ACTIVATION, LEGACY, MAKO_UNIT]


def run(*args, check=True):
    return subprocess.run(args, check=check, text=True, capture_output=True)


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def snapshot():
    backup = STATE / 'installs' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True)
    records = []
    for index, path in enumerate(PATHS):
        saved = backup / str(index)
        kind = 'missing'
        if path.is_symlink():
            kind = 'symlink'
            saved.symlink_to(os.readlink(path))
        elif path.is_dir():
            kind = 'directory'
            shutil.copytree(path, saved, symlinks=True)
        elif path.is_file():
            kind = 'file'
            shutil.copy2(path, saved)
        records.append({'path': str(path), 'kind': kind, 'saved': str(index)})
    (backup / 'manifest.json').write_text(json.dumps(records, indent=2) + '\n')
    return backup


def reload_services():
    run('systemctl', '--user', 'daemon-reload')
    run('busctl', '--user', 'call', 'org.freedesktop.DBus', '/org/freedesktop/DBus',
        'org.freedesktop.DBus', 'ReloadConfig')


def verify():
    for _ in range(40):
        reply = run('quickshell', 'ipc', '-p', str(DEST), 'call', 'shell', 'status', check=False)
        if reply.returncode == 0 and json.loads(reply.stdout).get('bridge'):
            return
        time.sleep(0.25)
    raise RuntimeError('Quickshell did not become ready; check the user journal.')


def restore(backup):
    run('systemctl', '--user', 'stop', 'quickshell.service', check=False)
    for record in json.loads((backup / 'manifest.json').read_text()):
        path, saved = Path(record['path']), backup / record['saved']
        if path not in PATHS:
            raise RuntimeError('Backup contains an unexpected path.')
        remove(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        if record['kind'] == 'symlink':
            path.symlink_to(os.readlink(saved))
        elif record['kind'] == 'directory':
            shutil.copytree(saved, path, symlinks=True)
        elif record['kind'] == 'file':
            shutil.copy2(saved, path)
    reload_services()
    if UNIT.exists():
        run('systemctl', '--user', 'start', 'quickshell.service')
        verify()


def install():
    if not shutil.which('quickshell'):
        raise RuntimeError('Install the quickshell package first.')
    backup = snapshot()
    try:
        if ROOT != DEST:
            run('systemctl', '--user', 'stop', 'quickshell.service', check=False)
            staging = CONFIG / 'quickshell.installing'
            if staging.exists():
                raise RuntimeError(f'Remove the previous staging directory first: {staging}')
            shutil.copytree(ROOT, staging, ignore=shutil.ignore_patterns('.git', '__pycache__', '*.pyc', '.qt'))
            remove(DEST)
            staging.rename(DEST)
        UNIT.parent.mkdir(parents=True, exist_ok=True)
        # Unit specifiers do not expand in D-Bus activation files.
        unit = (DEST / 'integration/quickshell.service').read_text()
        unit = unit.replace('%h/.config/quickshell', str(DEST).replace('%', '%%'))
        UNIT.write_text(unit)
        ACTIVATION.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(DEST / 'integration/org.freedesktop.Notifications.service', ACTIVATION)
        if LEGACY.is_file() and 'SystemdService=quickshell.service' in LEGACY.read_text():
            LEGACY.unlink()
        if not shutil.which('mako') and MAKO_UNIT.is_symlink() and os.readlink(MAKO_UNIT) == '/dev/null':
            MAKO_UNIT.unlink()
        reload_services()
        run('systemctl', '--user', 'restart', 'quickshell.service')
        verify()
        (STATE / 'last-install').write_text(str(backup) + '\n')
        print(f'Installed in {DEST}. Backup: {backup}')
    except Exception:
        restore(backup)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'rollback'])
    args = parser.parse_args()
    if args.action == 'install':
        install()
    else:
        marker = STATE / 'last-install'
        if not marker.exists():
            raise RuntimeError('No installation backup found.')
        restore(Path(marker.read_text().strip()))
        marker.unlink()
        print('Previous Quickshell installation restored. App defaults preserved.')


if __name__ == '__main__':
    main()
