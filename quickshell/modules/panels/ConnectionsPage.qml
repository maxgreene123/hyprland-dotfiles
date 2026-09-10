import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10 as QQC
import Quickshell
import Quickshell.Bluetooth as NativeBluetooth
import "../../components"
import "../../config"
import "../../services"
Flickable {
    id: root
    clip: true; contentHeight: content.implicitHeight; contentWidth: width
    boundsBehavior: Flickable.StopAtBounds
    readonly property var adapter: NativeBluetooth.Bluetooth.defaultAdapter
    property string confirmAction: ""
    function focusSection() {
        if (DesktopBridge.auth) { root.contentY = 0; password.forceActiveFocus(); return; }
        const target = ShellState.controlSection === "network" ? networkHeading : ShellState.controlSection === "bluetooth" ? bluetoothHeading : null;
        contentY = target ? Math.min(target.mapToItem(content, 0, 0).y, Math.max(0, contentHeight - height)) : 0;
    }
    Component.onCompleted: Qt.callLater(focusSection)
    Connections { target: ShellState; function onControlSectionChanged() { Qt.callLater(root.focusSection); } }
    QQC.ScrollBar.vertical: QQC.ScrollBar {}
    ColumnLayout {
        id: content; width: root.width; spacing: 14
        ColumnLayout {
            visible: !!DesktopBridge.auth; Layout.fillWidth: true; spacing: 8
            Label { text: "Connect to " + (DesktopBridge.auth?.name || "Wi-Fi"); Layout.fillWidth: true; wrapMode: Text.Wrap }
            FlatField { id: username; visible: DesktopBridge.auth?.username ?? false; placeholderText: "Username"; Layout.fillWidth: true }
            FlatField { id: password; placeholderText: "Password"; echoMode: TextInput.Password; Layout.fillWidth: true; onAccepted: authSubmit.clicked() }
            RowLayout {
                FlatButton { id: authSubmit; text: "Connect"; onClicked: { DesktopBridge.action("network.auth", {prompt: DesktopBridge.auth.id, password: password.text, username: username.text}); password.clear(); username.clear(); } }
                FlatButton { text: "Cancel"; onClicked: { DesktopBridge.action("network.auth", {prompt: DesktopBridge.auth.id, cancel: true}); password.clear(); } }
            }
        }
        Label { id: networkHeading; text: "NETWORK"; color: Theme.muted; font.pixelSize: 12 }
        Label { text: DesktopBridge.stats.links.filter(l => l.state === "up").map(l => l.name + ": connected").join("\n") || "No active network link"; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted }
        Label { visible: !DesktopBridge.network.available; text: DesktopBridge.network.error || "Wireless service unavailable"; color: Theme.warning; Layout.fillWidth: true; wrapMode: Text.Wrap }
        Repeater {
            model: DesktopBridge.network.devices
            ColumnLayout {
                id: wifi
                property bool expanded: false
                required property var modelData
                Layout.fillWidth: true; spacing: 8
                RowLayout {
                    Label { text: wifi.modelData.name + " · " + wifi.modelData.state; Layout.fillWidth: true }
                    FlatButton { iconName: "network-wireless"; iconGroup: "devices"; text: wifi.modelData.powered ? "[On]" : "[Off]"; onClicked: DesktopBridge.action("network.power", {path: wifi.modelData.path, enabled: !wifi.modelData.powered}) }
                }
                RowLayout {
                    FlatButton { text: wifi.modelData.scanning ? "Scanning…" : "Scan"; enabled: wifi.modelData.powered && !wifi.modelData.scanning; onClicked: DesktopBridge.action("network.scan", {path: wifi.modelData.path}) }
                    FlatButton { text: "Disconnect"; enabled: wifi.modelData.state === "connected"; onClicked: DesktopBridge.action("network.disconnect", {path: wifi.modelData.path}) }
                }
                Repeater {
                    model: wifi.expanded ? wifi.modelData.networks : wifi.modelData.networks.slice(0, 4)
                    ColumnLayout {
                        id: networkRow
                        required property var modelData
                        Layout.fillWidth: true; spacing: 0
                        FlatButton {
                            Layout.fillWidth: true
                            text: (networkRow.modelData.connected ? "[✓] " : "") + networkRow.modelData.name + "  " + Math.round(networkRow.modelData.strength) + "%"
                            active: networkRow.modelData.connected
                            enabled: (networkRow.modelData.security !== "8021x" || !!networkRow.modelData.known)
                            onClicked: if (!networkRow.modelData.connected) DesktopBridge.action("network.connect", {path: networkRow.modelData.path})
                        }
                        RowLayout {
                            Label { text: networkRow.modelData.security; color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
                            FlatButton { visible: !!networkRow.modelData.known; text: "Forget"; compact: true; onClicked: { root.confirmAction = networkRow.modelData.known; } }
                        }
                        RowLayout {
                            visible: root.confirmAction === networkRow.modelData.known && !!networkRow.modelData.known
                            Label { text: "Forget saved network?"; Layout.fillWidth: true; font.pixelSize: 12 }
                            FlatButton { text: "Yes"; compact: true; onClicked: { DesktopBridge.action("network.forget", {path: root.confirmAction}); root.confirmAction = ""; } }
                            FlatButton { text: "No"; compact: true; onClicked: root.confirmAction = "" }
                        }
                    }
                }
                FlatButton {
                    visible: wifi.modelData.networks.length > 4
                    text: wifi.expanded ? "Show fewer networks" : "Show all " + wifi.modelData.networks.length + " networks"
                    onClicked: wifi.expanded = !wifi.expanded
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.selected }
        RowLayout {
            Label { id: bluetoothHeading; text: "BLUETOOTH"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
            FlatButton { iconName: "bluetooth"; iconGroup: "devices"; text: root.adapter?.enabled ? "[On]" : "[Off]"; enabled: !!root.adapter; onClicked: root.adapter.enabled = !root.adapter.enabled }
            FlatButton { text: root.adapter?.discovering ? "Stop" : "Scan"; enabled: root.adapter?.enabled ?? false; onClicked: root.adapter.discovering = !root.adapter.discovering }
        }
        Repeater {
            model: root.adapter?.enabled ? root.adapter.devices.values : []
            RowLayout {
                id: deviceRow
                required property var modelData
                Layout.fillWidth: true
                Label { text: deviceRow.modelData.name || deviceRow.modelData.address; Layout.fillWidth: true }
                FlatButton {
                    text: deviceRow.modelData.connected ? "Disconnect" : deviceRow.modelData.pairing ? "Cancel" : deviceRow.modelData.paired ? "Connect" : "Pair"
                    onClicked: {
                        if (deviceRow.modelData.connected) deviceRow.modelData.disconnect();
                        else if (deviceRow.modelData.pairing) deviceRow.modelData.cancelPair();
                        else if (deviceRow.modelData.paired) deviceRow.modelData.connect();
                        else deviceRow.modelData.pair();
                    }
                }
            }
        }
        FlatButton { text: "Bluetooth device settings"; onClicked: ShellState.command(["uwsm", "app", "--", "blueman-manager"]) }
    }
    Connections {
        target: DesktopBridge
        function onAuthChanged() {
            if (DesktopBridge.auth) { root.contentY = 0; password.forceActiveFocus(); }
            else password.clear();
        }
    }
    Component.onDestruction: {
        if (root.adapter) root.adapter.discovering = false;
        if (DesktopBridge.auth && ShellState.panel !== "")
            DesktopBridge.action("network.auth", {prompt: DesktopBridge.auth.id, cancel: true});
    }
}
