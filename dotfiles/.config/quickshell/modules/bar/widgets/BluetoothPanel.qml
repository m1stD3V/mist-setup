pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Bluetooth devices behind the bar's BT chip: power, scanning, connect and
// forget. Pairing happens inside bluetoothctl when a device is clicked; there
// is no passkey prompt yet, so keyboards that ask for one need blueman.
BarPopup {
    id: root

    readonly property int rowH: Theme.popupRowHeight
    readonly property int maxRows: 8

    // unpaired devices are only useful while a scan is running
    readonly property var rows: Bluetooth.devices.filter(d => d.paired || d.connected || Bluetooth.discovering)
    readonly property int visibleRows: Math.min(rows.length, maxRows)
    readonly property bool listVisible: Bluetooth.powered && visibleRows > 0

    property var forgetDevice: null

    signal deviceClicked(var device)

    screenEdge: "right"
    title: "BLUETOOTH"
    contentWidth: Theme.popupWidth
    open: false

    onOpenChanged: {
        if (open) {
            Bluetooth.clearMessage();
            Bluetooth.setScanning(true);
        } else {
            Bluetooth.setScanning(false);
            forgetDevice = null;
        }
    }

    onDeviceClicked: device => Bluetooth.toggleDevice(device)

    function emptyText(): string {
        if (!Bluetooth.available)
            return "NO BLUETOOTH ADAPTER";
        if (!Bluetooth.powered)
            return "BLUETOOTH IS OFF";
        if (rows.length === 0)
            return Bluetooth.discovering ? "SCANNING..." : "NO KNOWN DEVICES";
        return "";
    }

    content: Component {
        Column {
            width: parent.width
            spacing: 0

            // adapter power
            Rectangle {
                width: parent.width
                height: root.rowH
                color: powerMouse.containsMouse ? Theme.surfaceHigh : "transparent"

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BLUETOOTH"
                    color: Theme.text
                    font.pixelSize: Theme.fontSmall
                }

                RText {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: !Bluetooth.available ? "N/A" : (Bluetooth.powered ? (Bluetooth.busy ? "..." : "ON") : "OFF")
                    color: Bluetooth.powered ? Theme.textHigh : Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }

                MouseArea {
                    id: powerMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Bluetooth.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Bluetooth.togglePower()
                }
            }

            // separator
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

            // list heading
            Rectangle {
                width: parent.width
                height: 26
                color: "transparent"

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DEVICES"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall + 2
                }

                RText {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Bluetooth.discovering ? "SCANNING" : "SCAN"
                    color: Bluetooth.powered ? (scanMouse.containsMouse ? Theme.textHigh : Theme.textDim) : Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall + 2

                    MouseArea {
                        id: scanMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!Bluetooth.powered)
                                return;
                            Bluetooth.setScanning(false);
                            Bluetooth.setScanning(true);
                        }
                    }
                }
            }

            // device list
            Rectangle {
                width: parent.width
                height: Math.max(1, root.visibleRows) * root.rowH
                color: "transparent"

                RText {
                    anchors.centerIn: parent
                    visible: !root.listVisible
                    text: root.emptyText()
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }

                ListView {
                    anchors.fill: parent
                    visible: root.listVisible
                    clip: true
                    interactive: false
                    model: root.rows.slice(0, root.maxRows)

                    delegate: Rectangle {
                        id: deviceRow

                        required property var modelData

                        readonly property bool forgetTarget: root.forgetDevice !== null && root.forgetDevice.mac === modelData.mac

                        width: ListView.view.width
                        height: root.rowH
                        color: deviceMouse.containsMouse || forgetTarget ? Theme.surfaceHigh : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.right: statusText.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            RText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, deviceRow.width - 180)
                                text: deviceRow.modelData.name.toUpperCase()
                                color: deviceRow.modelData.connected ? Theme.textHigh : Theme.text
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        RText {
                            id: statusText

                            anchors.right: forgetText.visible ? forgetText.left : parent.right
                            anchors.rightMargin: forgetText.visible ? 10 : 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: deviceRow.modelData.connected ? "CONNECTED" : (deviceRow.modelData.paired ? "PAIRED" : "NEW")
                            color: deviceRow.modelData.connected ? Theme.textHigh : Theme.textDim
                            font.pixelSize: Theme.fontExtraSmall
                        }

                        RText {
                            id: forgetText

                            visible: deviceRow.modelData.paired || deviceRow.modelData.connected
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "X"
                            color: forgetMouse.containsMouse ? Theme.textHigh : Theme.textMuted
                            font.pixelSize: Theme.fontSmall

                            MouseArea {
                                id: forgetMouse

                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.forgetDevice = deviceRow.modelData
                            }
                        }

                        MouseArea {
                            id: deviceMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deviceClicked(deviceRow.modelData)
                        }
                    }
                }
            }

            // forget confirmation
            Rectangle {
                visible: root.forgetDevice !== null
                width: parent.width
                height: visible ? root.rowH : 0
                color: Theme.surfaceHigh

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: noText.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "FORGET " + (root.forgetDevice?.name ?? "").toUpperCase() + "?"
                    color: Theme.text
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                RText {
                    id: noText

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NO"
                    color: noMouse.containsMouse ? Theme.textHigh : Theme.textDim
                    font.pixelSize: Theme.fontSmall

                    MouseArea {
                        id: noMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.forgetDevice = null
                    }
                }

                RText {
                    id: yesText

                    anchors.right: noText.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "YES"
                    color: yesMouse.containsMouse ? Theme.textHigh : Theme.textDim
                    font.pixelSize: Theme.fontSmall

                    MouseArea {
                        id: yesMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Bluetooth.forget(root.forgetDevice.mac);
                            root.forgetDevice = null;
                        }
                    }
                }
            }

            // message line
            Rectangle {
                width: parent.width
                height: 26
                color: "transparent"

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: Bluetooth.message.length > 0 ? Bluetooth.message : (Bluetooth.connectedCount > 0 ? Bluetooth.connectedCount + " CONNECTED" : "")
                    color: Bluetooth.messageError ? Theme.textHigh : Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
