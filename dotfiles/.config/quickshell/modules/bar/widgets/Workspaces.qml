pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Workspace strip. The visible range is not a magic "5": it is the user's
// configured count plus any workspace that actually exists (named or
// persistent ones included), so a workspace created by a keybind or another
// monitor is never invisible. Occupancy is computed once per change instead of
// scanning the workspace list inside every cell.
Row {
    id: root

    required property ShellScreen screen

    readonly property var mon: Hypr.monitorFor(screen)
    readonly property bool monActive: Hypr.focusedMonitor?.name === mon?.name
    readonly property int activeId: Hypr.activeWsId

    readonly property var ids: {
        const count = Math.max(1, Math.min(32, Settings.workspaceCount));
        const set = new Set();
        for (let i = 1; i <= count; ++i)
            set.add(i);
        for (const w of (Hypr.workspaces?.values ?? [])) {
            const id = Number(w?.id);
            if (Number.isFinite(id) && id > 0)
                set.add(id);
        }
        if (Number.isFinite(root.activeId) && root.activeId > 0)
            set.add(root.activeId);
        return [...set].sort((a, b) => a - b);
    }

    // one pass over the workspace list; O(1) lookup per cell
    readonly property var occupied: {
        const out = new Set();
        for (const w of (Hypr.workspaces?.values ?? [])) {
            if ((w?.lastIpcObject?.windows ?? 0) > 0)
                out.add(Number(w.id));
        }
        return out;
    }

    readonly property var names: {
        const out = {};
        for (const w of (Hypr.workspaces?.values ?? [])) {
            const name = String(w?.name ?? "");
            if (name.length > 0 && name !== String(w?.id))
                out[Number(w.id)] = name;
        }
        return out;
    }

    spacing: 2

    function step(delta: int): void {
        const target = root.activeId + delta;
        if (target >= 1)
            Hypr.focusWorkspace(target);
    }

    // wheel scrolls through workspaces like the pager it looks like
    WheelHandler {
        onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
    }

    Repeater {
        model: root.ids

        Rectangle {
            id: cell

            required property int modelData

            readonly property bool isActive: root.monActive && root.activeId === cell.modelData
            readonly property bool isOccupied: root.occupied.has(cell.modelData)
            readonly property string wsName: root.names[cell.modelData] ?? ""

            implicitWidth: 18
            implicitHeight: Theme.barChipHeight
            radius: 0

            readonly property bool hovered: mouse.containsMouse

            color: "transparent"

            Accessible.role: Accessible.Button
            Accessible.name: cell.wsName.length > 0 ? cell.wsName : qsTr("Workspace %1").arg(cell.modelData)

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
                text: {
                    // a named workspace keeps its initial so the strip still
                    // tells you which one you are on
                    if (cell.wsName.length > 0 && (cell.isActive || cell.isOccupied || cell.hovered))
                        return cell.wsName.charAt(0).toUpperCase();
                    return cell.isActive || cell.isOccupied || cell.hovered ? String(cell.modelData) : "·";
                }
                font.pixelSize: Theme.fontSmall
                color: {
                    if (cell.isActive)
                        return Theme.inverseText;
                    if (cell.isOccupied || cell.hovered)
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

                onClicked: Hypr.focusWorkspace(cell.modelData)
            }
        }
    }
}
