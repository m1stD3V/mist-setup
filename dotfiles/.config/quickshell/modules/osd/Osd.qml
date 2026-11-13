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

    readonly property real osdValue: ShellState.osdKind === "volume" && ShellState.osdMuted ? 0 : ShellState.osdValue

    screen: modelData
    visible: ShellState.osdVisible
    anchors {
        top: true
        left: true
    }
    implicitWidth: 360
    implicitHeight: 84
    margins.top: Theme.barHeight + 12
    margins.left: Math.round((modelData.width - implicitWidth) / 2)
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "transparent"
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay

    Box {
        anchors.centerIn: parent
        width: 360
        height: 84
        title: ShellState.osdKind === "volume" ? "AUDIO OUTPUT" : "BRIGHTNESS"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor

            property real startVolume: 0
            property real pressY: 0

            onPressed: mouse => {
                startVolume = Audio.muted ? 0 : Audio.volume;
                pressY = mouse.y;
            }

            onPositionChanged: mouse => {
                if (pressed)
                    Audio.setVolume(startVolume - (mouse.y - pressY) / 80);
            }

            onWheel: wheel => {
                if (wheel.angleDelta.y > 0)
                    Audio.incrementVolume();
                else
                    Audio.decrementVolume();
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingMd

            Meter {
                anchors.verticalCenter: parent.verticalCenter
                label: ShellState.osdKind === "volume" ? "VOL" : "BRT"
                value: root.osdValue
                segments: 16
                segH: 16
            }
        }
    }
}
