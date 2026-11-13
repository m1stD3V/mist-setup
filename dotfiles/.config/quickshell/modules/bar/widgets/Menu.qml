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
    }

    implicitWidth: labelText.implicitWidth + 10
    implicitHeight: Theme.barHeight - 10
    color: hover.hovered || popup.open ? Theme.inverseBg : "transparent"
    border.width: 1
    border.color: hover.hovered || popup.open ? Theme.inverseBg : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: popup.open = !popup.open
    }

    RText {
        id: labelText

        anchors.centerIn: parent
        text: "MENU"
        color: hover.hovered || popup.open ? Theme.inverseText : Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
    }

    Connections {
        target: ShellState

        function onWallpaperOpenChanged(): void {
            if (ShellState.wallpaperOpen)
                popup.open = false;
        }

        function onSessionOpenChanged(): void {
            if (ShellState.sessionOpen)
                popup.open = false;
        }

        function onAppsOpenChanged(): void {
            if (ShellState.appsOpen)
                popup.open = false;
        }

        function onSettingsOpenChanged(): void {
            if (ShellState.settingsOpen)
                popup.open = false;
        }
    }

    BarPopup {
        id: popup

        barWindow: root.window
        screenEdge: "left"
        title: "SYSTEM"
        contentWidth: Theme.popupWidth
        contentHeight: 5 * Theme.popupRowHeight + 4 * Theme.popupRowSpacing + Theme.popupChromeHeight
        open: false

        content: Component {
            Column {
                anchors.fill: parent
                spacing: 4

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
}
