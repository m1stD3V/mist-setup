import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Battery button: shows charge level; click opens the power profile picker.
Rectangle {
    id: root

    property PanelWindow window

    readonly property bool hot: hover.hovered || popup.open

    function closePopup(): void {
        popup.open = false;
    }

    implicitWidth: btnRow.implicitWidth + 10
    implicitHeight: Theme.barHeight - 10
    color: "transparent"
    border.width: 1
    border.color: root.hot ? Theme.highlight : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: popup.open = !popup.open
    }

    Row {
        id: btnRow

        anchors.centerIn: parent
        spacing: Theme.spacingSm

        Meter {
            anchors.verticalCenter: parent.verticalCenter
            label: "PWR"
            value: Host.batteryPct
            segments: 6
            showPct: false
        }

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Host.batteryPct * 100) + "%" + (Host.batteryCharging ? "+" : "")
            color: Theme.textDim
            font.pixelSize: Theme.fontExtraSmall + 2
        }
    }

    BarPopup {
        id: popup

        readonly property int rowH: Theme.popupRowHeight
        readonly property int listH: Math.max(1, PowerProfiles.profiles.length) * rowH

        barWindow: root.window
        screenEdge: "right"
        title: "POWER"
        contentWidth: Theme.popupWidth
        contentHeight: Theme.popupChromeHeight + rowH + 9 + listH + 22
        open: false

        onOpenChanged: if (open)
            PowerProfiles.refresh()

        content: Component {
            Column {
                anchors.fill: parent
                spacing: 0

                // battery summary
                Rectangle {
                    width: parent.width
                    height: popup.rowH
                    color: "transparent"

                    RText {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "BATTERY"
                        color: Theme.text
                        font.pixelSize: Theme.fontExtraSmall + 2
                    }

                    RText {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Host.batteryPct * 100) + "%  " + (Host.batteryCharging ? "CHARGING" : "DISCHARGING") + (Host.battery?.timeToEmpty > 0 ? "  " + Host.formatUptime(Host.battery.timeToEmpty).toUpperCase() + " LEFT" : "")
                        color: Host.batteryCharging ? Theme.textHigh : Theme.textDim
                        font.pixelSize: Theme.fontExtraSmall + 2
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 9
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }
                }

                // power profiles
                Item {
                    width: parent.width
                    height: popup.listH

                    Column {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: PowerProfiles.profiles

                            delegate: Rectangle {
                                id: profileRow

                                required property var modelData

                                readonly property bool isActive: profileRow.modelData.name === PowerProfiles.activeProfile

                                width: parent.width
                                height: popup.rowH
                                color: rowMouse.containsMouse ? Theme.highlight : "transparent"

                                RText {
                                    id: marker

                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: profileRow.isActive ? ">" : " "
                                    color: rowMouse.containsMouse ? Theme.inverseText : (profileRow.isActive ? Theme.textHigh : Theme.textMuted)
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }

                                RText {
                                    anchors.left: marker.right
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: profileRow.modelData.label
                                    color: rowMouse.containsMouse ? Theme.inverseText : (profileRow.isActive ? Theme.textHigh : Theme.text)
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }

                                RText {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: profileRow.isActive ? "ACTIVE" : ""
                                    color: rowMouse.containsMouse ? Theme.inverseText : Theme.textDim
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                MouseArea {
                                    id: rowMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PowerProfiles.setProfile(profileRow.modelData.name)
                                }
                            }
                        }
                    }

                    RText {
                        anchors.centerIn: parent
                        visible: PowerProfiles.profiles.length === 0
                        text: PowerProfiles.available ? "NO PROFILES" : "POWER PROFILES UNAVAILABLE"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontExtraSmall + 2
                    }
                }

                // status / help line
                Rectangle {
                    width: parent.width
                    height: 22
                    color: "transparent"

                    RText {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (PowerProfiles.error.length > 0)
                                return PowerProfiles.error;
                            if (PowerProfiles.switching)
                                return "SWITCHING PROFILE...";
                            if (!PowerProfiles.available)
                                return "POWER-PROFILES-DAEMON UNAVAILABLE";
                            return "LMB SELECT PROFILE";
                        }
                        color: PowerProfiles.error.length > 0 ? (Theme.blink ? Theme.textHigh : Theme.textDim) : Theme.textMuted
                        font.pixelSize: Theme.fontExtraSmall
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
