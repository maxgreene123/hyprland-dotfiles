import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../../components"
import "../../config"
import "../../services"
FocusScope {
    id: root
    readonly property var entries: {
        const query = search.text.toLowerCase().trim();
        const all = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const score = a => {
            const name = a.name.toLowerCase();
            if (!query) return 1;
            if (name.startsWith(query)) return 4;
            if (name.includes(query)) return 3;
            if (((a.genericName || "") + " " + (a.comment || "") + " " + a.id).toLowerCase().includes(query)) return 2;
            return 0;
        };
        return all.filter(a => score(a) > 0).sort((a,b) => score(b) - score(a) || a.name.localeCompare(b.name));
    }
    function launch() { if (entries[list.currentIndex]) ShellState.launch(entries[list.currentIndex]); }
    ColumnLayout {
        anchors.fill: parent; spacing: 12
        Label { text: "[ APPLICATIONS ]"; font.bold: true }
        FlatField {
            id: search; Layout.fillWidth: true; placeholderText: "Search applications…"; focus: true
            onTextChanged: list.currentIndex = 0
            Keys.onDownPressed: list.currentIndex = Math.min(root.entries.length - 1, list.currentIndex + 1)
            Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
            onAccepted: root.launch()
        }
        ListView {
            id: list; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            model: root.entries; currentIndex: 0; boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: appRow
                required property var modelData
                required property int index
                width: list.width; height: list.height / 8
                color: ListView.isCurrentItem ? Theme.selected : hover.containsMouse ? Theme.surface : "transparent"
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                    Image { source: Quickshell.iconPath(appRow.modelData.icon, true); Layout.preferredWidth: 26; Layout.preferredHeight: 26; sourceSize: Qt.size(32,32) }
                    Label { text: appRow.modelData.name; Layout.fillWidth: true }
                    Label { text: appRow.modelData.runInTerminal ? "terminal" : ""; color: Theme.muted; font.pixelSize: 12 }
                }
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: ShellState.launch(appRow.modelData) }
            }
            Label { anchors.centerIn: parent; visible: root.entries.length === 0; text: "No matching applications"; color: Theme.muted }
        }
        Label { text: root.entries.length + " applications   [↑↓] select   [Enter] open   [Esc] close"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
    }
    Component.onCompleted: search.forceActiveFocus()
}
