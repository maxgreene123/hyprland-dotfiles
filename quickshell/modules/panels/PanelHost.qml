import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../config"
import "../../services"
PanelWindow {
    id: window
    screen: ShellState.panelScreen || ShellState.focusedScreen()
    visible: ShellState.panel !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "maxshell-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property bool narrowPanel: ["controls", "connections"].includes(ShellState.panel)
    readonly property bool sidePanel: narrowPanel || ShellState.panel === "settings"
    MouseArea { anchors.fill: parent; onClicked: ShellState.close() }
    Rectangle {
        id: frame
        width: Math.min(parent.width - 32, window.narrowPanel ? 420 : ShellState.panel === "launcher" ? 640 : 860)
        height: Math.min(parent.height - 64, ShellState.panel === "launcher" ? 490 : window.narrowPanel ? parent.height - 64 : 640)
        x: window.sidePanel ? parent.width - width - 12 : (parent.width - width) / 2
        y: window.sidePanel ? Theme.barHeight + 12 : Math.max(Theme.barHeight + 12, (parent.height - height) / 2)
        color: Theme.background; border.width: 1; border.color: Theme.border
        MouseArea { anchors.fill: parent }
        FocusScope {
            anchors.fill: parent; anchors.margins: 16; focus: true
            Keys.onEscapePressed: ShellState.close()
            ColumnLayout {
                anchors.fill: parent; spacing: 8
                RowLayout {
                    visible: ShellState.panel !== "launcher"
                    Label { text: "[ " + (window.sidePanel ? "SET" : ShellState.panel.toUpperCase()) + " ]"; font.bold: true; Layout.fillWidth: true }
                    FlatButton { visible: window.sidePanel; iconName: "system-lock-screen"; text: "Lock"; compact: true; onClicked: ShellState.command(["uwsm", "app", "--", "hyprlock"]) }
                    FlatButton { text: "[×]"; compact: true; onClicked: ShellState.close() }
                }
                GridLayout {
                    visible: window.sidePanel
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 4; rowSpacing: 4
                    FlatButton { Layout.fillWidth: true; text: "Quick controls"; active: ShellState.panel === "controls"; onClicked: ShellState.panel = "controls" }
                    FlatButton { Layout.fillWidth: true; text: "Wi-Fi / Bluetooth"; active: ShellState.panel === "connections"; onClicked: { ShellState.controlSection = ""; ShellState.panel = "connections"; } }
                    FlatButton { Layout.fillWidth: true; text: "Apps"; active: ShellState.panel === "settings"; onClicked: ShellState.panel = "settings" }
                }
                Label { visible: ShellState.message !== ""; text: ShellState.message; color: Theme.warning; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
                Loader {
                    id: loader; Layout.fillWidth: true; Layout.fillHeight: true
                    active: window.visible
                    source: {
                        switch (ShellState.panel) {
                            case "launcher": return "../launcher/LauncherWindow.qml";
                            case "controls": return "ControlCenter.qml";
                            case "connections": return "ConnectionsPage.qml";
                            case "settings": return "SettingsPage.qml";
                            case "dashboard": return "Dashboard.qml";
                            default: return "";
                        }
                    }
                    onLoaded: if (item) item.forceActiveFocus()
                }
            }
        }
    }
}
