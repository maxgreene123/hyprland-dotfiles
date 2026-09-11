import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10 as QQC
import Quickshell
import "../../components"
import "../../config"
import "../../services"

ColumnLayout {
    id: root
    spacing: 6
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.selected }
    RowLayout {
        Image { source: Quickshell.iconPath("obsidian", true); Layout.preferredWidth: 18; Layout.preferredHeight: 18; sourceSize: Qt.size(24, 24) }
        Label { text: "TODO"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
        Label { text: ObsidianTodos.ready ? (ObsidianTodos.snapshot.doneCount + "/" + (ObsidianTodos.snapshot.openCount + ObsidianTodos.snapshot.doneCount)) : ""; color: Theme.muted; font.pixelSize: 12 }
        FlatButton { text: "Open"; compact: true; enabled: !!ObsidianTodos.notePath && !ObsidianTodos.busy; onClicked: ObsidianTodos.openNote() }
    }
    RowLayout {
        Label { text: "TODO.md"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
        FlatButton { text: "Undo"; compact: true; enabled: !!ObsidianTodos.notePath && !ObsidianTodos.busy; onClicked: ObsidianTodos.undo() }
    }
    Label {
        visible: ObsidianTodos.issue !== ""
        text: ObsidianTodos.issue; color: Theme.warning; font.pixelSize: 12
        Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2
    }
    ListView {
        id: todos
        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 56
        clip: true; model: ObsidianTodos.todos
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar {}
        delegate: Rectangle {
            id: todoRow
            required property var modelData
            width: todos.width; height: Math.max(30, taskLabel.implicitHeight + 8)
            color: hover.containsMouse ? Theme.surface : "transparent"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: Math.min(4, todoRow.modelData.depth || 0) * 12; spacing: 8
                Label { text: todoRow.modelData.checked ? "[x]" : "[ ]"; color: Theme.muted }
                Label {
                    id: taskLabel
                    text: todoRow.modelData.text; Layout.fillWidth: true
                    wrapMode: Text.Wrap; maximumLineCount: 2
                    color: todoRow.modelData.checked ? Theme.muted : Theme.text
                    font.strikeout: todoRow.modelData.checked
                }
            }
            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; enabled: !ObsidianTodos.busy; onClicked: ObsidianTodos.toggle(todoRow.modelData) }
        }
        Label {
            anchors.centerIn: parent; width: parent.width
            visible: ObsidianTodos.todos.length === 0 && !ObsidianTodos.issue
            text: !ObsidianTodos.notePath ? "Open your vault in Obsidian to connect TODO.md."
                : !ObsidianTodos.ready ? "Loading TODO.md…"
                : ObsidianTodos.snapshot.exists ? "No tasks in TODO.md."
                : "TODO.md could not be read."
            color: Theme.muted; font.pixelSize: 12; wrapMode: Text.Wrap
        }
    }
    RowLayout {
        FlatField { id: newTodo; Layout.fillWidth: true; implicitHeight: 34; placeholderText: "Add a task…"; enabled: !!ObsidianTodos.notePath && !ObsidianTodos.mutating; onAccepted: ObsidianTodos.add(text) }
        FlatButton { text: "[+]"; enabled: !ObsidianTodos.busy && newTodo.enabled && newTodo.text.trim() !== ""; onClicked: ObsidianTodos.add(newTodo.text) }
    }
    Connections { target: ObsidianTodos; function onAdded() { newTodo.text = ""; } }
    Component.onCompleted: ObsidianTodos.refresh()
}
