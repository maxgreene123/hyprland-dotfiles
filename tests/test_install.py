#!/usr/bin/env python3
"""Check restore behavior without changing the real home or installing packages."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('installer', ROOT / 'scripts/install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class RestoreTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.target = self.base / 'restored user'
        self.target.mkdir()
        self.config = self.target / '.config'
        self.backup = self.base / 'backup'
        patcher = patch.multiple(installer, TARGET_HOME=self.target, CONFIG=self.config, STATE=self.base / 'state')
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_restore_and_repeat_preserve_unrelated_files_and_backups(self):
        (self.config / 'hypr').mkdir(parents=True)
        previous = self.config / 'hypr/hyprland.lua'
        previous.write_text('previous compositor configuration')
        unrelated = self.config / 'hypr/local.lua'
        unrelated.write_text('local settings')
        defaults = self.config / 'mimeapps.list'
        defaults.write_text('existing associations')
        installer.install_files(self.backup)
        self.assertEqual((self.backup / 'home/.config/hypr/hyprland.lua').read_text(), 'previous compositor configuration')
        self.assertEqual(previous.read_bytes(), (ROOT / 'hypr/hyprland.lua').read_bytes())
        self.assertIn(str(self.target / 'Pictures/macos.png'), (self.config / 'hypr/hyprpaper.conf').read_text())
        self.assertIn(self.target.as_uri(), (self.config / 'gtk-3.0/bookmarks').read_text())
        self.assertIn(str(self.target / 'Screenshots'), (self.config / 'hypr/scripts/screenshot.sh').read_text())
        self.assertTrue(os.access(self.config / 'hypr/scripts/screenshot.sh', os.X_OK))
        self.assertTrue((self.target / 'Pictures/macos.png').is_file())
        timer = self.config / 'systemd/user/timers.target.wants/vencord-maintain.timer'
        self.assertEqual(timer.resolve(), self.config / 'systemd/user/vencord-maintain.timer')
        installer.install_files(self.base / 'second-backup')
        self.assertEqual(unrelated.read_text(), 'local settings')
        self.assertEqual(defaults.read_text(), 'existing associations')
        self.assertEqual((self.backup / 'home/.config/hypr/hyprland.lua').read_text(), 'previous compositor configuration')

    def test_file_symlink_is_backed_up_without_changing_its_target(self):
        original = self.base / 'original-zshrc'
        original.write_text('original shell settings')
        (self.target / '.zshrc').symlink_to(original)
        installer.install_files(self.backup)
        self.assertEqual(original.read_text(), 'original shell settings')
        self.assertFalse((self.target / '.zshrc').is_symlink())
        self.assertEqual((self.backup / 'home/.zshrc').resolve(), original)

    def test_parent_symlink_is_rejected_before_installing_files(self):
        original = self.base / 'shared-config'
        original.mkdir()
        self.config.symlink_to(original)
        with self.assertRaisesRegex(RuntimeError, 'parent is a symlink'):
            installer.install_files(self.backup)
        self.assertEqual(list(original.iterdir()), [])
        self.assertFalse(self.backup.exists())

    def test_dry_run_has_no_writes_or_subprocesses(self):
        with patch('sys.argv', ['install.py', '--dry-run']), patch.object(installer.subprocess, 'run') as command:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(installer.main(), 0)
        command.assert_not_called()
        self.assertEqual(list(self.target.iterdir()), [])

    def test_config_only_installs_quickshell_without_a_running_session(self):
        environment = {
            'XDG_CONFIG_HOME': str(self.config),
            'XDG_DATA_HOME': str(self.target / '.local/share'),
            'XDG_STATE_HOME': str(self.base / 'state'),
        }
        with patch('sys.argv', ['install.py', '--config-only']), patch.dict(os.environ, environment), \
                patch.object(Path, 'home', return_value=self.target), patch.object(os, 'geteuid', return_value=1000), \
                patch.object(shutil, 'which', return_value='/usr/bin/quickshell'), \
                patch.object(subprocess, 'run') as command, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(installer.main(), 0)
        command.assert_not_called()
        self.assertTrue((self.config / 'quickshell/shell.qml').is_file())
        self.assertFalse((self.config / 'quickshell/tests').exists())
        self.assertIn(str(self.config / 'quickshell'), (self.config / 'systemd/user/quickshell.service').read_text())
        self.assertTrue((self.target / '.local/share/dbus-1/services/org.freedesktop.Notifications.service').is_file())


class PackageTests(unittest.TestCase):
    def run_packages(self, install_status=0):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            shutil.copy2(ROOT / 'install-packages.sh', base / 'install-packages.sh')
            (base / 'packages.txt').write_text('installed-local\navailable\nmissing\nyay-debug\n# comment\n')
            binary = base / 'bin'
            binary.mkdir()
            (binary / 'pacman').write_text('#!/bin/bash\n[[ "$2" == installed-local ]]\n')
            (binary / 'yay').write_text(
                '#!/bin/bash\n'
                'if [[ "$1" == -Si ]]; then [[ "$2" == available ]]; exit; fi\n'
                'printf "%s\\n" "$@" > "$PACKAGE_TEST_LOG"\n'
                f'exit {install_status}\n')
            for script in binary.iterdir():
                script.chmod(0o755)
            log = base / 'command.log'
            env = dict(os.environ, PATH=str(binary) + ':' + os.environ['PATH'],
                       XDG_STATE_HOME=str(base / 'state'), PACKAGE_TEST_LOG=str(log))
            result = subprocess.run(['bash', str(base / 'install-packages.sh')], env=env, text=True, capture_output=True)
            return result, log.read_text(), (base / 'state/dotfiles/missing-packages.txt').read_text()

    def test_missing_packages_do_not_block_available_packages(self):
        result, command, missing = self.run_packages()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(command, '-S\n--needed\navailable\n')
        self.assertEqual(missing, 'missing\n')

    def test_install_failure_is_not_reported_as_success(self):
        result, _, _ = self.run_packages(install_status=2)
        self.assertEqual(result.returncode, 1)


if __name__ == '__main__':
    unittest.main()
