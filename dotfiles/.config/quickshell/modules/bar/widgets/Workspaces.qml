pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

Row {
    id: root

    required property ShellScreen screen

    readonly property var mon: Hypr.monitorFor(screen)
    readonly property bool monActive: Hypr.focusedMonitor?.name === mon?.name

    spacing: 2

    Repeater {
        model: 5

        Rectangle {
            id: cell

            required property int index

            readonly property int wsId: index + 1
            readonly property bool isActive: root.monActive && Hypr.activeWsId === wsId
            readonly property bool occupied: Hypr.workspaces.values.some(w => w.id === wsId && (w.lastIpcObject?.windows ?? 0) > 0)

            implicitWidth: 18
            implicitHeight: Theme.barHeight - 10
            radius: 0

            readonly property bool hovered: mouse.containsMouse

            color: "transparent"

            // highlight inset from the container border so it reads as a
            // separate chip rather than touching the frame
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                anchors.leftMargin: 1
                anchors.rightMargin: 1
                color: cell.isActive ? Theme.highlight : "transparent"
            }

            RText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                text: cell.isActive || cell.occupied || cell.hovered ? cell.wsId : "·"
                font.pixelSize: Theme.fontSmall
                color: {
                    if (cell.isActive)
                        return Theme.inverseText;
                    if (cell.occupied || cell.hovered)
                        return Theme.text;
                    return Theme.textMuted;
                }

                // Tiny5 leaves a wide right side bearing after each glyph, so
                // centring the text box puts numbers left of the cell's centre.
                // Centre the ink box instead.
                TextMetrics {
                    id: ink

                    font.family: label.font.family
                    font.pixelSize: label.font.pixelSize
                    text: label.text
                }

                x: (cell.width - width) / 2 + (width - ink.boundingRect.width) / 2 - ink.boundingRect.x
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: Hypr.focusWorkspace(cell.wsId)
            }
        }
    }
}
