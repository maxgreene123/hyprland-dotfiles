#!/usr/bin/env python3
"""Run isolated association and mocked D-Bus regression checks."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
# GIO caches XDG paths. Set these before importing it, in a fresh interpreter.
fixture = tempfile.TemporaryDirectory(prefix='maxshell-test-')
base = Path(fixture.name)
os.environ.update(HOME=str(base), XDG_CONFIG_HOME=str(base / 'config'),
                  XDG_DATA_HOME=str(base / 'data'), XDG_DATA_DIRS='/usr/share', XDG_CURRENT_DESKTOP='')
(base / 'config').mkdir()
apps = base / 'data/applications'
apps.mkdir(parents=True)
MIMES = 'x-scheme-handler/http;x-scheme-handler/https;text/html;application/xhtml+xml;application/pdf;text/plain;'
for name in ['A', 'B']:
    (apps / f'fixture-{name}.desktop').write_text(f'[Desktop Entry]\nType=Application\nName=Fixture {name}\nExec=/usr/bin/true %U\nMimeType={MIMES}\n')
subprocess.run(['update-desktop-database', str(apps)], check=True)
spec = importlib.util.spec_from_file_location('desktop_bridge', ROOT / 'scripts/desktop_bridge.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class DefaultsTests(unittest.TestCase):
    def setUp(self):
        self.defaults = b.Defaults()
        self.path = base / 'config/mimeapps.list'
        self.path.write_text('[Default Applications]\napplication/pdf=fixture-A.desktop\ntext/plain=fixture-B.desktop\nx-scheme-handler/unrelated=leave-me.desktop\n')

    def test_browser_group_preserves_other_associations(self):
        self.defaults.set(b.ROLES['browser'], 'fixture-B.desktop')
        for mime in b.ROLES['browser']:
            self.assertEqual(b.Gio.AppInfo.get_default_for_type(mime, False).get_id(), 'fixture-B.desktop')
        self.assertEqual(b.Gio.AppInfo.get_default_for_type('application/pdf', False).get_id(), 'fixture-A.desktop')
        self.assertIn('x-scheme-handler/unrelated=leave-me.desktop', self.path.read_text())

    def test_pdf_write_and_reload(self):
        result = self.defaults.set(['application/pdf'], 'fixture-B.desktop')
        self.assertEqual(result['current']['application/pdf']['id'], 'fixture-B.desktop')
        self.assertEqual(self.defaults.get(['text/plain'])['current']['text/plain']['id'], 'fixture-B.desktop')

    def test_missing_app_never_writes(self):
        before = self.path.read_bytes()
        with self.assertRaises(ValueError):
            self.defaults.set(['application/pdf'], 'not-installed.desktop')
        self.assertEqual(self.path.read_bytes(), before)

    def test_group_failure_restores_original_bytes(self):
        before = self.path.read_bytes()
        app = b.Gio.DesktopAppInfo.new('fixture-B.desktop')
        class FailingApp:
            calls = 0
            def set_as_default_for_type(self, mime):
                self.calls += 1
                if self.calls == 2:
                    raise RuntimeError('Simulated write failure')
                return app.set_as_default_for_type(mime)
        with patch.object(b.Gio.DesktopAppInfo, 'new', return_value=FailingApp()):
            with self.assertRaisesRegex(RuntimeError, 'Simulated'):
                self.defaults.set(b.ROLES['browser'], 'fixture-B.desktop')
        self.assertEqual(self.path.read_bytes(), before)

    def test_type_search_has_extensions(self):
        pdf = next(t for t in self.defaults.types() if t['mime'] == 'application/pdf')
        self.assertIn('.pdf', pdf['extensions'])
        self.assertTrue(pdf['name'])


class Invocation:
    def __init__(self): self.value = None; self.error = None
    def return_value(self, value): self.value = value.unpack() if value else ()
    def return_dbus_error(self, name, message): self.error = name


class NetworkTests(unittest.TestCase):
    def setUp(self):
        self.events = []
        self.network = b.Network.__new__(b.Network)
        self.network.emit = lambda event, data: self.events.append((event, data))
        self.network.pending = None
        self.network.prompt_id = 9
        self.network.prompt_method = 'RequestPassphrase'
        self.network.objects = {'/station': {b.Network.NAME + '.Station': {}}, '/network': {b.Network.NAME + '.Network': {}}}
        self.network.refresh_source = 0

    def test_powered_off_device_remains_available(self):
        self.network.agent_manager = None
        self.network.call = lambda *args, **kwargs: b.GLib.Variant('(a{oa{sa{sv}}})', ({'/device': {b.Network.NAME + '.Device': {'Name': b.GLib.Variant('s', 'wlan0'), 'Powered': b.GLib.Variant('b', False)}}},))
        self.network.refresh()
        state = self.events[-1][1]
        self.assertEqual(len(state['devices']), 1)
        self.assertFalse(state['devices'][0]['powered'])

    def test_malformed_packet_does_not_drop_reader(self):
        bridge = b.Bridge.__new__(b.Bridge)
        bridge.buffer = b''
        packets = []
        bridge.output = packets.append
        bridge.handle = lambda request: bridge.reply(request, 'still alive')
        read_fd, write_fd = os.pipe()
        try:
            os.write(write_fd, b'[]\n{"id":2,"op":"test"}\n')
            self.assertTrue(bridge.read(read_fd, b.GLib.IO_IN))
            self.assertFalse(packets[0]['ok'])
            self.assertEqual(packets[1]['result'], 'still alive')
        finally:
            os.close(read_fd)
            os.close(write_fd)

    def test_password_reply_never_appears_in_events(self):
        pending = self.network.pending = Invocation()
        self.network.authenticate({'prompt': 9, 'password': 'secret-fixture'})
        self.assertEqual(pending.value, ('secret-fixture',))
        self.assertNotIn('secret-fixture', json.dumps(self.events))
        self.assertIsNone(self.network.pending)

    def test_cancel_and_expired_prompt(self):
        pending = self.network.pending = Invocation()
        self.network.authenticate({'prompt': 9, 'cancel': True})
        self.assertEqual(pending.error, 'net.connman.iwd.Agent.Error.Canceled')
        with self.assertRaisesRegex(ValueError, 'expired'):
            self.network.authenticate({'prompt': 9, 'password': 'unused'})

    def test_disappeared_device(self):
        with self.assertRaisesRegex(ValueError, 'no longer available'):
            self.network.action({'op': 'network.scan', 'path': '/gone'}, lambda error: None)

    def test_async_scan_and_access_denied(self):
        results = []
        class Bus:
            def call(self, *args):
                self.args = args
                args[-2](self, object(), None)
            def call_finish(self, result):
                raise b.GLib.Error('Access denied')
        self.network.bus = Bus()
        self.network.changed = lambda: None
        self.network.action({'op': 'network.scan', 'path': '/station'}, results.append)
        self.assertEqual(self.network.bus.args[3], 'Scan')
        self.assertIn('Access denied', results[0])

    def test_restart_cancels_password(self):
        pending = self.network.pending = Invocation()
        self.network.changed = lambda: None
        self.network.owner_changed()
        self.assertIsNone(self.network.pending)
        self.assertIsNotNone(pending.error)


if __name__ == '__main__':
    unittest.main()
