import QtQuick 6.10
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../config"
import "../../services"
PanelWindow {
    id: root
    property bool shown: false
    visible: shown && ShellState.panel !== "controls"
    screen: ShellState.focusedScreen()
    anchors { bottom: true }
    margins.bottom: 60
    implicitWidth: 240; implicitHeight: 60
    color: Theme.background; exclusiveZone: 0
    WlrLayershell.namespace: "maxshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Rectangle { anchors.fill: parent; color: "transparent"; border.color: Theme.border }
    Label { anchors.centerIn: parent; text: Audio.muted ? "[ VOLUME: MUTED ]" : "[ VOLUME: " + Math.round(Audio.volume * 100) + "% ]" }
    Timer { id: hideTimer; interval: 1800; onTriggered: root.shown = false }
    Connections { target: Audio; function onChanged() { root.shown = true; hideTimer.restart(); } }
}
