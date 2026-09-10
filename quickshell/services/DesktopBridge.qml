pragma Singleton
import QtQuick 6.10
import Quickshell
import Quickshell.Io
Singleton {
    id: root
    property bool ready: false
    property var network: ({ available: false, devices: [] })
    property var stats: ({ cpu: 0, memory: 0, temperature: null, links: [] })
    property var auth: null
    property int serial: 0
    property var callbacks: ({})
    signal appsChanged()
    signal error(string message)
    function request(op, args, callback) {
        if (!ready) { if (callback) callback(null, "Desktop service is starting."); return; }
        const id = ++serial;
        if (callback) callbacks[id] = callback;
        process.write(JSON.stringify(Object.assign({id: id, op: op}, args || {})) + "\n");
    }
    function action(op, args) {
        request(op, args, (result, message) => { if (message) root.error(message); });
    }
    Process {
        id: process
        command: ["python3", Qt.resolvedUrl("../scripts/desktop_bridge.py").toString().replace("file://", "")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const msg = JSON.parse(line);
                    if (msg.event === "ready") root.ready = true;
                    else if (msg.event === "network") root.network = msg.data;
                    else if (msg.event === "stats") root.stats = msg.data;
                    else if (msg.event === "auth") root.auth = msg.data;
                    else if (msg.event === "appsChanged") root.appsChanged();
                    else if (msg.id && root.callbacks[msg.id]) {
                        const cb = root.callbacks[msg.id];
                        delete root.callbacks[msg.id];
                        cb(msg.result, msg.ok ? "" : msg.error);
                    }
                } catch (e) { console.warn("Desktop bridge: invalid response", e.message); }
            }
        }
        onExited: {
            root.ready = false;
            root.auth = null;
            for (const key in root.callbacks) root.callbacks[key](null, "Desktop service restarted.");
            root.callbacks = ({});
            restart.start();
        }
    }
    Timer { id: restart; interval: 2000; onTriggered: process.running = true }
}
