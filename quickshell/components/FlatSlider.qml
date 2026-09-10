import QtQuick 6.10
import QtQuick.Controls 6.10
import "../config"
Slider {
    id: root
    from: 0; to: 1; implicitHeight: 30
    background: Rectangle {
        x: root.leftPadding; y: (root.height - height) / 2
        width: root.availableWidth; height: 3; color: Theme.selected
        Rectangle { width: root.visualPosition * parent.width; height: parent.height; color: Theme.muted }
    }
    handle: Rectangle { x: root.leftPadding + root.visualPosition * (root.availableWidth - width); y: (root.height - height) / 2; width: 10; height: 18; color: root.pressed ? Theme.text : Theme.muted }
}
