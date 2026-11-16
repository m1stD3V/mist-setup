pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onFocused: {
        const fm = Hypr.focusedMonitor;
        return !!fm && fm.name === (Hypr.monitorFor(modelData)?.name ?? "");
    }

    readonly property bool showHere: ShellState.sysmonOpen && onFocused

    readonly property int frameWidth: 540
    readonly property int frameHeight: 390

    // shrink only if the frame cannot fit this screen at full size
    readonly property real frameScale: Theme.fitScale(modelData.width, modelData.height, root.frameWidth, root.frameHeight)

    screen: modelData
    visible: showHere
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "#b0050505"
    focusable: ShellState.sysmonOpen

    WlrLayershell.layer: WlrLayer.Overlay

    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.toggleSysmon()
    }

    Box {
        anchors.centerIn: parent
        width: root.frameWidth
        height: root.frameHeight
        // transformOrigin defaults to Item.Center, so the scaled frame stays centered
        scale: root.frameScale
        title: "SYSTEM STATUS"

        Column {
            anchors.fill: parent
            spacing: Theme.spacingSm

            // text rows
            Repeater {
                model: ScriptModel {
                    values: [{
                            "k": "HOST",
                            "v": Host.hostname.toUpperCase()
                        }, {
                            "k": "OS",
                            "v": Host.distro.toUpperCase()
                        }, {
                            "k": "KERNEL",
                            "v": Host.kernel
                        }, {
                            "k": "UPTIME",
                            "v": Host.formatUptime(Host.uptime).toUpperCase()
                        }, {
                            "k": "SESSION",
                            "v": "HYPRLAND/WAYLAND"
                        }]
                }

                delegate: Row {
                    id: infoRow

                    required property var modelData

                    width: parent.width
                    spacing: Theme.spacingSm

                    RText {
                        width: 90
                        text: infoRow.modelData.k
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                    }

                    RText {
                        width: parent.width - 98
                        text: infoRow.modelData.v
                        color: Theme.text
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                width: 1
                height: 8
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderHigh
            }

            Item {
                width: 1
                height: 8
            }

            Meter {
                width: parent.width
                label: "CPU"
                value: Host.cpu
                segments: 20
                segH: 14
            }

            Meter {
                width: parent.width
                label: "MEM"
                value: Host.mem
                segments: 20
                segH: 14
            }

            Meter {
                width: parent.width
                visible: Host.batteryPresent
                label: "PWR"
                value: Host.batteryPct
                segments: 20
                segH: 14
            }

            RText {
                width: parent.width
                visible: Host.batteryPresent
                text: (Host.batteryCharging ? "STATUS: CHARGING" : "STATUS: DISCHARGING") + (Host.battery.timeToEmpty > 0 ? "  -  " + Host.formatUptime(Host.battery.timeToEmpty).toUpperCase() + " REMAIN" : "")
                color: Theme.textDim
                font.pixelSize: Theme.fontExtraSmall
            }

            Item {
                width: 1
                height: 10
            }

            RText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "PRESS ESC TO CLOSE"
                color: Theme.textMuted
                font.pixelSize: Theme.fontExtraSmall
            }
        }

        Shortcut {
            sequences: ["Escape"]

            onActivated: ShellState.toggleSysmon()
        }
    }
}
