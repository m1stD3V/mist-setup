pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// NetworkManager control panel opened from the overflow menu. Lists Wi-Fi
// and wired devices, connects/disconnects, prompts for passwords on new
// secure networks, and lets saved profiles be forgotten.
BarPopup {
    id: root

    readonly property int rowH: Theme.popupRowHeight
    readonly property int maxRows: 10

    property var passwordNetwork: null
    property var forgetNetwork: null
    property string message: ""
    property bool messageError: false

    signal passwordSubmitted(string psk)

    screenEdge: "left"
    title: "NETWORK"
    contentWidth: Theme.popupWidth
    open: false

    // Take keyboard focus while open so typing a PSK works right away and
    // Escape still closes the panel. BarPopup's focusable alone only maps to
    // on-demand focus, which waits for a click.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int wiredCount: Network.wiredDevices.length
    readonly property int headerHeight: rowH + wiredCount * rowH + 9 + 22
    readonly property int bodyHeight: Math.max(1, Math.min(Network.wifiNetworks.length, maxRows)) * rowH
    readonly property int promptHeight: passwordNetwork !== null ? 36 : (forgetNetwork !== null ? rowH : 0)
    readonly property int footerHeight: 22

    contentHeight: headerHeight + bodyHeight + promptHeight + footerHeight + Theme.popupChromeHeight

    onOpenChanged: {
        if (open) {
            Network.setScanning(true);
        } else {
            Network.setScanning(false);
            passwordNetwork = null;
            forgetNetwork = null;
            message = "";
            messageError = false;
            messageTimer.stop();
        }
    }

    onPasswordSubmitted: psk => root.submitPassword(psk)

    function showMessage(text: string, error: bool): void {
        message = text;
        messageError = error;
        messageTimer.restart();
    }

    function promptPassword(net: var): void {
        forgetNetwork = null;
        passwordNetwork = net;
        message = "PASSWORD FOR " + net.name.toUpperCase();
        messageError = false;
        messageTimer.stop();
    }

    function promptForget(net: var): void {
        passwordNetwork = null;
        forgetNetwork = net;
        message = "";
        messageError = false;
        messageTimer.stop();
    }

    function activate(net: var): void {
        if (!net || Network.stateLabel(net).length > 0)
            return;

        forgetNetwork = null;
        if (net.connected) {
            message = "";
            Network.activate(net);
        } else if (Network.needsPassword(net)) {
            root.promptPassword(net);
        } else if (Network.isEnterprise(net) && !net.known) {
            root.showMessage("802.1X NEEDS MANUAL SETUP", true);
        } else {
            message = "";
            Network.activate(net);
        }
    }

    function submitPassword(psk: string): void {
        const net = passwordNetwork;
        if (!net)
            return;
        if (psk.length < Network.minPasswordLength(net)) {
            root.showMessage("PASSWORD TOO SHORT", true);
            return;
        }
        Network.connectWithPassword(net, psk);
        passwordNetwork = null;
        root.showMessage("CONNECTING...", false);
    }

    function emptyText(): string {
        if (!Network.available)
            return "NO NETWORK BACKEND";
        if (!Network.wifiAvailable)
            return "NO WI-FI ADAPTER";
        if (!Network.wifiOn)
            return "WI-FI DISABLED";
        return "SCANNING...";
    }

    Timer {
        id: messageTimer

        interval: 3500
        onTriggered: {
            root.message = "";
            root.messageError = false;
        }
    }

    Component {
        id: passwordPrompt

        Rectangle {
            color: Theme.surfaceHigh

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            RText {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 38
                anchors.verticalCenter: parent.verticalCenter
                visible: pskField.text.length === 0
                text: "PASSWORD"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }

            TextInput {
                id: pskField

                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 38
                anchors.topMargin: 1
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Theme.textHigh
                font.family: Theme.family
                font.pixelSize: Theme.fontSmall
                selectByMouse: true
                clip: true
                focus: true

                Component.onCompleted: forceActiveFocus()

                onAccepted: root.passwordSubmitted(text)

                Keys.onEscapePressed: event => {
                    root.passwordNetwork = null;
                    root.message = "";
                    event.accepted = true;
                }
            }

            RText {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "OK"
                color: okMouse.containsMouse ? Theme.textHigh : Theme.textDim
                font.pixelSize: Theme.fontExtraSmall + 2

                MouseArea {
                    id: okMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.passwordSubmitted(pskField.text)
                }
            }
        }
    }

    Component {
        id: forgetPrompt

        Rectangle {
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
                text: "FORGET " + (root.forgetNetwork?.name ?? "").toUpperCase() + "?"
                color: Theme.text
                font.pixelSize: Theme.fontExtraSmall + 2
                elide: Text.ElideRight
            }

            RText {
                id: noText

                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "NO"
                color: noMouse.containsMouse ? Theme.textHigh : Theme.textDim
                font.pixelSize: Theme.fontExtraSmall + 2

                MouseArea {
                    id: noMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.forgetNetwork = null;
                        root.message = "";
                    }
                }
            }

            RText {
                id: yesText

                anchors.right: noText.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "YES"
                color: yesMouse.containsMouse ? Theme.textHigh : Theme.textDim
                font.pixelSize: Theme.fontExtraSmall + 2

                MouseArea {
                    id: yesMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Network.forget(root.forgetNetwork);
                        root.forgetNetwork = null;
                        root.showMessage("PROFILE REMOVED", false);
                    }
                }
            }
        }
    }

    content: Component {
        Column {
            anchors.fill: parent
            spacing: 0

            // Wi-Fi radio
            Rectangle {
                width: parent.width
                height: root.rowH
                color: wifiMouse.containsMouse ? Theme.surfaceHigh : "transparent"

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WI-FI"
                    color: Theme.text
                    font.pixelSize: Theme.fontExtraSmall + 2
                }

                RText {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: !Network.available ? "N/A" : (!Network.wifiAvailable ? "NO ADAPTER" : (!Network.wifiHardwareOn ? "HW OFF" : (Network.wifiOn ? "ON" : "OFF")))
                    color: Network.wifiOn && Network.wifiHardwareOn ? Theme.textHigh : Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall + 2
                }

                MouseArea {
                    id: wifiMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!Network.wifiAvailable) {
                            root.showMessage("NO WI-FI ADAPTER", true);
                            return;
                        }
                        if (!Network.wifiHardwareOn) {
                            root.showMessage("WI-FI BLOCKED BY HARDWARE", true);
                            return;
                        }
                        Network.toggleWifi();
                    }
                }
            }

            // Wired devices
            Repeater {
                model: Network.wiredDevices

                delegate: Rectangle {
                    id: wiredRow

                    required property var modelData

                    width: parent.width
                    height: root.rowH
                    color: wiredMouse.containsMouse ? Theme.surfaceHigh : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        RText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "WIRED"
                            color: Theme.text
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, wiredRow.width - 160)
                            text: (wiredRow.modelData.name ?? "").toUpperCase()
                            color: Theme.textDim
                            font.pixelSize: Theme.fontExtraSmall + 2
                            elide: Text.ElideRight
                        }
                    }

                    RText {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: wiredRow.modelData.connected ? "CONNECTED" : (Network.stateLabel(wiredRow.modelData).length > 0 ? Network.stateLabel(wiredRow.modelData) : (wiredRow.modelData.hasLink ? "LINK UP" : "LINK DOWN"))
                        color: wiredRow.modelData.connected ? Theme.textHigh : (wiredRow.modelData.hasLink ? Theme.textDim : Theme.textMuted)
                        font.pixelSize: Theme.fontExtraSmall + 2
                    }

                    MouseArea {
                        id: wiredMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Network.toggleWired(wiredRow.modelData)
                    }
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

            // List heading
            Rectangle {
                width: parent.width
                height: 22
                color: "transparent"

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NETWORKS"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall
                }

                RText {
                    id: scanText

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SCAN"
                    color: scanMouse.containsMouse ? Theme.textHigh : Theme.textDim
                    font.pixelSize: Theme.fontExtraSmall

                    MouseArea {
                        id: scanMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Network.rescan()
                    }
                }
            }

            // Wi-Fi list
            Rectangle {
                width: parent.width
                height: root.bodyHeight
                color: "transparent"

                ListView {
                    id: netList

                    anchors.fill: parent
                    clip: true
                    spacing: 0
                    model: Network.wifiNetworks
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: netRow

                        required property var modelData
                        required property int index

                        readonly property var net: netRow.modelData
                        readonly property bool hovered: netMouse.containsMouse

                        width: netList.width
                        height: root.rowH
                        color: netRow.hovered ? Theme.highlight : "transparent"

                        RText {
                            id: marker

                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: netRow.net?.connected ? ">" : (netRow.net?.known ? "+" : " ")
                            color: netRow.hovered ? Theme.inverseText : (netRow.net?.connected ? Theme.textHigh : Theme.textMuted)
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            id: nameText

                            anchors.left: marker.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, netRow.width - marker.width - rightGroup.width - 22)
                            text: (netRow.net?.name ?? "").toUpperCase()
                            color: netRow.hovered ? Theme.inverseText : Theme.text
                            font.pixelSize: Theme.fontExtraSmall + 2
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Row {
                            id: rightGroup

                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7

                            RText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Network.stateLabel(netRow.net)
                                visible: text.length > 0
                                color: netRow.hovered ? Theme.inverseText : Theme.textHigh
                                font.pixelSize: Theme.fontExtraSmall
                            }

                            RText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Network.securityLabel(netRow.net)
                                visible: Network.stateLabel(netRow.net).length === 0
                                color: netRow.hovered ? Theme.inverseText : Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                            }

                            Row {
                                id: bars

                                readonly property int level: Math.max(1, Math.round((netRow.net?.signalStrength ?? 0) * 4))

                                anchors.verticalCenter: parent.verticalCenter
                                width: 4 * 3 + 3 * 1
                                height: 9
                                spacing: 1

                                Repeater {
                                    model: 4

                                    Rectangle {
                                        required property int index

                                        width: 3
                                        height: 3 + index * 2
                                        anchors.bottom: parent.bottom
                                        color: index < bars.level ? (netRow.hovered ? Theme.inverseText : Theme.accent) : (netRow.hovered ? Theme.textDim : Theme.surfaceHighest)
                                    }
                                }
                            }

                            RText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                horizontalAlignment: Text.AlignRight
                                text: Math.round((netRow.net?.signalStrength ?? 0) * 100) + "%"
                                color: netRow.hovered ? Theme.inverseText : Theme.textDim
                                font.pixelSize: Theme.fontExtraSmall
                            }
                        }

                        MouseArea {
                            id: netMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    if (netRow.net?.known)
                                        root.promptForget(netRow.net);
                                } else {
                                    root.activate(netRow.net);
                                }
                            }
                        }

                        Connections {
                            target: netRow.net
                            ignoreUnknownSignals: true

                            function onConnectionFailed(reason) {
                                root.showMessage(Network.reasonLabel(reason), true);
                            }
                        }
                    }
                }

                RText {
                    anchors.centerIn: parent
                    visible: netList.count === 0
                    text: root.emptyText()
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall + 2
                }

                Rectangle {
                    visible: netList.contentHeight > netList.height
                    x: netList.width - 3
                    y: (netList.height - height) * (netList.contentY / Math.max(1, netList.contentHeight - netList.height))
                    width: 2
                    height: Math.max(12, netList.height * netList.height / Math.max(1, netList.contentHeight))
                    color: Theme.borderHigh
                }
            }

            Loader {
                width: parent.width
                height: root.promptHeight
                sourceComponent: root.passwordNetwork !== null ? passwordPrompt : (root.forgetNetwork !== null ? forgetPrompt : null)
            }

            // Status / help line
            Rectangle {
                width: parent.width
                height: root.footerHeight
                color: "transparent"

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.message.length > 0)
                            return root.message;
                        if (root.passwordNetwork !== null)
                            return "ENTER PASSWORD";
                        if (root.forgetNetwork !== null)
                            return "REMOVE SAVED PROFILE?";
                        if (!Network.available)
                            return "NETWORKMANAGER UNAVAILABLE";
                        return "LMB CONNECT / RMB FORGET";
                    }
                    color: root.messageError ? (Theme.blink ? Theme.textHigh : Theme.textDim) : Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
