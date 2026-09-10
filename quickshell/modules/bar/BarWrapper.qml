import QtQuick 6.10
import Quickshell
import Quickshell.Wayland as Wayland
import "../../config"
import "../../services"
Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: Theme.barHeight
            exclusiveZone: ShellState.preview ? 0 : Theme.barHeight
            color: Theme.surface
            Wayland.WlrLayershell.namespace: "maxshell-bar"
            Wayland.WlrLayershell.keyboardFocus: Wayland.WlrKeyboardFocus.None
            Wayland.IdleInhibitor { window: window; enabled: ShellState.inhibited }
            Bar { anchors.fill: parent; screen: window.screen; barWindow: window }
        }
    }
}
