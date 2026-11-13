pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.services
import qs.modules.discord
import "widgets" as Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight
    color: Theme.barBg

    // click on empty bar space dismisses popups
    TapHandler {
        onTapped: {
            if (ShellState.popupClickGuard) {
                ShellState.popupClickGuard = false;
                return;
            }
            tray?.closeMenu();
            vol?.closePopup();
            ntf?.closePopup();
            dsc?.closePopup();
            menu?.closePopup();
            search?.closePopup();
            clock?.closePopup();
            activeWindow?.closePopup();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm
        spacing: 6

        Row {
            id: leftCluster

            spacing: 8

            Widgets.Menu {
                id: menu
                window: root
                visible: Settings.showMenu
            }

            Widgets.SearchBar {
                id: search
                window: root
                visible: Settings.showSearch
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Row {
            id: rightCluster

            spacing: 6

            Widgets.BarModule {
                visible: Settings.showTray && tray.visible

                Widgets.Tray {
                    id: tray
                    window: root
                }
            }

            Widgets.NotifButton {
                id: ntf
                window: root
                visible: Settings.showNotifications
            }

            Row {
                spacing: 4

                DiscordWidget {
                    id: dsc
                    window: root
                    visible: Settings.showDiscord && Discord.bridgeUp
                }
                Widgets.Volume {
                    id: vol
                    window: root
                    visible: Settings.showVolume
                }
            }

            Widgets.BarModule {
                visible: Settings.showBattery && battery.visible

                Widgets.BatteryW {
                    id: battery
                }
            }

            Widgets.Clock {
                id: clock
                window: root
                visible: Settings.showClock
            }
        }
    }

    // workspaces + active window, centered together as one group in the
    // true center of the bar regardless of cluster widths
    RowLayout {
        id: centerGroup

        readonly property real leftEdge: Theme.spacingSm + leftCluster.implicitWidth + 6
        readonly property real rightEdge: root.width - Theme.spacingSm - rightCluster.implicitWidth - 6
        readonly property real halfSpace: Math.max(0, Math.min(root.width / 2 - leftEdge, rightEdge - root.width / 2))

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: activeWindowModule.visible && workspacesModule.visible ? 10 : 0

        Widgets.BarModule {
            id: workspacesModule
            Layout.alignment: Qt.AlignVCenter
            visible: Settings.showWorkspaces

            Widgets.Workspaces {
                id: workspaces
                screen: root.modelData
            }
        }

        Widgets.BarModule {
            id: activeWindowModule
            Layout.alignment: Qt.AlignVCenter
            visible: Settings.showActiveWindow

            Widgets.ActiveWindow {
                id: activeWindow
                window: root
                width: Math.max(0, Math.min(560, implicitWidth, centerGroup.halfSpace * 2 - workspacesModule.implicitWidth - centerGroup.spacing - 10))
            }
        }
    }

    Rectangle {
        y: root.height - 1
        width: root.width
        height: 1
        color: Theme.barBorder
    }
}
