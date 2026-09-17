import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import Quickshell.Hyprland
import "../../components"
import "../../config"
import "../../services"
Item {
    id: root
    required property var screen
    required property var barWindow
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int firstWorkspace: screen.name === "HDMI-A-1" ? 11 : 1
    readonly property var activeTop: Hyprland.toplevels.values.find(t => t.lastIpcObject?.address === root.monitor?.activeWorkspace?.lastIpcObject?.lastwindow)
    readonly property string appName: {
        const appId = activeTop?.lastIpcObject?.class || activeTop?.lastIpcObject?.initialClass || "";
        if (!appId) return "";
        return DesktopEntries.heuristicLookup(appId)?.name || appId.split(".").pop();
    }
    readonly property var player: Players.active
    readonly property var stats: DesktopBridge.stats
    SystemClock { id: clock; precision: SystemClock.Minutes }
    RowLayout {
        anchors.fill: parent; spacing: 0
        Rectangle {
            Layout.fillHeight: true; implicitWidth: leftRow.implicitWidth; color: Theme.background
            Row {
                id: leftRow; height: parent.height
                FlatButton { text: "[MENU]"; compact: true; onClicked: ShellState.toggle("launcher", root.screen) }
                Repeater {
                    model: 10
                    FlatButton {
                        required property int index
                        readonly property int wsId: root.firstWorkspace + index
                        compact: true; text: String(wsId); width: implicitWidth + 4
                        active: root.monitor?.activeWorkspace?.id === wsId
                        onClicked: ShellState.workspace(wsId)
                    }
                }
                Label { text: root.monitor?.activeWorkspace?.hasFullscreen ? "[M]" : root.activeTop?.lastIpcObject?.floating ? "><>" : "[]="; height: parent.height; verticalAlignment: Text.AlignVCenter; leftPadding: 4; rightPadding: 4 }
            }
        }
        Label {
            Layout.fillWidth: true; Layout.leftMargin: 4
            text: root.appName
        }
        Rectangle {
            Layout.fillHeight: true; implicitWidth: rightRow.implicitWidth; color: Theme.background
            Row {
                id: rightRow; height: parent.height; spacing: 4
                FlatButton {
                    id: music
                    readonly property string song: [root.player?.trackTitle, root.player?.trackArtist].filter(Boolean).join(" - ")
                    visible: !!root.player && !!root.player.trackTitle
                    compact: true; width: Math.min(480, root.width * 0.3, implicitWidth)
                    text: "[" + (root.player?.isPlaying ? " " : " ") + song + "]"
                    contentItem: RowLayout {
                        spacing: 0
                        Label { text: "[" + (root.player?.isPlaying ? " " : " ") }
                        Label { text: music.song; Layout.fillWidth: true }
                        Label { text: "]" }
                    }
                    onClicked: if (root.player?.canTogglePlaying) root.player.togglePlaying()
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: event => { if (event.angleDelta.y > 0 && root.player.canGoNext) root.player.next(); else if (event.angleDelta.y < 0 && root.player.canGoPrevious) root.player.previous(); } }
                }
                FlatButton { compact: true; text: Audio.muted ? "[VOL: M]" : "[VOL:" + Math.round(Audio.volume * 100) + "%]"; onClicked: ShellState.toggle("controls", root.screen) }
                FlatButton { compact: true; text: "[CPU:" + root.stats.cpu + "%]"; onClicked: ShellState.toggle("dashboard", root.screen) }
                FlatButton { compact: true; text: "[MEM:" + root.stats.memory + "%]"; onClicked: ShellState.toggle("dashboard", root.screen) }
                Label { visible: root.stats.temperature !== null; height: parent.height; verticalAlignment: Text.AlignVCenter; color: root.stats.temperature >= 80 ? Theme.warning : Theme.text; text: "[" + root.stats.temperature + "°C]" }
                FlatButton { compact: true; text: "[" + Qt.formatDateTime(clock.date, "hh:mm AP") + "]"; onClicked: ShellState.toggle("dashboard", root.screen) }
                FlatButton { compact: true; text: "[SET]"; onClicked: ShellState.toggleSet(root.screen) }
                Tray {}
            }
        }
    }
}
