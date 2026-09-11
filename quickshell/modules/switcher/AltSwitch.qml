// Adapted from Pablo-Merino/omarchy-altswitch; see LICENSE in this directory.
import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../components"
import "../../config"
import "../../services"

Scope {
    id: root
    property bool opened: false
    property var windows: []
    property int selectedIndex: 0
    property var targetScreen: null

    function appEntry(appClass) {
        return appClass ? DesktopEntries.heuristicLookup(String(appClass)) : null;
    }

    function appName(appClass) {
        return appEntry(appClass)?.name || String(appClass || "Unknown").split(".").pop();
    }

    function appIcon(appClass) {
        const icon = String(appEntry(appClass)?.icon || "");
        if (icon.startsWith("file://") || icon.startsWith("image://")) return icon;
        if (icon.startsWith("/")) return "file://" + icon.split("/").map(encodeURIComponent).join("/");
        return Quickshell.iconPath(icon || "application-x-executable", true)
            || Quickshell.iconPath("application-x-executable", true);
    }

    function show(payloadJson) {
        watchdog.restart();
        try {
            const payload = JSON.parse(payloadJson);
            if (!Array.isArray(payload.windows)) throw new Error("missing windows");
            root.windows = payload.windows;
            root.selectedIndex = Math.max(0, Math.min(root.windows.length - 1, Number(payload.index) || 0));
            if (!root.opened) root.targetScreen = ShellState.focusedScreen();
            ShellState.close();
            root.opened = root.windows.length > 0;
        } catch (error) {
            console.warn("altswitch: unreadable payload:", error);
            root.hide();
        }
    }

    function select(index) {
        if (!root.opened) return;
        root.selectedIndex = Math.max(0, Math.min(root.windows.length - 1, index));
        watchdog.restart();
    }

    function hide() {
        watchdog.stop();
        root.opened = false;
        root.windows = [];
    }

    Timer {
        id: watchdog
        interval: 10000
        onTriggered: {
            root.hide();
            Quickshell.execDetached(["hyprctl", "eval", "__altswitch_cancel()"]);
        }
    }

    IpcHandler {
        target: "altswitch"
        function show(payloadJson: string): void { root.show(payloadJson); }
        function select(index: int): void { root.select(index); }
        function hide(): void { root.hide(); }
        function state(): string { return JSON.stringify({ open: root.opened, selected: root.selectedIndex, windows: root.windows.length, screen: root.targetScreen?.name }); }
    }

    PanelWindow {
        id: panel
        screen: root.targetScreen || ShellState.focusedScreen()
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "maxshell-altswitch"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(760, panel.width - 32)
            height: Math.min(panel.height - 64, root.windows.length * 48 + 94)
            color: Theme.background
            border.width: 1
            border.color: Theme.border
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                RowLayout {
                    Label { text: "[ WINDOWS ]"; font.bold: true; Layout.fillWidth: true }
                    Label { text: (root.selectedIndex + 1) + " / " + root.windows.length; color: Theme.muted }
                }
                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; interactive: false
                    model: root.windows; currentIndex: root.selectedIndex
                    highlightMoveDuration: 0
                    preferredHighlightBegin: 0; preferredHighlightEnd: height
                    highlightRangeMode: ListView.ApplyRange
                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var modelData
                        width: list.width; height: 48
                        color: index === root.selectedIndex ? Theme.selected : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 12
                            Label { text: row.modelData.workspace; Layout.preferredWidth: 28; color: Theme.muted; horizontalAlignment: Text.AlignRight }
                            Image {
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                sourceSize: Qt.size(48, 48); fillMode: Image.PreserveAspectFit
                                source: root.appIcon(row.modelData.appClass)
                                onStatusChanged: if (status === Image.Error) source = Quickshell.iconPath("application-x-executable", true)
                            }
                            Label { text: root.appName(row.modelData.appClass); Layout.preferredWidth: 136; Layout.maximumWidth: 136; color: Theme.muted }
                            Label { text: row.modelData.title || root.appName(row.modelData.appClass); Layout.fillWidth: true }
                        }
                    }
                }
                Label { text: "[Tab] next   [Shift+Tab] previous   [Release Alt] switch   [Esc] cancel"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
            }
        }
    }
}
