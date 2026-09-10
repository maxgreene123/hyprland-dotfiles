# Quickshell

- `shell.qml` starts bars, panels, notifications, and IPC.
- `config/Theme.qml` owns colors, font, and bar height.
- `services/` contains shared state and native integrations.
- `scripts/desktop_bridge.py` handles GIO defaults, iwd, and metrics.
- Keep comments brief and use argument arrays for commands.
- Preserve monitor assignments, app defaults, and network services.

Run `python3 tests/test_bridge.py` after bridge changes.
Run notification tests on the private bus described in `README.md`.
Check affected panels and runtime logs after QML changes.
