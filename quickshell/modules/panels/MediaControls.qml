import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../components"
import "../../config"
import "../../services"
ColumnLayout {
    id: root
    readonly property var player: Players.active
    spacing: 10
    Label { text: "MEDIA"; color: Theme.muted; font.pixelSize: 12 }
    RowLayout {
        Layout.fillWidth: true; spacing: 12
        Rectangle {
            Layout.preferredWidth: 80; Layout.preferredHeight: 80; color: Theme.surface
            Image { id: art; anchors.fill: parent; source: root.player?.trackArtUrl || ""; asynchronous: true; fillMode: Image.PreserveAspectFit; sourceSize: Qt.size(160,160) }
            Label { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "♫"; font.pixelSize: 28; color: Theme.muted }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5
            Label { text: root.player?.trackTitle || "Nothing playing"; Layout.fillWidth: true; font.bold: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
            Label { text: root.player?.trackArtist || root.player?.identity || ""; color: Theme.muted; Layout.fillWidth: true }
            Label { text: root.player?.trackAlbum || ""; color: Theme.muted; Layout.fillWidth: true; font.pixelSize: 12 }
        }
    }
    RowLayout {
        FlatButton { iconName: "media-skip-backward"; text: "Prev"; enabled: root.player?.canGoPrevious ?? false; onClicked: root.player.previous() }
        FlatButton { iconName: root.player?.isPlaying ? "media-playback-pause" : "media-playback-start"; text: root.player?.isPlaying ? "Pause" : "Play"; enabled: root.player?.canTogglePlaying ?? false; onClicked: root.player.togglePlaying() }
        FlatButton { iconName: "media-skip-forward"; text: "Next"; enabled: root.player?.canGoNext ?? false; onClicked: root.player.next() }
    }
}
