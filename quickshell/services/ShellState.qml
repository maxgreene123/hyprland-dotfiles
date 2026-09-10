pragma Singleton
import QtQuick 6.10
import Quickshell
import Quickshell.Hyprland
Singleton {
    id: root
    property string panel: ""
    property string controlSection: ""
    property var panelScreen: null
    property bool inhibited: false
    property string message: ""
    readonly property bool preview: Quickshell.env("MAXSHELL_PREVIEW") === "1"
    function toggleSet(screen) {
        if (["controls", "connections", "settings"].includes(panel) && panelScreen === screen) close();
        else toggle("controls", screen);
    }
    function showControls(section, screen) {
        controlSection = section; panelScreen = screen || focusedScreen();
        panel = ["network", "bluetooth"].includes(section) ? "connections" : "controls";
    }
    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0] || null;
    }
    function toggle(name, screen) {
        if (name === "notifications") name = "controls";
        const target = screen || focusedScreen();
        if (panel === name && panelScreen === target) { close(); return; }
        panelScreen = target;
        panel = name;
        message = "";
    }
    function close() {
        if (DesktopBridge.auth) DesktopBridge.action("network.auth", {prompt: DesktopBridge.auth.id, cancel: true});
        panel = "";
    }
    function launch(entry) {
        Quickshell.execDetached(["uwsm", "app", "--", entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop"]);
        close();
    }
    function command(args) { Quickshell.execDetached(args); close(); }
    function workspace(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (ws) ws.activate();
        else Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + Number(id) + " })" : "workspace " + Number(id));
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activewindowv2", "windowtitlev2", "changefloatingmode", "fullscreen", "movewindowv2"].includes(event.name)) {
                Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels();
            }
        }
    }
    Connections {
        target: DesktopBridge
        function onError(message) { root.message = message; }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.panelScreen && !Quickshell.screens.includes(root.panelScreen)) root.close();
        }
    }
}
