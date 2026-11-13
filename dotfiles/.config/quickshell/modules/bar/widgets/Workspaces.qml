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

            color: isActive ? Theme.inverseBg : "transparent"

            RText {
                anchors.centerIn: parent
                text: cell.isActive || cell.occupied || cell.hovered ? cell.wsId : "·"
                font.pixelSize: Theme.fontSmall
                color: {
                    if (cell.isActive)
                        return Theme.inverseText;
                    if (cell.occupied || cell.hovered)
                        return Theme.text;
                    return Theme.textMuted;
                }
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
