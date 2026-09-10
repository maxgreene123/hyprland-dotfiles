pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
Singleton {
    readonly property var players: Mpris.players.values
    readonly property var active: players.find(p => p.identity.toLowerCase().includes("spotify")) || players.find(p => p.isPlaying) || players[0] || null
}
