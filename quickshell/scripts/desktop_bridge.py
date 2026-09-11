#!/usr/bin/env python3
"""JSON-lines bridge for app defaults, iwd, and system metrics."""
import argparse
import glob
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib

ROLES = {
    'browser': ['x-scheme-handler/http', 'x-scheme-handler/https', 'text/html', 'application/xhtml+xml'],
    'email': ['x-scheme-handler/mailto'],
    'files': ['inode/directory'],
    'pdf': ['application/pdf'],
    'editor': ['text/plain'],
}


def app_record(app):
    if not app:
        return None
    icon = app.get_icon()
    return {'id': app.get_id(), 'name': app.get_display_name(),
            'icon': icon.to_string() if icon else ''}


class Defaults:
    def __init__(self):
        self.extensions = {}
        roots = [os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))]
        roots += os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
        for root in roots:
            try:
                for line in (Path(root) / 'mime/globs2').read_text().splitlines():
                    if line.startswith('#'):
                        continue
                    _, mime, pattern, *_ = line.split(':')
                    if pattern.startswith('*.'):
                        self.extensions.setdefault(mime, set()).add(pattern[1:])
            except (OSError, ValueError):
                continue

    def types(self):
        return [{'mime': m, 'name': Gio.content_type_get_description(m) or m,
                 'extensions': ' '.join(sorted(self.extensions.get(m, [])))}
                for m in sorted(Gio.content_types_get_registered())]

    def get(self, types):
        if not types or not all(isinstance(t, str) and '/' in t for t in types):
            raise ValueError('Choose a valid file type.')
        current = {t: app_record(Gio.AppInfo.get_default_for_type(t, False)) for t in types}
        # Use the first type for choices; browsers often omit XHTML support.
        apps = {a.get_id(): a for a in Gio.AppInfo.get_all_for_type(types[0]) if a.should_show()}
        for t in types:
            a = Gio.AppInfo.get_default_for_type(t, False)
            if a and a.get_id():
                apps[a.get_id()] = a
        return {'types': types, 'current': current,
                'apps': sorted([app_record(a) for a in apps.values()], key=lambda a: a['name'].lower())}

    def set(self, types, desktop_id):
        available = self.get(types)
        if desktop_id not in {a['id'] for a in available['apps']}:
            raise ValueError('Application is missing or does not support this file type.')
        app = Gio.DesktopAppInfo.new(desktop_id)
        if not app:
            raise ValueError('Application is no longer installed.')
        path = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'mimeapps.list'
        before = path.read_bytes() if path.exists() else None
        try:
            for mime in types:
                if not app.set_as_default_for_type(mime):
                    raise RuntimeError('Could not save association for ' + mime)
            result = self.get(types)
            if any(not result['current'][t] or result['current'][t]['id'] != desktop_id for t in types):
                raise RuntimeError('Another desktop association overrides this selection.')
            return result
        except Exception:
            if before is not None and path.exists() and path.read_bytes() != before:
                temporary = path.with_name('mimeapps.list.quickshell-restore')
                temporary.write_bytes(before)
                temporary.replace(path)
            elif before is None and path.exists():
                path.unlink()
            raise


def launch_role(role):
    app = Gio.AppInfo.get_default_for_type(ROLES[role][0], False)
    if not app:
        raise ValueError('No default application selected for ' + role)
    command = ['uwsm', 'app', '--', app.get_id()]
    if role == 'files':
        command.append(str(Path.home()))
    os.execvp(command[0], command)


AGENT_XML = '''<node><interface name="net.connman.iwd.Agent">
<method name="Release"/>
<method name="RequestPassphrase"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="RequestPrivateKeyPassphrase"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="RequestUserNameAndPassword"><arg type="o" direction="in"/><arg type="s" direction="out"/><arg type="s" direction="out"/></method>
<method name="RequestUserPassword"><arg type="o" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="out"/></method>
<method name="Cancel"><arg type="s" direction="in"/></method>
</interface></node>'''


class Network:
    NAME = 'net.connman.iwd'
    def __init__(self, emit, bus=None):
        self.emit = emit
        self.bus = bus or Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.objects = {}
        self.agent_path = '/org/quickshell/NetworkAgent'
        self.agent_manager = None
        self.pending = None
        self.prompt_id = 0
        self.refresh_source = 0
        self.agent_id = self.bus.register_object(self.agent_path,
            Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0], self.agent_call, None, None)
        self.bus.signal_subscribe(self.NAME, None, None, None, None,
            Gio.DBusSignalFlags.NONE, self.changed)
        self.bus.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus',
            'NameOwnerChanged', '/org/freedesktop/DBus', self.NAME,
            Gio.DBusSignalFlags.NONE, self.owner_changed)
        self.refresh()

    def changed(self, *args):
        if not self.refresh_source:
            self.refresh_source = GLib.timeout_add(350, self.refresh)

    def owner_changed(self, *args):
        self.agent_manager = None
        self.cancel_pending('Wireless service restarted.')
        self.changed()

    def call(self, path, interface, method, args=None, signature=None):
        return self.bus.call_sync(self.NAME, path, interface, method, args,
            GLib.VariantType.new(signature) if signature else None,
            Gio.DBusCallFlags.NONE, 4000, None)

    def refresh(self):
        self.refresh_source = 0
        try:
            self.objects = self.call('/', 'org.freedesktop.DBus.ObjectManager',
                'GetManagedObjects', signature='(a{oa{sa{sv}}})').unpack()[0]
            manager = next((p for p, v in self.objects.items() if self.NAME + '.AgentManager' in v), None)
            if manager and self.agent_manager != manager:
                self.call(manager, self.NAME + '.AgentManager', 'RegisterAgent',
                    GLib.Variant('(o)', (self.agent_path,)))
                self.agent_manager = manager
            devices = []
            for path, interfaces in self.objects.items():
                device = interfaces.get(self.NAME + '.Device')
                if device is None:
                    continue
                station = interfaces.get(self.NAME + '.Station', {})
                networks = []
                if device.get('Powered', False) and station:
                    try:
                        ordered = self.call(path, self.NAME + '.Station', 'GetOrderedNetworks').unpack()[0]
                        for netpath, strength in ordered:
                            props = self.objects.get(netpath, {}).get(self.NAME + '.Network', {})
                            networks.append({'path': netpath, 'name': props.get('Name', 'Wi-Fi network'), 'security': props.get('Type', 'unknown'),
                                'strength': max(0, min(100, 2 * (strength / 100 + 100))),
                                'connected': props.get('Connected', False),
                                'known': props.get('KnownNetwork', '')})
                    except GLib.Error:
                        pass
                devices.append({'path': path, 'name': device.get('Name', 'Wi-Fi'),
                    'powered': device.get('Powered', False), 'state': station.get('State', 'disconnected'),
                    'scanning': station.get('Scanning', False), 'networks': networks})
            self.emit('network', {'available': True, 'devices': devices})
        except (GLib.Error, StopIteration) as error:
            self.objects = {}
            self.emit('network', {'available': False, 'devices': [], 'error': str(error)})
        return GLib.SOURCE_REMOVE

    def cancel_pending(self, message='Connection canceled.'):
        if self.pending:
            self.pending.return_dbus_error('net.connman.iwd.Agent.Error.Canceled', message)
            self.pending = None
            self.emit('auth', None)

    def agent_call(self, connection, sender, path, interface, method, parameters, invocation):
        # Only the iwd owner may request credentials from this exported object.
        owner = self.bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
            'org.freedesktop.DBus', 'GetNameOwner', GLib.Variant('(s)', (self.NAME,)),
            GLib.VariantType.new('(s)'), Gio.DBusCallFlags.NONE, 2000, None).unpack()[0]
        if sender != owner:
            invocation.return_dbus_error('org.freedesktop.DBus.Error.AccessDenied', 'Not the wireless service.')
            return
        if method in ('Cancel', 'Release'):
            self.cancel_pending()
            invocation.return_value(None)
        elif method in ('RequestPassphrase', 'RequestPrivateKeyPassphrase', 'RequestUserPassword', 'RequestUserNameAndPassword'):
            self.cancel_pending()
            self.pending = invocation
            self.prompt_id += 1
            self.prompt_method = method
            p = parameters.unpack()[0]
            props = self.objects.get(p, {}).get(self.NAME + '.Network', {})
            self.emit('auth', {'id': self.prompt_id, 'name': props.get('Name', 'Wi-Fi network'),
                'username': method == 'RequestUserNameAndPassword'})
        else:
            invocation.return_dbus_error('org.freedesktop.DBus.Error.UnknownMethod', 'Unsupported request.')

    def authenticate(self, request):
        if not self.pending or request.get('prompt') != self.prompt_id:
            raise ValueError('Password request has expired.')
        if request.get('cancel'):
            self.cancel_pending()
            return
        pending, self.pending = self.pending, None
        if self.prompt_method == 'RequestUserNameAndPassword':
            value = GLib.Variant('(ss)', (request.get('username', ''), request.get('password', '')))
        else:
            value = GLib.Variant('(s)', (request.get('password', ''),))
        pending.return_value(value)
        self.emit('auth', None)

    def action(self, request, done):
        op, path = request['op'], request.get('path', '')
        if op == 'network.auth':
            self.authenticate(request)
            done(None)
            return
        allowed = {
            'network.scan': ('.Station', 'Scan'),
            'network.connect': ('.Network', 'Connect'),
            'network.disconnect': ('.Station', 'Disconnect'),
            'network.forget': ('.KnownNetwork', 'Forget'),
            'network.power': ('.Device', 'Set'),
        }
        iface, method = allowed[op]
        if self.NAME + iface not in self.objects.get(path, {}):
            raise ValueError('Network or device is no longer available.')
        args = None
        full_interface = self.NAME + iface
        if op == 'network.power':
            full_interface = 'org.freedesktop.DBus.Properties'
            args = GLib.Variant('(ssv)', (self.NAME + '.Device', 'Powered', GLib.Variant('b', bool(request['enabled']))))
        def finished(connection, result, unused):
            try:
                connection.call_finish(result)
                done(None)
            except GLib.Error as error:
                done(str(error))
            self.changed()
        self.bus.call(self.NAME, path, full_interface, method, args, None,
            Gio.DBusCallFlags.NONE, 120000 if op == 'network.connect' else 15000,
            None, finished, None)


def gpu_usage(drm_root=Path('/sys/class/drm')):
    """Prefer the boot GPU; fall back to readable DRM telemetry."""
    readings = []
    for card in drm_root.glob('card[0-9]*'):
        if not card.name[4:].isdigit():
            continue
        device = card / 'device'
        try:
            primary = (device / 'boot_vga').read_text().strip() == '1'
        except OSError:
            primary = False
        try:
            usage = int((device / 'gpu_busy_percent').read_text())
            if not 0 <= usage <= 100:
                usage = None
        except (OSError, ValueError):
            usage = None
        readings.append((primary, usage))
    return max(readings, key=lambda item: (item[0], item[1] is not None))[1] if readings else None


class Bridge:
    def __init__(self):
        self.defaults = Defaults()
        self.previous_cpu = None
        self.buffer = b''
        self.network = None
        self.loop = GLib.MainLoop()
        self.app_monitor = Gio.AppInfoMonitor.get()
        self.app_monitor.connect('changed', lambda *_: self.event('appsChanged', {}))
        try:
            self.network = Network(self.event)
        except GLib.Error as error:
            self.event('network', {'available': False, 'devices': [], 'error': str(error)})
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, self.read)
        GLib.timeout_add_seconds(2, self.stats)
        GLib.timeout_add_seconds(10, self.refresh_network)
        self.stats()
        self.event('ready', {})

    @staticmethod
    def output(message):
        print(json.dumps(message, ensure_ascii=False), flush=True)

    def event(self, name, data):
        self.output({'event': name, 'data': data})

    def reply(self, request, result=None, error=None):
        self.output({'id': request.get('id'), 'ok': error is None, 'result': result, 'error': error})

    def read(self, fd, condition):
        chunk = os.read(fd, 65536)
        if not chunk:
            if self.network:
                self.network.cancel_pending('Shell closed.')
            self.loop.quit()
            return False
        self.buffer += chunk
        while b'\n' in self.buffer:
            line, self.buffer = self.buffer.split(b'\n', 1)
            request = {}
            try:
                packet = json.loads(line)
                if not isinstance(packet, dict):
                    raise ValueError('Request must be a JSON object.')
                request = packet
                self.handle(request)
            except Exception as error:
                self.reply(request, error=str(error))
        return True

    def handle(self, request):
        op = request['op']
        if op == 'apps.types':
            self.reply(request, self.defaults.types())
        elif op == 'apps.get':
            self.reply(request, self.defaults.get(request['types']))
        elif op == 'apps.set':
            self.reply(request, self.defaults.set(request['types'], request['desktopId']))
        elif op.startswith('network.') and self.network:
            self.network.action(request, lambda error: self.reply(request, error=error))
        else:
            raise ValueError('Unsupported operation: ' + op)

    def refresh_network(self):
        if self.network:
            self.network.refresh()
        return True

    def stats(self):
        try:
            cpu = [int(n) for n in Path('/proc/stat').read_text().splitlines()[0].split()[1:9]]
            current = (sum(cpu), cpu[3] + cpu[4])
            usage = 0
            if self.previous_cpu:
                total = current[0] - self.previous_cpu[0]
                usage = 100 * (1 - (current[1] - self.previous_cpu[1]) / total) if total > 0 else 0
            self.previous_cpu = current
            mem = {line.split(':')[0]: int(line.split()[1]) for line in Path('/proc/meminfo').read_text().splitlines()}
            temperature = None
            for name in glob.glob('/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon*/temp1_input'):
                temperature = round(int(Path(name).read_text()) / 1000)
            links = []
            for p in Path('/sys/class/net').iterdir():
                if p.name != 'lo':
                    links.append({'name': p.name, 'state': (p / 'operstate').read_text().strip()})
            self.event('stats', {'cpu': round(usage), 'memory': round(100 * (1 - mem['MemAvailable'] / mem['MemTotal'])),
                'gpu': gpu_usage(), 'temperature': temperature, 'links': links})
        except (OSError, ValueError, KeyError):
            pass
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--launch-role', choices=ROLES)
    args = parser.parse_args()
    if args.launch_role:
        launch_role(args.launch_role)
    else:
        Bridge().loop.run()

if __name__ == '__main__':
    main()
