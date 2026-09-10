#!/usr/bin/env python3
"""Integration checks on a private D-Bus session, never the desktop server."""
import json
import os
from pathlib import Path
import subprocess
import time
from gi.repository import Gio, GLib

root = Path(__file__).resolve().parents[1]
path = root / 'notification-test.qml'
log = open('/tmp/maxshell-notification-tests.log', 'w')
p = subprocess.Popen(['quickshell', '-p', str(path), '--no-color'], stdout=log, stderr=log)
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

def ipc(method, *args):
    out = subprocess.check_output(['quickshell', 'ipc', '-p', str(path), 'call', 'test', method, *map(str,args)], text=True)
    return json.loads(out) if out.strip() else None

def call(method, parameters):
    return bus.call_sync('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
        'org.freedesktop.Notifications', method, parameters, None, Gio.DBusCallFlags.NONE, 4000, None)

def notify(summary, replaces=0, critical=False, actions=False, image=False):
    hints = {'urgency': GLib.Variant('y', 2 if critical else 1)}
    if image:
        hints['image-data'] = GLib.Variant('(iiibiiay)', (2,2,8,True,8,4,bytes([255,0,0,255] * 4)))
    return call('Notify', GLib.Variant('(susssasa{sv}i)',
        ('Quickshell test', replaces, '', summary, 'Test body', ['test','Test action'] if actions else [], hints, 5000))).unpack()[0]

try:
    for _ in range(100):
        if p.poll() is not None:
            raise RuntimeError('Harness did not load; see /tmp/maxshell-notification-tests.log')
        try:
            owned = bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'NameHasOwner', GLib.Variant('(s)', ('org.freedesktop.Notifications',)), None, Gio.DBusCallFlags.NONE, 2000, None).unpack()[0]
            if owned:
                break
            time.sleep(.1)
        except GLib.Error:
            time.sleep(.1)
    normal = notify('normal', actions=True)
    critical = notify('critical', critical=True)
    notify('critical replacement', replaces=critical, critical=True)
    ipc('dnd', 'true')
    suppressed = notify('DND notification')
    ipc('dnd', 'false')
    assert not next(n for n in ipc('snapshot') if n['id'] == suppressed)['popup']
    # A critical notification received after DND stays visible through replacement.
    critical2 = notify('critical new', critical=True)
    notify('critical updated', replaces=critical2, critical=True)
    time.sleep(5.4)
    items = ipc('snapshot')
    assert len(items) == 4
    n = next(n for n in items if n['id'] == normal)
    assert not n['popup'] and not n['closed'] and n['actions'] == 1
    assert next(n for n in items if n['id'] == critical2)['popup']
    action_events = []
    bus.signal_subscribe(None, 'org.freedesktop.Notifications', 'ActionInvoked',
        '/org/freedesktop/Notifications', None, Gio.DBusSignalFlags.NONE,
        lambda *args: action_events.append(args[5].unpack()))
    ipc('invoke', normal)
    end = time.monotonic() + .5
    while time.monotonic() < end:
        GLib.MainContext.default().iteration(False)
        time.sleep(.01)
    assert (normal, 'test') in action_events
    image_id = notify('image', image=True)
    call('CloseNotification', GLib.Variant('(u)', (image_id,)))
    time.sleep(.1)
    item = next(n for n in ipc('snapshot') if n['id'] == image_id)
    assert item['closed'] and item['image'] and item['retained']
    assert ipc('checkImage', image_id)
    for i in range(82): notify('cap ' + str(i))
    assert len(ipc('snapshot')) == 80
    ipc('clear')
    assert ipc('snapshot') == []
    print('PASS: replacement, critical timing, DND, actions after popup timeout, retained images, 80-item cap, clear')
finally:
    p.terminate()
    p.wait(timeout=5)
    log.close()
