import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10 as QQC
import "../../components"
import "../../config"
import "../../services"
ColumnLayout {
    spacing: 12
    RowLayout {
        Label { text: "NOTIFICATIONS"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
        FlatButton { text: "Clear all"; enabled: Notifs.notifications.length > 0; onClicked: Notifs.clearAll() }
    }
    Label { text: "This session · " + Notifs.notifications.length + " notifications"; color: Theme.muted; font.pixelSize: 12 }
    ListView {
        id: list; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
        model: Notifs.notifications; boundsBehavior: Flickable.StopAtBounds
        delegate: NotificationCard { required property var modelData; width: list.width; notification: modelData; history: true }
        Label { anchors.centerIn: parent; visible: Notifs.notifications.length === 0; text: "No notifications"; color: Theme.muted }
        QQC.ScrollBar.vertical: QQC.ScrollBar {}
    }
    Component.onCompleted: Notifs.markAllRead()
}
