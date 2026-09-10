import QtQuick 6.10
import QtQuick.Controls 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../config"
Button {
    id: root
    property bool compact: false
    property bool active: false
    property string iconName: ""
    property string iconGroup: "actions"
    font.family: Theme.family
    font.pixelSize: Theme.fontSize
    padding: compact ? 3 : 8
    topPadding: compact ? 0 : 7
    bottomPadding: compact ? 0 : 7
    implicitHeight: compact ? Theme.barHeight : 34
    background: Rectangle {
        color: root.down || root.active ? Theme.selected : root.hovered ? Theme.surface : "transparent"
        border.color: root.activeFocus && !root.compact ? Theme.muted : "transparent"
        border.width: 1
    }
    contentItem: RowLayout {
        spacing: root.iconName && root.text ? 7 : 0
        Image { visible: root.iconName !== ""; source: visible ? "file:///usr/share/icons/Papirus-Dark/24x24/" + root.iconGroup + "/" + root.iconName + ".svg" : ""; Layout.preferredWidth: 18; Layout.preferredHeight: 18; opacity: root.enabled ? 1 : 0.5; sourceSize: Qt.size(24,24) }
        Text {
            visible: root.text !== ""; text: root.text; font: root.font; Layout.fillWidth: true
            color: root.enabled ? Theme.text : Theme.border
            verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
