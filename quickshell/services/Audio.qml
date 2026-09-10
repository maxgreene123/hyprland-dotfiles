pragma Singleton
import QtQuick 6.10
import Quickshell
import Quickshell.Services.Pipewire
Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    property bool initialized: false
    signal changed()
    PwObjectTracker { objects: Pipewire.nodes.values }
    function setVolume(value) { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, value)); }
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function selectOutput(node) { Pipewire.preferredDefaultAudioSink = node; }
    onVolumeChanged: if (initialized) changed()
    onMutedChanged: if (initialized) changed()
    Timer { interval: 2500; running: true; onTriggered: root.initialized = true }
}
