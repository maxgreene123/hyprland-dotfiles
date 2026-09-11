import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../../components"
import "../../config"
import "../../services"
ColumnLayout {
    id: root
    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property var today: new Date()
    SystemClock { id: clock; precision: SystemClock.Minutes }
    spacing: 20
    RowLayout {
        Label { text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy"); Layout.fillWidth: true; font.pixelSize: 20 }
        Label { text: Qt.formatDateTime(clock.date, "hh:mm AP"); font.pixelSize: 28 }
    }
    RowLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 28
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            RowLayout {
                FlatButton { text: "[<]"; onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1) }
                Label { text: Qt.formatDateTime(root.month, "MMMM yyyy"); Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                FlatButton { text: "[>]"; onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1) }
            }
            GridLayout {
                columns: 7; rowSpacing: 4; columnSpacing: 4; Layout.fillWidth: true
                Repeater { model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]; Label { required property string modelData; text: modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; color: Theme.muted } }
                Repeater {
                    model: 42
                    Rectangle {
                        required property int index
                        readonly property int day: index - ((root.month.getDay() + 6) % 7) + 1
                        readonly property bool valid: day > 0 && day <= new Date(root.month.getFullYear(), root.month.getMonth() + 1, 0).getDate()
                        readonly property bool current: valid && day === root.today.getDate() && root.month.getMonth() === root.today.getMonth() && root.month.getFullYear() === root.today.getFullYear()
                        Layout.fillWidth: true; implicitHeight: 38
                        color: current ? Theme.selected : "transparent"
                        Label { anchors.centerIn: parent; text: parent.valid ? String(parent.day) : ""; font.bold: parent.current }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
        ColumnLayout {
            Layout.preferredWidth: 290; Layout.fillHeight: true; spacing: 16
            Label { text: "SYSTEM"; color: Theme.muted; font.pixelSize: 12 }
            Label { text: "[CPU:" + DesktopBridge.stats.cpu + "%]  [MEM:" + DesktopBridge.stats.memory + "%]  [GPU:" + (DesktopBridge.stats.gpu == null ? "—" : DesktopBridge.stats.gpu + "%") + "]"; Layout.fillWidth: true }
            Label { text: "CPU temperature: " + (DesktopBridge.stats.temperature ?? "—") + "°C"; Layout.fillWidth: true }
            MediaControls { Layout.fillWidth: true }
            FlatButton { text: "App launcher"; Layout.fillWidth: true; onClicked: ShellState.toggle("launcher", ShellState.panelScreen) }
            FlatButton { text: "Control center"; Layout.fillWidth: true; onClicked: ShellState.toggle("controls", ShellState.panelScreen) }
            FlatButton { text: "Notifications (" + Notifs.unreadCount + ")"; Layout.fillWidth: true; onClicked: ShellState.toggle("notifications", ShellState.panelScreen) }
            FlatButton { text: "Default applications"; Layout.fillWidth: true; onClicked: ShellState.toggle("settings", ShellState.panelScreen) }
            Item { Layout.fillHeight: true }
        }
    }
}
