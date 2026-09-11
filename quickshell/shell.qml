//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick 6.10
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "services"
import "modules/bar"
import "modules/panels"
import "modules/switcher"
ShellRoot {
    readonly property var bridge: DesktopBridge
    BarWrapper {}
    PanelHost {}
    NotificationPopups {}
    VolumeOverlay {}
    AltSwitch {}
    Loader {
        active: !ShellState.preview
        sourceComponent: NotificationServer {
            keepOnReload: true
            actionsSupported: true
            bodySupported: true
            bodyMarkupSupported: false
            bodyHyperlinksSupported: false
            imageSupported: true
            persistenceSupported: true
            onNotification: notification => Notifs.addNotification(notification)
        }
    }
    IpcHandler {
        target: "shell"
        function launcher(): void { ShellState.toggle("launcher", null); }
        function notifications(): void { ShellState.toggle("notifications", null); Notifs.markAllRead(); }
        function settings(): void { ShellState.toggle("settings", null); }
        function connections(): void { ShellState.controlSection = ""; ShellState.toggle("connections", null); }
        function controls(): void { ShellState.toggle("controls", null); }
        function dashboard(): void { ShellState.toggle("dashboard", null); }
        function close(): void { ShellState.close(); }
        function status(): string { return JSON.stringify({ panel: ShellState.panel, screen: ShellState.panelScreen?.name, bridge: DesktopBridge.ready, notifications: Notifs.notifications.length, dnd: Notifs.dnd }); }
        function dnd(enabled: bool): void { Notifs.dnd = enabled; }
    }
}
