pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Theme
import qs.components
import qs.services

// Audio output panel: one row per sink and per app stream, plus an ALL row for
// the aggregate volume. Opened from the control-center volume tile.
BarPopup {
    id: root

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

    screenEdge: "right"
    title: "AUDIO OUTPUT"
    contentWidth: Theme.popupWidth
    open: false

    content: Component {
        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: root.rows

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
                            font.pixelSize: Theme.fontSmall
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor

                        property real startVolume: 0
                        property real pressY: 0
                        // A vertical drag also produces a click on release; without
                        // this, every volume drag toggled mute at the end.
                        property bool dragged: false

                        function clamp01(v: real): real {
                            return Math.max(0, Math.min(1, v));
                        }

                        onPressed: mouse => {
                            startVolume = deviceRow.rowMuted ? 0 : deviceRow.level;
                            pressY = mouse.y;
                            dragged = false;
                        }

                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const dy = Math.abs(mouse.y - pressY);
                            if (dy < 3)
                                return;
                            dragged = true;
                            const v = clamp01(startVolume - (mouse.y - pressY) / 120);
                            if (deviceRow.isAll)
                                Audio.setVolume(v);
                            else if (deviceRow.isSinkRow)
                                Audio.setSinkVolume(deviceRow.modelData.node, v);
                            else
                                Audio.setStreamVolume(deviceRow.modelData.node, v);
                        }

                        onClicked: {
                            if (dragged) {
                                dragged = false;
                                return;
                            }
                            if (deviceRow.isAll)
                                Audio.toggleMuted();
                            else
                                Audio.toggleNodeMuted(deviceRow.modelData.node);
                        }

                        onWheel: wheel => {
                            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            if (deviceRow.isAll) {
                                Audio.incrementVolume(delta);
                            } else {
                                const current = deviceRow.modelData.node?.audio?.volume ?? 0;
                                if (deviceRow.isSinkRow)
                                    Audio.setSinkVolume(deviceRow.modelData.node, clamp01(current + delta));
                                else
                                    Audio.setStreamVolume(deviceRow.modelData.node, clamp01(current + delta));
                            }
                        }
                    }
                }
            }
        }
    }
}
