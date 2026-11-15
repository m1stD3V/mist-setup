pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Overflow menu: keeps the rarer actions (settings, system monitor,
// wallpapers, session/power) off the bar while leaving them one click away.
Rectangle {
    id: root

    property PanelWindow window

    function closePopup(): void {
        popup.open = false;
        networkPopup.open = false;
    }

    implicitWidth: labelText.implicitWidth + 10
    implicitHeight: Theme.barHeight - 10
    color: hover.hovered || popup.open || networkPopup.open ? Theme.highlight : "transparent"
    border.width: 1
    border.color: hover.hovered || popup.open || networkPopup.open ? Theme.highlight : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: {
            networkPopup.open = false;
            popup.open = !popup.open;
        }
    }

    RText {
        id: labelText

        anchors.centerIn: parent
        text: "MENU"
        color: hover.hovered || popup.open || networkPopup.open ? Theme.inverseText : Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
    }

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
        contentHeight: 6 * Theme.popupRowHeight + 5 * Theme.popupRowSpacing + Theme.popupChromeHeight
        open: false

        content: Component {
            Column {
                anchors.fill: parent
                spacing: 4

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
