#!/usr/bin/env python3
"""Isolated installation and recovery checks."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('session', Path(__file__).parents[2] / 'install/quickshell.py')
session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(session)


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        config, data = base / 'config space', base / 'data'
        source = base / 'source'
        (source / 'integration').mkdir(parents=True)
        (source / 'shell.qml').write_text('ShellRoot {}\n')
        (source / '.git').mkdir()
        (source / '.git/private').write_text('not installed')
        (source / 'tests').mkdir()
        (source / 'tests/fixture.qml').write_text('not installed')
        for path in (Path(__file__).parents[1] / 'integration').iterdir():
            (source / 'integration' / path.name).write_bytes(path.read_bytes())
        values = dict(ROOT=source, CONFIG=config, DATA=data, STATE=base / 'state',
            DEST=config / 'quickshell', UNIT=config / 'systemd/user/quickshell.service',
            ACTIVATION=data / 'dbus-1/services/org.freedesktop.Notifications.service',
            LEGACY=data / 'dbus-1/services/fr.emersion.mako.service',
            MAKO_UNIT=config / 'systemd/user/mako.service')
        values['PATHS'] = [values[k] for k in ['DEST', 'UNIT', 'ACTIVATION', 'LEGACY', 'MAKO_UNIT']]
        p = patch.multiple(session, **values)
        p.start(); self.addCleanup(p.stop)
        config.mkdir()
        self.defaults = config / 'mimeapps.list'
        self.defaults.write_text('Existing defaults\n')
        self.run = patch.object(session, 'run', return_value=subprocess.CompletedProcess([], 0, '', ''))
        self.calls = self.run.start(); self.addCleanup(self.run.stop)
        p = patch.object(session, 'verify'); p.start(); self.addCleanup(p.stop)
        p = patch.object(session.shutil, 'which', side_effect=lambda name: '/usr/bin/quickshell' if name == 'quickshell' else None)
        p.start(); self.addCleanup(p.stop)

    def test_copy_and_rollback_preserve_defaults(self):
        session.DEST.mkdir()
        (session.DEST / 'old.qml').write_text('Previous config')
        session.install()
        self.assertTrue((session.DEST / 'shell.qml').exists())
        self.assertFalse((session.DEST / '.git').exists())
        self.assertFalse((session.DEST / 'tests').exists())
        self.assertIn('"' + str(session.DEST) + '"', session.UNIT.read_text())
        session.restore(Path((session.STATE / 'last-install').read_text().strip()))
        self.assertEqual((session.DEST / 'old.qml').read_text(), 'Previous config')
        self.assertFalse(session.UNIT.exists())
        self.assertEqual(self.defaults.read_text(), 'Existing defaults\n')

    def test_replace_symlink_without_removing_source(self):
        session.DEST.symlink_to(session.ROOT)
        session.install()
        self.assertFalse(session.DEST.is_symlink())
        self.assertTrue((session.ROOT / 'shell.qml').exists())
        session.restore(Path((session.STATE / 'last-install').read_text().strip()))
        self.assertEqual(session.DEST.resolve(), session.ROOT)

    def test_install_and_rollback_without_a_session(self):
        session.DEST.mkdir()
        (session.DEST / 'old.qml').write_text('Previous config')
        session.install(start=False)
        self.assertTrue((session.DEST / 'shell.qml').exists())
        self.assertTrue(session.ACTIVATION.exists())
        session.restore(Path((session.STATE / 'last-install').read_text().strip()), start=False)
        self.assertEqual((session.DEST / 'old.qml').read_text(), 'Previous config')
        self.calls.assert_not_called()
        session.verify.assert_not_called()

    def test_failure_restores_previous_directory(self):
        session.DEST.mkdir()
        (session.DEST / 'old.qml').write_text('Previous config')
        def run(*args, **kwargs):
            if 'restart' in args:
                raise RuntimeError('Mock restart failure')
            return subprocess.CompletedProcess([], 0, '', '')
        self.calls.side_effect = run
        with self.assertRaisesRegex(RuntimeError, 'Mock restart failure'):
            session.install()
        self.assertEqual((session.DEST / 'old.qml').read_text(), 'Previous config')
        self.assertEqual(self.defaults.read_text(), 'Existing defaults\n')


if __name__ == '__main__':
    unittest.main()
