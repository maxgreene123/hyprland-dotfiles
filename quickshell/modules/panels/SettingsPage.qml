import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../components"
import "../../config"
import "../../services"
FocusScope {
    id: root
    property string tab: "defaults"
    property var types: []
    property var selection: null
    property var details: null
    property string error: ""
    property bool busy: false
    property int requestGeneration: 0
    readonly property var roles: [
        {name: "Browser", types: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"]},
        {name: "Email", types: ["x-scheme-handler/mailto"]},
        {name: "File manager", types: ["inode/directory"]},
        {name: "PDF documents", types: ["application/pdf"]},
        {name: "Text editor", types: ["text/plain"]}
    ]
    readonly property var rows: tab === "defaults" ? roles : types.filter(t => (t.name + " " + t.mime + " " + t.extensions).toLowerCase().includes(search.text.toLowerCase()))
    function loadTypes() {
        DesktopBridge.request("apps.types", {}, (result, message) => { if (!root) return; if (result) root.types = result; else root.error = message; });
    }
    function select(row) {
        selection = row; error = ""; details = null;
        const generation = ++root.requestGeneration;
        DesktopBridge.request("apps.get", {types: row.types || [row.mime]}, (result, message) => {
            if (!root || generation !== root.requestGeneration) return;
            root.details = result; root.error = message;
            if (result) {
                const id = result.current[result.types[0]]?.id;
                applications.currentIndex = result.apps.findIndex(a => a.id === id);
            }
        });
    }
    function initialize() { loadTypes(); select(roles[0]); }
    Connections {
        target: DesktopBridge
        function onReadyChanged() { if (DesktopBridge.ready) root.initialize(); }
        function onAppsChanged() { if (root.selection && !root.busy) root.select(root.selection); }
    }
    ColumnLayout {
        anchors.fill: parent; spacing: 14
        RowLayout {
            FlatButton { text: "Default apps"; active: root.tab === "defaults"; onClicked: { root.tab = "defaults"; root.select(root.roles[0]); } }
            FlatButton { text: "File types"; active: root.tab === "types"; onClicked: { root.tab = "types"; root.selection = null; root.details = null; root.requestGeneration++; } }
            FlatButton { text: "Monitors"; iconName: "video-display"; iconGroup: "devices"; onClicked: ShellState.command(["uwsm", "app", "--", "alacritty", "--class", "TUI.float", "-e", "hyprmoncfg"]) }
            Item { Layout.fillWidth: true }
        }
        Label { text: "Choose which apps open links, folders, and files."; color: Theme.muted; Layout.fillWidth: true }
        RowLayout {
            Layout.fillHeight: true; Layout.fillWidth: true; spacing: 20
            ColumnLayout {
                Layout.preferredWidth: 260; Layout.fillHeight: true
                FlatField { id: search; visible: root.tab === "types"; Layout.fillWidth: true; placeholderText: "Extension or file type…" }
                ListView {
                    id: typeList; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: root.rows
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: FlatButton {
                        required property var modelData
                        width: typeList.width; height: 48
                        text: modelData.name
                        active: root.selection === modelData
                        onClicked: root.select(modelData)
                    }
                }
                Label { visible: root.tab === "types"; text: root.rows.length + " file types"; color: Theme.muted; font.pixelSize: 12 }
            }
            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.selected }
            ColumnLayout {
                Layout.fillHeight: true; Layout.fillWidth: true; spacing: 14
                Label { text: root.selection?.name ?? "Select a file type"; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Label {
                    text: root.details ? root.details.types.join("\n") : ""; color: Theme.muted
                    wrapMode: Text.WrapAnywhere; elide: Text.ElideNone; Layout.fillWidth: true; font.pixelSize: 12
                }
                Label {
                    text: root.details ? "Current: " + root.details.types.map(t => root.details.current[t]?.name || "Not set").filter((v,i,a) => a.indexOf(v) === i).join(", ") : ""
                    wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true
                }
                FlatCombo { id: applications; Layout.fillWidth: true; visible: !!root.details; model: root.details?.apps ?? []; textRole: "name"; enabled: !root.busy && count > 0 }
                Label { visible: !!root.details && root.details.apps.length === 0; text: "No compatible applications installed."; color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.Wrap }
                FlatButton {
                    text: root.busy ? "Saving…" : "Apply"; enabled: !!root.details && applications.currentIndex >= 0 && !root.busy
                    onClicked: {
                        root.busy = true; root.error = "";
                        const chosen = root.details.apps[applications.currentIndex].id;
                        const generation = root.requestGeneration;
                        DesktopBridge.request("apps.set", {types: root.details.types, desktopId: chosen}, (result, message) => {
                            if (!root) return;
                            root.busy = false;
                            if (generation !== root.requestGeneration) return;
                            root.error = message || "Default saved.";
                            if (result) { root.details = result; applications.currentIndex = result.apps.findIndex(a => a.id === chosen); }
                        });
                    }
                }
                Label { text: root.error; visible: text !== ""; color: Theme.warning; Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
                Item { Layout.fillHeight: true }
                Label { text: "Browser, file-manager, and editor shortcuts follow these choices."; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
            }
        }
    }
    Component.onCompleted: if (DesktopBridge.ready) initialize()
}
