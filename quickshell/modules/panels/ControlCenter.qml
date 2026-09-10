import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10 as QQC
import Quickshell
import "../../components"
import "../../config"
import "../../services"
ColumnLayout {
    id: root
    spacing: 14
    property string confirmAction: ""
    Flickable {
        id: quickControls
        Layout.fillWidth: true
        Layout.preferredHeight: content.implicitHeight
        Layout.maximumHeight: root.height * 0.62
        clip: true; contentHeight: content.implicitHeight; contentWidth: width
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar {}
        ColumnLayout {
            id: content; width: quickControls.width; spacing: 14
            RowLayout {
                Label { text: "AUDIO"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
                FlatButton { iconName: Audio.muted ? "audio-volume-muted" : "audio-volume-high"; text: Audio.muted ? "[Unmute]" : "[Mute]"; onClicked: Audio.toggleMute(); enabled: !!Audio.sink }
                Label { text: Math.round(Audio.volume * 100) + "%" }
            }
            FlatSlider { Layout.fillWidth: true; value: Audio.volume; enabled: !!Audio.sink; onMoved: Audio.setVolume(value) }
            FlatCombo { Layout.fillWidth: true; model: Audio.outputs.map(n => n.description || n.name); currentIndex: Audio.outputs.indexOf(Audio.sink); onActivated: index => Audio.selectOutput(Audio.outputs[index]); enabled: Audio.outputs.length > 0 }
            MediaControls { Layout.fillWidth: true }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.selected }
            RowLayout {
                FlatButton { text: Notifs.dnd ? "[DND: On]" : "[DND: Off]"; active: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
                FlatButton { text: ShellState.inhibited ? "[Keep awake: On]" : "[Keep awake: Off]"; active: ShellState.inhibited; onClicked: ShellState.inhibited = !ShellState.inhibited }
            }
            RowLayout {
                FlatButton { text: "Screenshot"; onClicked: ShellState.command(["uwsm", "app", "--", Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot.sh"]) }
            }
            RowLayout {
                FlatButton { text: "Suspend"; onClicked: root.confirmAction = "suspend" }
                FlatButton { text: "Log out"; onClicked: root.confirmAction = "logout" }
                FlatButton { text: "Power off"; onClicked: root.confirmAction = "poweroff" }
            }
            RowLayout {
                visible: ["suspend", "logout", "poweroff"].includes(root.confirmAction)
                Label { text: "Confirm " + root.confirmAction + "?"; Layout.fillWidth: true }
                FlatButton { text: "Yes"; onClicked: ShellState.command(root.confirmAction === "logout" ? ["uwsm", "stop"] : ["systemctl", root.confirmAction]) }
                FlatButton { text: "Cancel"; onClicked: root.confirmAction = "" }
            }
        }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.selected }
    NotificationCenter { Layout.fillWidth: true; Layout.fillHeight: true }
}
