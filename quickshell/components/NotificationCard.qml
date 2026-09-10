import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../config"
import "../services"
Rectangle {
    id: root
    required property var notification
    property bool history: false
    implicitHeight: content.implicitHeight + 24
    color: Theme.surface
    border.width: 1; border.color: notification.urgency === 2 ? Theme.warning : Theme.border
    ColumnLayout {
        id: content; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
        RowLayout {
            Image { visible: root.notification.appIcon !== ""; source: root.notification.appIcon.startsWith("/") || root.notification.appIcon.startsWith("file:") ? root.notification.appIcon : Quickshell.iconPath(root.notification.appIcon, true); sourceSize: Qt.size(24,24); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            Label { text: root.notification.appName || "Notification"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
            Label { visible: root.history; text: Qt.formatDateTime(new Date(root.notification.stamp), "hh:mm AP"); color: Theme.muted; font.pixelSize: 11 }
            FlatButton { compact: true; text: "[×]"; onClicked: root.history ? Notifs.remove(root.notification) : root.notification.dismiss() }
        }
        Label { text: root.notification.summary; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: root.history ? 6 : 3 }
        Label { visible: text !== ""; text: root.notification.body; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: root.history ? 12 : 5; color: Theme.muted }
        Image { visible: root.notification.image !== ""; source: root.notification.image; Layout.fillWidth: true; Layout.preferredHeight: visible ? 100 : 0; fillMode: Image.PreserveAspectFit; asynchronous: true }
        Flow {
            Layout.fillWidth: true; spacing: 4
            Repeater {
                model: root.notification.closed ? [] : root.notification.actions
                FlatButton { required property var modelData; text: modelData.text; onClicked: root.notification.invoke(modelData.id) }
            }
        }
    }
}
