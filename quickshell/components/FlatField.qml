import QtQuick 6.10
import QtQuick.Controls 6.10
import "../config"
TextField {
    id: root
    font.family: Theme.family; font.pixelSize: Theme.fontSize
    color: Theme.text; placeholderTextColor: Theme.muted
    selectionColor: Theme.selected; selectedTextColor: Theme.text
    padding: 10; implicitHeight: 40
    background: Rectangle { color: Theme.background; border.color: root.activeFocus ? Theme.muted : Theme.border; border.width: 1 }
}
