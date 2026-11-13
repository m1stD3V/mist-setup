pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Services.SystemTray
import qs.Theme
import qs.components

Row {
    id: root

    property PanelWindow window

    spacing: 6
    visible: implicitWidth > 0

    Repeater {
        model: ScriptModel {
            values: SystemTray.items.values.filter(i => i.status !== Status.Passive)
        }

        delegate: Rectangle {
            id: trayEntry

            required property SystemTrayItem modelData

            readonly property string iconSource: root.iconFor(trayEntry.modelData.icon)

            implicitWidth: iconItem.loaded ? 20 : 0
            implicitHeight: 20
            visible: iconItem.loaded
            color: mouse.hovered ? Theme.surfaceHigh : "transparent"

            MonoIcon {
                id: iconItem

                anchors.centerIn: parent
                size: 18
                icon: trayEntry.iconSource
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: event => {
                    if (event.button === Qt.LeftButton) {
                        if (trayEntry.modelData.onlyMenu)
                            root.openMenu(trayEntry.modelData);
                        else
                            trayEntry.modelData.activate();
                    } else {
                        if (trayEntry.modelData.hasMenu)
                            root.openMenu(trayEntry.modelData);
                        else
                            trayEntry.modelData.secondaryActivate();
                    }
                }
            }
        }
    }

    function iconFor(icon: string): string {
        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=");
            const file = name.slice(name.lastIndexOf("/") + 1);
            const themed = Quickshell.iconPath(file, true);
            if (themed)
                return themed;
            return Qt.resolvedUrl(`${path}/${file}`);
        }
        if (icon.startsWith("/"))
            return `file://${icon}`;
        return Quickshell.iconPath(icon, true) ?? "";
    }

    function openMenu(item: SystemTrayItem): void {
        menuPopup.entry = item;
        menuPopup.open = true;
    }

    function closeMenu(): void {
        menuPopup.open = false;
    }

    QsMenuOpener {
        id: opener

        menu: menuPopup.entry?.menu ?? null
    }

    BarPopup {
        id: menuPopup

        property SystemTrayItem entry: null

        barWindow: root.window
        screenEdge: "right"
        title: ""
        contentWidth: Theme.popupWidth
        contentHeight: {
            let h = 0;
            for (const e of opener.children.values)
                h += e.isSeparator ? 9 : Theme.popupRowHeight;
            return h + 18;
        }
        open: false

        content: Component {
            Column {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: opener.children

                    delegate: Rectangle {
                        id: menuEntry

                        required property var modelData

                        width: parent.width
                        height: modelData.isSeparator ? 9 : Theme.popupRowHeight
                        color: mouse.hovered && menuEntry.modelData.enabled && !menuEntry.modelData.isSeparator ? Theme.inverseBg : "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: Theme.borderHigh
                            visible: menuEntry.modelData.isSeparator
                        }

                        RText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            text: menuEntry.modelData.text.replace(/&([^&])/g, "$1")
                            font.pixelSize: Theme.fontSmall
                            color: menuEntry.modelData.enabled ? (mouse.hovered && !menuEntry.modelData.isSeparator ? Theme.inverseText : Theme.text) : Theme.textMuted
                            elide: Text.ElideRight
                            width: parent.width - 24
                        }

                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: menuEntry.modelData.enabled && !menuEntry.modelData.isSeparator

                            onClicked: {
                                menuEntry.modelData.triggered();
                                root.closeMenu();
                            }
                        }
                    }
                }
            }
        }
    }
}
