pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Polkit password prompt. Shown on the focused monitor whenever the agent has
// a live auth flow, whatever requested it (pkexec in a terminal, a package
// manager, a disk tool). Deliberately modal: exclusive keyboard focus, no
// click-through dismissal, Escape cancels the request.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onFocused: {
        const fm = Hypr.focusedMonitor;
        return !!fm && fm.name === (Hypr.monitorFor(modelData)?.name ?? "");
    }

    readonly property bool showHere: Polkit.active && onFocused

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
    color: "#c0050505"
    focusable: showHere

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowHereChanged: {
        if (!showHere)
            return;
        password.text = "";
        password.forceActiveFocus();
    }

    Box {
        id: frame

        anchors.centerIn: parent
        width: 440
        height: 286
        title: "AUTHENTICATION"

        Column {
            anchors.fill: parent
            spacing: 8

            RText {
                width: parent.width
                text: Polkit.message.length > 0 ? Polkit.message.toUpperCase() : "AUTHENTICATION REQUIRED"
                color: Theme.text
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            RText {
                width: parent.width
                text: Polkit.actionId.length > 0 ? Polkit.actionId : " "
                color: Theme.textMuted
                font.pixelSize: Theme.fontExtraSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            RText {
                width: parent.width
                text: {
                    if (Polkit.detail.length > 0)
                        return Polkit.detail.toUpperCase();
                    if (Polkit.failed)
                        return "AUTHENTICATION FAILED";
                    return " ";
                }
                color: Polkit.detailIsError || Polkit.failed ? Theme.textHigh : Theme.textDim
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            RText {
                width: parent.width
                text: Polkit.prompt.length > 0 ? Polkit.prompt.toUpperCase() : "PASSWORD"
                color: Theme.textDim
                font.pixelSize: Theme.fontSmall
            }

            Rectangle {
                width: parent.width
                height: 30
                color: Theme.surfaceHigh
                border.width: 1
                border.color: password.activeFocus ? Theme.highlight : Theme.borderHigh

                TextInput {
                    id: password

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.textHigh
                    font.family: Theme.family
                    font.pixelSize: Theme.fontSmall
                    selectionColor: Theme.inverseBg
                    selectedTextColor: Theme.inverseText
                    clip: true
                    focus: true

                    onAccepted: root.submit()
                }
            }

            Item {
                width: 1
                height: 4
            }

            Row {
                spacing: 8

                TextButton {
                    label: "AUTHENTICATE"
                    onClicked: root.submit()
                }

                TextButton {
                    label: "CANCEL"
                    danger: true
                    onClicked: Polkit.cancel()
                }
            }

            RText {
                width: parent.width
                text: "ENTER AUTHENTICATE  ESC CANCEL"
                color: Theme.textMuted
                font.pixelSize: Theme.fontExtraSmall
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Polkit.cancel();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submit();
                event.accepted = true;
            }
        }
    }

    Connections {
        function onFlowChanged(): void {
            password.text = "";
            if (root.showHere)
                password.forceActiveFocus();
        }

        target: Polkit
    }

    function submit(): void {
        const value = password.text;
        if (value.length === 0)
            return;
        password.text = "";
        Polkit.submit(value);
    }
}
