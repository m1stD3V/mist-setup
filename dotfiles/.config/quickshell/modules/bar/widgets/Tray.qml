pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Services.SystemTray
import qs.Theme
import qs.components

// System tray icons plus their DBusMenu popup. Height comes from BarPopup's
// content measurement, so a menu that changes while open (many apps rewrite it
// on every open) cannot leave the box the wrong size.
Row {
    id: root

    property var window

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

            Accessible.role: Accessible.Button
            Accessible.name: trayEntry.modelData.title || trayEntry.modelData.id

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
                    } else if (trayEntry.modelData.hasMenu) {
                        root.openMenu(trayEntry.modelData);
                    } else {
                        trayEntry.modelData.secondaryActivate();
                    }
                }
            }
        }
    }

    // Resolve a StatusNotifierItem icon name. Some apps send
    // "name?path=/dir" so a bundled icon can be found; the themed lookup comes
    // first and the bundled file is the fallback. Returns "" when nothing
    // resolves, which makes MonoIcon unload and collapse the entry instead of
    // drawing a broken image.
    function iconFor(icon: string): string {
        if (!icon)
            return "";
        const marker = icon.indexOf("?path=");
        if (marker !== -1) {
            const name = icon.slice(0, marker);
            const dir = icon.slice(marker + 6).replace(/\/+$/, "");
            const file = name.slice(name.lastIndexOf("/") + 1);
            const themed = Quickshell.iconPath(file, true);
            if (themed)
                return themed;
            if (dir.length > 0 && file.length > 0)
                return encodeURI("file://" + dir + "/" + file);
            return "";
        }
        if (icon.startsWith("/"))
            return encodeURI("file://" + icon);
        return Quickshell.iconPath(icon, true) ?? "";
    }

    // DBus menus mark mnemonics with "&"; "&&" is a literal ampersand.
    function menuLabel(text: var): string {
        return String(text ?? "").replace(/&&/g, "\u0000").replace(/&([^&])/g, "$1").replace(/\u0000/g, "&");
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
        open: false

        // the item can vanish while its menu is open (app quit, tray reload)
        onEntryChanged: if (entry === null)
            menuPopup.open = false

        content: Component {
            Column {
                width: parent.width
                spacing: 0

                Repeater {
                    model: opener.children

                    delegate: Rectangle {
                        id: menuEntry

                        required property var modelData

                        readonly property bool inert: !modelData.enabled || modelData.isSeparator
                        readonly property bool hot: mouse.hovered && !menuEntry.inert

                        width: parent.width
                        height: modelData.isSeparator ? 9 : Theme.popupRowHeight
                        color: menuEntry.hot ? Theme.highlight : "transparent"

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
                            text: root.menuLabel(menuEntry.modelData.text)
                            font.pixelSize: Theme.fontSmall
                            color: menuEntry.modelData.enabled ? (menuEntry.hot ? Theme.inverseText : Theme.text) : Theme.textMuted
                            elide: Text.ElideRight
                            width: parent.width - 24
                        }

                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !menuEntry.inert

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
