pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Layer-shell popup shown below the bar. Callers choose which screen edge to
// align to (or center); anchoring to an item is also supported.
// PopupWindow cannot attach to layer surfaces, so popouts are their own
// overlay PanelWindows positioned manually. Each popup covers all the space
// below the bar so clicking anywhere outside the box dismisses it.
PanelWindow {
    id: popupRoot

    required property PanelWindow barWindow
    property Item anchorItem
    property string title: ""
    property int contentWidth: Theme.popupWidth
    property int contentHeight: 100
    property Component content
    // "left", "right", "center", or "anchor" (center under anchorItem).
    property string screenEdge: "left"
    property bool open: false

    // Top-left corner of the box, relative to the popup window.
    property int boxX: Theme.spacingSm
    readonly property int boxY: Theme.spacingXs

    function reposition(): void {
        const screenW = barWindow.screen?.width ?? 0;
        let x = Theme.spacingSm;
        if (screenEdge === "right") {
            x = screenW - contentWidth - Theme.spacingSm;
        } else if (screenEdge === "center") {
            x = Math.round(screenW / 2 - contentWidth / 2);
        } else if (screenEdge === "anchor" && anchorItem) {
            const rect = barWindow.itemRect(anchorItem);
            x = Math.round(rect.x + rect.width / 2 - contentWidth / 2);
        }
        boxX = Math.max(Theme.spacingSm, Math.min(screenW - contentWidth - Theme.spacingSm, x));
    }

    visible: open
    screen: barWindow.screen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // Leave the bar itself usable; the window catches everything below it.
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "transparent"
    focusable: open

    WlrLayershell.layer: WlrLayer.Overlay

    onOpenChanged: {
        if (open)
            ShellState.activatePopup(popupRoot);
        else
            ShellState.deactivatePopup(popupRoot);
    }

    Shortcut {
        sequences: ["Escape"]

        onActivated: popupRoot.open = false
    }

    onVisibleChanged: if (visible)
        reposition()

    onContentWidthChanged: if (visible)
        reposition()

    onScreenEdgeChanged: if (visible)
        reposition()

    onAnchorItemChanged: if (visible)
        reposition()

    // Any click outside the box dismisses the popup.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: popupRoot.open = false
    }

    // Clicks on the frame's border/padding belong to the popup, not to the
    // dismiss area underneath.
    MouseArea {
        x: popupRoot.boxX
        y: popupRoot.boxY
        width: popupRoot.contentWidth
        height: popupRoot.contentHeight
    }

    Box {
        x: popupRoot.boxX
        y: popupRoot.boxY
        width: popupRoot.contentWidth
        height: popupRoot.contentHeight
        title: popupRoot.title

        Loader {
            anchors.fill: parent
            sourceComponent: popupRoot.content
        }
    }
}
