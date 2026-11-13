import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Theme
import qs.components
import qs.services

// Volume button: shows the aggregate volume of all active output
// devices. Click opens a popup grouping every device with its own
// meter. Wheel/drag on the button adjusts all devices at once.
Rectangle {
    id: root

    property PanelWindow window

    implicitWidth: btnRow.implicitWidth + 10
    implicitHeight: Theme.barHeight - 10
    color: btnArea.containsMouse || popup.open ? Theme.inverseBg : "transparent"
    border.width: 1
    border.color: btnArea.containsMouse || popup.open ? Theme.inverseBg : Theme.borderHigh

    Row {
        id: btnRow

        anchors.centerIn: parent
        spacing: 8

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: "VOL"
            color: btnArea.containsMouse || popup.open ? Theme.inverseText : Theme.text
            font.pixelSize: Theme.fontExtraSmall + 2
        }

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.muted ? "MUTE" : Math.round(Audio.volume * 100) + "%"
            color: {
                if (btnArea.containsMouse || popup.open)
                    return Theme.inverseText;
                return Audio.muted ? (Theme.blink ? Theme.textHigh : Theme.textMuted) : Theme.textDim;
            }
            font.pixelSize: Theme.fontExtraSmall + 2
        }
    }

    MouseArea {
        id: btnArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: pressed ? Qt.SizeVerCursor : Qt.PointingHandCursor

        property real startVolume: 0
        property real pressY: 0
        property bool dragged: false

        onPressed: mouse => {
            startVolume = Audio.muted ? 0 : Audio.volume;
            pressY = mouse.y;
            dragged = false;
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            if (!dragged && Math.abs(mouse.y - pressY) > 8) {
                dragged = true;
                popup.open = false;
            }
            if (dragged)
                Audio.setVolume(startVolume - (mouse.y - pressY) / 160);
        }

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                ShellState.showOsd("volume", Audio.volume, Audio.muted);
                return;
            }
            if (!dragged)
                popup.open = !popup.open;
        }

        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                Audio.incrementVolume();
            else
                Audio.decrementVolume();
        }
    }

    function closePopup(): void {
        popup.open = false;
    }

    BarPopup {
        id: popup

        readonly property var rows: [{
                "node": null,
                "label": "ALL"
            }].concat(Audio.sinks.map(n => ({
                    "node": n,
                    "label": Audio.sinkLabel(n)
                })), Audio.streams.map(n => ({
                    "node": n,
                    "label": Audio.streamLabel(n)
                })))

        barWindow: root.window
        screenEdge: "right"
        title: "AUDIO OUTPUT"
        contentWidth: Theme.popupWidth
        contentHeight: rows.length * Theme.popupRowHeight + Theme.popupChromeHeight
        open: false

        content: Component {
            Column {
                anchors.fill: parent
                spacing: 2

                Repeater {
                    model: popup.rows

                    delegate: Item {
                        id: deviceRow

                        required property var modelData

                        readonly property bool isAll: modelData.node === null
                        readonly property bool isSinkRow: !isAll && Audio.sinks.includes(modelData.node)
                        readonly property real level: isAll ? (Audio.muted ? 0 : Audio.volume) : (modelData.node?.audio?.volume ?? 0)
                        readonly property bool rowMuted: isAll ? Audio.muted : (modelData.node?.audio?.muted ?? false)

                        implicitWidth: rowContent.width + 8
                        implicitHeight: Theme.popupRowHeight

                        Row {
                            id: rowContent

                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Meter {
                                anchors.verticalCenter: parent.verticalCenter
                                label: deviceRow.modelData.label
                                value: deviceRow.rowMuted ? 0 : deviceRow.level
                                segments: 8
                                showPct: false
                            }

                            RText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: deviceRow.rowMuted ? "MUTED" : Math.round(deviceRow.level * 100) + "%"
                                color: deviceRow.rowMuted ? (Theme.blink ? Theme.textHigh : Theme.textMuted) : Theme.textDim
                                font.pixelSize: Theme.fontExtraSmall + 2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor

                            property real startVolume: 0
                            property real pressY: 0

                            onPressed: mouse => {
                                startVolume = deviceRow.rowMuted ? 0 : deviceRow.level;
                                pressY = mouse.y;
                            }

                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return;
                                const v = Math.max(0, Math.min(1, startVolume - (mouse.y - pressY) / 120));
                                if (deviceRow.isAll)
                                    Audio.setVolume(v);
                                else if (deviceRow.isSinkRow)
                                    Audio.setSinkVolume(deviceRow.modelData.node, v);
                                else
                                    Audio.setStreamVolume(deviceRow.modelData.node, v);
                            }

                            onClicked: {
                                if (deviceRow.isAll)
                                    Audio.toggleMuted();
                                else
                                    Audio.toggleNodeMuted(deviceRow.modelData.node);
                            }

                            onWheel: wheel => {
                                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                if (deviceRow.isAll)
                                    Audio.incrementVolume(delta);
                                else if (deviceRow.isSinkRow)
                                    Audio.setSinkVolume(deviceRow.modelData.node, (deviceRow.modelData.node?.audio?.volume ?? 0) + delta);
                                else
                                    Audio.setStreamVolume(deviceRow.modelData.node, (deviceRow.modelData.node?.audio?.volume ?? 0) + delta);
                            }
                        }
                    }
                }
            }
        }
    }
}
