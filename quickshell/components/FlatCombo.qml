import QtQuick 6.10
import QtQuick.Controls 6.10
import "../config"
ComboBox {
    id: root
    font.family: Theme.family; font.pixelSize: Theme.fontSize
    implicitHeight: 38; leftPadding: 10; rightPadding: 28
    contentItem: Text { text: root.displayText; color: Theme.text; font: root.font; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    indicator: Text { x: root.width - 22; y: (root.height - height) / 2; text: "▾"; color: Theme.muted; font: root.font }
    background: Rectangle { color: Theme.surface; border.width: 1; border.color: root.activeFocus ? Theme.muted : Theme.border }
    delegate: ItemDelegate {
        width: root.width; height: 38
        highlighted: root.highlightedIndex === index
        contentItem: Text { text: root.textRole ? modelData[root.textRole] : modelData; font: root.font; color: Theme.text; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { color: highlighted ? Theme.selected : Theme.background }
    }
    popup: Popup {
        y: root.height; width: root.width; padding: 1
        implicitHeight: Math.min(280, contentItem.implicitHeight + 2)
        contentItem: ListView { clip: true; implicitHeight: contentHeight; model: root.popup.visible ? root.delegateModel : null; currentIndex: root.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator {} }
        background: Rectangle { color: Theme.background; border.color: Theme.border }
    }
}
