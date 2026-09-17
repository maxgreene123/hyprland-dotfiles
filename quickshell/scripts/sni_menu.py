#!/usr/bin/env python3
"""Pops the context menu of a StatusNotifierItem that exports no DBusMenu.

XEmbed icons proxied by xembedsniproxy have no Menu property, so the shell
cannot build a DBusMenu for them. Calling ContextMenu makes the proxy forward
a right click to the embedded window and the app pops its own menu.
"""

import json
import os
import re
import subprocess
import sys

IFACE = "org.kde.StatusNotifierItem"


def run_json(argv):
    result = subprocess.run(argv, capture_output=True, text=True)
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


def registered_items():
    payload = run_json([
        "busctl", "--user", "--json=short", "call",
        "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
        "org.freedesktop.DBus.Properties", "Get", "ss",
        "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems",
    ])
    if not payload:
        return []
    return payload["data"][0]["data"]


def item_id(service, path):
    payload = run_json([
        "busctl", "--user", "--json=short", "get-property",
        service, path, IFACE, "Id",
    ])
    return payload["data"] if payload else None


def hyprland_cursor():
    result = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True)
    if result.returncode != 0:
        return None
    parts = result.stdout.strip().split(",")
    if len(parts) != 2:
        return None
    try:
        return int(parts[0]), int(parts[1])
    except ValueError:
        return None


def hyprland_monitors():
    payload = run_json(["hyprctl", "-j", "monitors"])
    return payload or []


def xwayland_origins():
    """Maps each output name to its top left corner in X screen coordinates."""
    result = subprocess.run(["xrandr"], capture_output=True, text=True,
                            env={"DISPLAY": os.environ.get("DISPLAY", ":0"), "PATH": "/usr/bin"})
    origins = {}
    for line in result.stdout.splitlines():
        match = re.match(r"^(\S+) connected (?:primary )?(\d+)x(\d+)\+(\d+)\+(\d+)", line)
        if match:
            origins[match.group(1)] = (int(match.group(4)), int(match.group(5)))
    return origins


def cursor_position():
    """GTK places the menu in X screen coordinates, which differ from Hyprland's layout.

    Hyprland lays monitors out in logical pixels, while XWayland addresses them in
    physical pixels, so each point needs its monitor's scale and both origins applied.
    """
    cursor = hyprland_cursor()
    if cursor is None:
        return "0", "0"
    origins = xwayland_origins()
    for monitor in hyprland_monitors():
        width = monitor["width"] / monitor["scale"]
        height = monitor["height"] / monitor["scale"]
        if not (monitor["x"] <= cursor[0] < monitor["x"] + width):
            continue
        if not (monitor["y"] <= cursor[1] < monitor["y"] + height):
            continue
        origin = origins.get(monitor["name"], (monitor["x"], monitor["y"]))
        x = (cursor[0] - monitor["x"]) * monitor["scale"] + origin[0]
        y = (cursor[1] - monitor["y"]) * monitor["scale"] + origin[1]
        return str(round(x)), str(round(y))
    return str(cursor[0]), str(cursor[1])


def split_entry(entry):
    service, sep, rest = entry.partition("/")
    return service, (sep + rest) if sep else "/StatusNotifierItem"


def main():
    if len(sys.argv) < 2:
        return 2
    wanted = sys.argv[1]
    if len(sys.argv) > 3:
        x, y = sys.argv[2], sys.argv[3]
    else:
        x, y = cursor_position()

    for entry in registered_items():
        service, path = split_entry(entry)
        if item_id(service, path) != wanted:
            continue
        subprocess.run([
            "busctl", "--user", "call", service, path,
            IFACE, "ContextMenu", "ii", x, y,
        ])
        return 0
    return 1


sys.exit(main())
