import QtQuick 6.10
import Quickshell
import Quickshell.Services.SystemTray
import "../../config"
import "../../services"

Row {
    height: Theme.barHeight
    spacing: 4
    Repeater {
        model: SystemTray.items.values.filter(item => !/blueman|bluetooth|networkmanager|nm-applet|vmware/i.test(item.id + " " + item.title))
        Item {
            id: tray
            required property var modelData
            width: 24; height: Theme.barHeight
            Image { anchors.centerIn: parent; width: 16; height: 16; source: tray.modelData.icon; fillMode: Image.PreserveAspectFit; sourceSize: Qt.size(24, 24) }
            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: event => {
                    if (event.button === Qt.RightButton || tray.modelData.onlyMenu) {
                        // XEmbed icons proxied to SNI carry no DBusMenu; ask the app to pop its own.
                        if (tray.modelData.hasMenu) trayMenu.open();
                        else ShellState.command(["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/sni_menu.py", tray.modelData.id]);
                    } else if (event.button === Qt.MiddleButton) tray.modelData.secondaryActivate();
                    else tray.modelData.activate();
                }
                onWheel: event => tray.modelData.scroll(event.angleDelta.y, false)
            }
            QsMenuAnchor { id: trayMenu; menu: tray.modelData.menu; anchor.item: tray; anchor.edges: Edges.Bottom; anchor.gravity: Edges.Bottom }
        }
    }
}
