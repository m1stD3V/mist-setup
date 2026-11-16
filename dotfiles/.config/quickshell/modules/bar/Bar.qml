pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.components
import qs.services
import qs.modules.discord
import "widgets" as Widgets

// One bar per screen. Layout: a left cluster, a right cluster, and a centered
// group (workspaces + window title) that keeps its true centre regardless of
// how wide the clusters get. The centre group shrinks before it can overlap a
// cluster, and its title disappears when there is no room left.
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

    // Timestamp guard: a chip arms it on press so the click that opens a popup
    // is not also read as a click on empty bar space. It expires on its own, so
    // an aborted press can never swallow a later click. Per-bar (per-screen),
    // unlike the old global boolean, so monitors cannot consume each other's
    // guard.
    property real popupGuardUntil: 0

    function armPopupGuard(): void {
        root.popupGuardUntil = Date.now() + 300;
    }

    function guardActive(): bool {
        return Date.now() < root.popupGuardUntil;
    }

    // Click on empty bar space dismisses whatever popup is open, whichever
    // screen it belongs to. No list of widgets to keep in sync.
    TapHandler {
        onTapped: {
            if (root.guardActive())
                return;
            ShellState.dismissPopup();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.barPad
        anchors.rightMargin: Theme.barPad
        spacing: Theme.barSpacing

        Row {
            id: leftCluster

            spacing: Theme.barSpacing

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

            spacing: Theme.barSpacing

            Widgets.BarModule {
                id: trayModule
                visible: Settings.showTray && tray.visible

                Widgets.Tray {
                    id: tray
                    window: root
                }
            }

            DiscordWidget {
                id: dsc
                window: root
                // gone from the bar once the app is killed; only comes back
                // when Discord is started again
                visible: Settings.showDiscord && Discord.appRunning
            }

            // one opener for everything that used to be its own chip:
            // network, bluetooth, volume, brightness, media, power, notifs
            Widgets.ControlCenter {
                id: sys
                window: root
                visible: Settings.showControlCenter
            }

            // the one reading worth keeping at a glance: boxed like the other
            // modules, but read-only
            Widgets.BarModule {
                id: batteryModule
                visible: Settings.showBattery && Host.batteryPresent
                interactive: false
                accessibleName: Host.batteryPresent ? qsTr("Battery %1%").arg(Math.round(Host.batteryPct * 100)) : ""

                RText {
                    text: Math.round(Host.batteryPct * 100) + "%"
                    color: Host.batteryCharging ? Theme.textHigh : Theme.text
                    font.pixelSize: Theme.fontExtraSmall + 2
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

        // horizontal room between the two clusters, measured after layout
        readonly property real free: Math.max(0, rightCluster.x - leftCluster.x - leftCluster.width - Theme.barSpacing * 2)
        readonly property real wsWidth: workspacesModule.visible ? workspacesModule.implicitWidth + Theme.barSpacing : 0
        readonly property real room: Math.max(0, free - wsWidth)

        visible: (Settings.showWorkspaces || Settings.showActiveWindow) && free > 48
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barSpacing

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
            // a title you cannot read is worse than no title
            visible: Settings.showActiveWindow && centerGroup.room >= 80

            Widgets.ActiveWindow {
                id: activeWindow
                window: root
                width: Math.max(0, Math.min(560, centerGroup.room) - 14)
            }
        }
    }

    // bottom hairline, always exactly on the bar's last pixel
    Rectangle {
        y: root.height - 1
        width: root.width
        height: 1
        color: Theme.barBorder
    }
}
