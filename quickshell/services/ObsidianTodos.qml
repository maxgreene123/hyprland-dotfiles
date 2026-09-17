pragma Singleton
import QtQuick 6.10
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string detectedVault: ""
    readonly property string vault: Quickshell.env("OBSIDIAN_VAULT_ROOT") || detectedVault
    readonly property string notePath: Quickshell.env("OBSIDIAN_TODO_FILE") || (vault ? vault + "/TODO.md" : "")
    property var snapshot: ({})
    property string issue: ""
    property string operation: ""
    property string requestPath: ""
    property bool received: false
    readonly property bool busy: worker.running
    readonly property bool mutating: busy && operation !== "status"
    readonly property bool ready: snapshot.state === "ok" && snapshot.requestedPath === notePath
    readonly property var todos: ready ? (snapshot.todos || []).slice().sort((a, b) => Number(a.checked) - Number(b.checked)) : []
    readonly property string backend: decodeURIComponent(Qt.resolvedUrl("../scripts/obsidian_todos.py").toString().replace(/^file:\/\//, ""))
    signal added()

    function request(args) {
        if (busy) return false;
        if (!notePath) { issue = "Open your vault in Obsidian to connect TODO.md."; return false; }
        operation = args[0];
        requestPath = notePath;
        received = false;
        if (operation !== "status") issue = "";
        worker.command = ["python3", backend, "--file", notePath].concat(args);
        worker.running = true;
        return true;
    }
    function refresh() { request(["status"]); }
    function add(text) {
        if (text.trim()) request(["add", "--text", text.trim()]);
    }
    function toggle(todo) {
        request(["toggle", "--line", String(todo.line), "--expect-text", todo.text, "--checked", String(todo.checked)]);
    }
    function openNote() { request(["open"]); }
    function undo() { request(["undo"]); }
    onNotePathChanged: if (ShellState.panel === "dashboard") refresh()

    FileView {
        id: obsidianConfig
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/obsidian/obsidian.json"
        printErrors: false; watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const vaults = Object.values(JSON.parse(text()).vaults || {});
                root.detectedVault = (vaults.find(v => v.open) || vaults[0])?.path || "";
            } catch (error) { root.issue = "Could not read Obsidian vault settings."; }
        }
    }
    Connections {
        target: ShellState
        function onPanelChanged() { if (ShellState.panel === "dashboard") root.refresh(); }
    }
    Timer { interval: 10000; repeat: true; running: ShellState.panel === "dashboard"; onTriggered: root.refresh() }
    Process {
        id: worker
        stdout: SplitParser {
            onRead: line => {
                try {
                    const result = JSON.parse(line);
                    root.received = true;
                    if (result.state === "error") root.issue = result.error || "Could not update TODO.md.";
                    else if (root.requestPath === root.notePath) {
                        root.issue = "";
                        result.requestedPath = root.requestPath;
                        root.snapshot = result;
                        if (root.operation === "add") root.added();
                    }
                } catch (error) { root.issue = "TODO helper returned an unreadable response."; }
            }
        }
        stderr: SplitParser { onRead: line => { root.issue = line; } }
        onExited: if (!root.received) root.issue = "TODO helper could not start. Check the Python helper."
    }
}
