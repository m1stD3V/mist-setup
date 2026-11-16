pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Overflow menu: keeps the rarer actions (settings, system monitor,
// wallpapers, session/power) off the bar while leaving them one click away.
BarChip {
    id: root

    property var window

    bar: root.window
    active: popup.open || networkPopup.open
    accessibleName: qsTr("System menu")

    function closePopup(): void {
        popup.open = false;
        networkPopup.open = false;
    }

    onTapped: {
        networkPopup.open = false;
        popup.open = !popup.open;
    }

    RText {
        text: "MENU"
        color: root.hot ? Theme.inverseText : Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
    }

    // A centred overlay taking over the screen closes this menu, instead of
    // leaving two panels open at once.
    Connections {
        target: ShellState

        function onWallpaperOpenChanged(): void {
            if (ShellState.wallpaperOpen)
                root.closePopup();
        }

        function onSessionOpenChanged(): void {
            if (ShellState.sessionOpen)
                root.closePopup();
        }

        function onAppsOpenChanged(): void {
            if (ShellState.appsOpen)
                root.closePopup();
        }

        function onSettingsOpenChanged(): void {
            if (ShellState.settingsOpen)
                root.closePopup();
        }
    }

    BarPopup {
        id: popup

        barWindow: root.window
        screenEdge: "left"
        title: "SYSTEM"
        contentWidth: Theme.popupWidth
        open: false

        content: Component {
            Column {
                width: parent.width
                spacing: Theme.popupRowSpacing

                MenuAction {
                    width: parent.width
                    label: "NETWORK"
                    hint: Network.menuHint
                    onClicked: {
                        popup.open = false;
                        networkPopup.open = true;
                    }
                }

                MenuAction {
                    width: parent.width
                    label: "INSTALL PACKAGES"
                    hint: "OPEN"
                    onClicked: {
                        Launcher.openPacseek("");
                        popup.open = false;
                    }
                }

                MenuAction {
                    width: parent.width
                    label: "SYSTEM MONITOR"
                    hint: "OPEN"
                    onClicked: ShellState.openApps("performance")
                }

                MenuAction {
                    width: parent.width
                    label: "WALLPAPERS"
                    hint: "OPEN"
                    onClicked: ShellState.toggleWallpaper()
                }

                MenuAction {
                    width: parent.width
                    label: "SETTINGS"
                    hint: "OPEN"
                    onClicked: ShellState.toggleSettings()
                }

                MenuAction {
                    width: parent.width
                    label: "SESSION / POWER"
                    hint: "OPEN"
                    onClicked: ShellState.toggleSession()
                }
            }
        }
    }

    NetworkPanel {
        id: networkPopup

        barWindow: root.window
    }
}
