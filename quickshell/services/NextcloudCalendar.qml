pragma Singleton
import QtQuick 6.10
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var days: ({})
    property var upcoming: []
    property string issue: ""
    readonly property string backend: decodeURIComponent(Qt.resolvedUrl("../scripts/nextcloud_calendar.py").toString().replace(/^file:\/\//, ""))

    function refresh() { worker.running = true; }
    Component.onCompleted: refresh()
    Connections {
        target: ShellState
        function onPanelChanged() { if (ShellState.panel === "dashboard") root.refresh(); }
    }
    Timer { interval: 300000; repeat: true; running: ShellState.panel === "dashboard"; onTriggered: root.refresh() }
    Process {
        id: worker
        command: ["python3", root.backend]
        stdout: SplitParser {
            onRead: line => {
                const result = JSON.parse(line);
                root.issue = result.error || "";
                if (!result.error) {
                    root.days = result.days;
                    root.upcoming = result.upcoming;
                }
            }
        }
    }
}
