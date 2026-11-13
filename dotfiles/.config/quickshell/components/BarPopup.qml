pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components

// Layer-shell popup shown below the bar. Callers choose which screen edge to
// align to (or center); anchoring to an item is also supported.
// PopupWindow cannot attach to layer surfaces, so popouts are their own
// overlay PanelWindows positioned manually.
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
        margins.left = Math.max(Theme.spacingSm, Math.min(screenW - contentWidth - Theme.spacingSm, x));
        margins.top = Theme.barHeight + Theme.spacingXs;
    }

    visible: open
    screen: barWindow.screen
    anchors {
        top: true
        left: true
    }
    implicitWidth: contentWidth
    implicitHeight: contentHeight
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "transparent"
    focusable: open

    WlrLayershell.layer: WlrLayer.Overlay

    Shortcut {
        sequences: ["Escape"]

        onActivated: popupRoot.open = false
    }

    onVisibleChanged: if (visible)
        reposition()

    onContentHeightChanged: if (visible)
        reposition()

    onContentWidthChanged: if (visible)
        reposition()

    Box {
        anchors.fill: parent
        title: popupRoot.title

        Loader {
            anchors.fill: parent
            sourceComponent: popupRoot.content
        }
    }
}
