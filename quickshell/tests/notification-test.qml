import QtQuick 6.10
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "services"
ShellRoot {
    Image { id: probe; cache: false; visible: false }
    NotificationServer {
        actionsSupported: true; imageSupported: true; persistenceSupported: true
        onNotification: notification => Notifs.addNotification(notification)
    }
    IpcHandler {
        target: "test"
        function snapshot(): string { return JSON.stringify(Notifs.notifications.map(n => ({id:n.notification?.id, summary:n.summary, popup:n.popup, closed:n.closed, actions:n.actions.length, image:n.image, retained:n.retained}))); }
        function dnd(value: bool): void { Notifs.dnd = value; }
        function invoke(id: int): void { const n = Notifs.notifications.find(n => n.notification?.id === id); if (n) n.invoke("test"); }
        function checkImage(id: int): bool { const n = Notifs.notifications.find(n => n.notification?.id === id); probe.source = n.image; return probe.status === Image.Ready; }
        function clear(): void { Notifs.clearAll(); }
    }
}
