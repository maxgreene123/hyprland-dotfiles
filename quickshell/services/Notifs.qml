pragma Singleton
import QtQuick 6.10
import Quickshell
import Quickshell.Services.Notifications
Singleton {
    id: root
    property var notifications: []
    property bool dnd: false
    readonly property int unreadCount: notifications.filter(n => !n.read).length
    readonly property var popups: dnd ? [] : notifications.filter(n => n.popup && !n.closed)
    onDndChanged: if (dnd) notifications.forEach(n => n.popup = false)
    function addNotification(notification) {
        notification.tracked = true;
        const item = wrapper.createObject(root, { notification: notification, screenName: ShellState.focusedScreen()?.name ?? "" });
        const all = [item, ...notifications];
        notifications = all.slice(0, 80);
        all.slice(80).forEach(n => { n.dismiss(); n.destroy(); });
    }
    function markAllRead() { notifications.forEach(n => n.read = true); }
    function remove(item) {
        notifications = notifications.filter(n => n !== item);
        item.dismiss(); item.destroy();
    }
    function clearAll() { const old = notifications; notifications = []; old.forEach(n => { n.dismiss(); n.destroy(); }); }
    Component {
        id: wrapper
        Scope {
            id: item
            property var notification: null
            property string screenName: ""
            property double stamp: Date.now()
            property string summary: ""
            property string body: ""
            property string appName: ""
            property string appIcon: ""
            property string image: ""
            property int urgency: 1
            property var actions: []
            property bool closed: false
            property bool read: false
            property bool popup: false
            function snapshot() {
                if (!notification) return;
                summary = notification.summary;
                body = notification.body;
                appName = notification.appName;
                const hint = notification.hints["image-path"] || notification.hints["image_path"] || "";
                const namedIcon = hint && !hint.startsWith("/") && !hint.startsWith("file:");
                appIcon = notification.appIcon || (namedIcon ? hint : "");
                image = namedIcon ? "" : notification.image;
                urgency = notification.urgency;
                actions = Array.from(notification.actions).map(a => ({id: a.identifier, text: a.text}));
            }
            function updated() {
                snapshot(); stamp = Date.now(); read = false;
                popup = !root.dnd;
                if (urgency === NotificationUrgency.Critical) expiry.stop(); else expiry.restart();
            }
            function dismiss() { popup = false; if (notification && !closed) notification.dismiss(); }
            function invoke(id) {
                if (!notification || closed) return;
                const action = Array.from(notification.actions).find(a => a.identifier === id);
                if (action) action.invoke();
            }
            Timer {
                id: expiry
                interval: 5000
                running: !item.closed && item.urgency !== NotificationUrgency.Critical
                onTriggered: item.popup = false
            }
            Connections {
                target: item.notification
                function onSummaryChanged() { item.updated(); }
                function onBodyChanged() { item.updated(); }
                function onActionsChanged() { item.snapshot(); }
                function onImageChanged() { item.snapshot(); }
                function onAppIconChanged() { item.snapshot(); }
                function onUrgencyChanged() { item.updated(); }
                function onClosed(reason) {
                    item.snapshot(); item.closed = true; item.popup = false;
                    item.actions = []; expiry.stop();
                }
            }
            readonly property bool retained: imageLock.retained
            RetainableLock { id: imageLock; object: item.notification; locked: true }
            Component.onCompleted: { snapshot(); popup = !root.dnd; if (urgency !== NotificationUrgency.Critical) expiry.restart(); }
        }
    }
}
