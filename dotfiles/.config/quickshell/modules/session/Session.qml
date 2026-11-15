pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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

    readonly property bool showHere: ShellState.sessionOpen && onFocused

    // frame is designed for a 1920x1080 logical desktop; shrink proportionally
    // on smaller screens so the window always fits
    readonly property real frameScale: Math.min(1, Math.min(modelData.width / 1920, modelData.height / 1080))

    readonly property var actions: [{
            "label": "SHUTDOWN",
            "cmd": ["systemctl", "poweroff"]
        }, {
            "label": "REBOOT",
            "cmd": ["systemctl", "reboot"]
        }, {
            "label": "LOGOUT",
            "cmd": ["hyprctl", "dispatch", "exit"]
        }]

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
    focusable: ShellState.sessionOpen

    WlrLayershell.layer: WlrLayer.Overlay

    property int selected: 0

    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.toggleSession()
    }

    Box {
        id: frame

        anchors.centerIn: parent
        width: 320
        height: 220
        // transformOrigin defaults to Item.Center, so the scaled frame stays centered
        scale: root.frameScale
        title: "SYSTEM MENU"
        focus: root.showHere

        Column {
            anchors.fill: parent
            spacing: 6

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: actionEntry

                    required property var modelData
                    required property int index

                    readonly property bool selected: index === root.selected

                    width: parent.width
                    height: 34
                    color: selected ? Theme.highlight : Theme.bg
                    border.width: 1
                    border.color: selected ? Theme.highlight : Theme.border

                    RText {
                        anchors.centerIn: parent
                        text: actionEntry.modelData.label
                        color: actionEntry.selected ? Theme.inverseText : Theme.text
                        font.pixelSize: Theme.fontSmall + 2
                    }

                    HoverHandler {
                        onHoveredChanged: if (hovered)
                            root.selected = actionEntry.index
                    }

                    TapHandler {
                        onTapped: root.run(actionEntry.modelData.cmd)
                    }
                }
            }

            Item {
                width: 1
                height: 10
            }

            RText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ENTER CONFIRM  ESC CANCEL"
                color: Theme.textMuted
                font.pixelSize: Theme.fontExtraSmall
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                ShellState.toggleSession();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                root.selected = (root.selected + 1) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                root.selected = (root.selected + root.actions.length - 1) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.run(root.actions[root.selected].cmd);
                event.accepted = true;
            }
        }

    }

    function run(cmd: list<string>): void {
        ShellState.sessionOpen = false;
        execProc.command = cmd;
        execProc.running = true;
    }

    Process {
        id: execProc
    }

    // initial keyboard focus
    onShowHereChanged: if (showHere)
        frame.forceActiveFocus()
}
