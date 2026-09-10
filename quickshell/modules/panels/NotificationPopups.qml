import QtQuick 6.10
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../config"
import "../../services"
Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            readonly property var items: Notifs.popups.filter(n => n.screenName === modelData.name).slice(0, 5)
            screen: modelData; visible: items.length > 0
            anchors { top: true; right: true }
            margins { top: Theme.barHeight + 10; right: 12 }
            implicitWidth: 340; implicitHeight: Math.min(stack.implicitHeight, modelData.height - 70)
            exclusiveZone: 0; color: "transparent"
            WlrLayershell.namespace: "maxshell-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            Column {
                id: stack; width: parent.width; spacing: 8
                Repeater { model: window.items; NotificationCard { required property var modelData; width: stack.width; notification: modelData } }
            }
        }
    }
}
