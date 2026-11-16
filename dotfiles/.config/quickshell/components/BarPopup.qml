pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Layer-shell popup shown below the bar.
//
// Callers choose which screen edge to align to (or center); anchoring to an
// item is also supported. PopupWindow cannot attach to layer surfaces, so
// popouts are their own overlay PanelWindows positioned manually. Each popup
// covers all the space below the bar so clicking anywhere outside the box
// dismisses it.
//
// Sizing is automatic: the content component is measured and the box grows to
// fit it. Callers used to hand-compute `rows * rowHeight + chrome`, which
// drifted out of sync with the theme and clipped the last row whenever a row
// was added. Pass contentHeight explicitly only for a fixed-size box.
PanelWindow {
    id: popupRoot

    required property PanelWindow barWindow
    property Item anchorItem
    property string title: ""
    property int contentWidth: Theme.popupWidth
    // -1 = fit the content's implicit height
    property int contentHeight: -1
    property Component content
    // "left", "right", "center", or "anchor" (center under anchorItem).
    property string screenEdge: "left"
    property bool open: false
    // text fields inside: take exclusive keyboard focus while open
    property bool grabKeyboard: false

    readonly property int padX: Theme.spacingSm
    readonly property int padY: Theme.spacingXs
    // Box reserves 9px on each side plus its double border
    readonly property int innerWidth: Math.max(1, boxW - 18)
    readonly property int screenW: barWindow.screen?.width ?? 0
    readonly property int screenH: barWindow.screen?.height ?? 0
    readonly property int boxW: Math.max(1, Math.min(contentWidth, screenW - padX * 2))
    readonly property int maxBoxH: Math.max(1, screenH - Theme.barHeight - padY * 2)

    readonly property int measuredHeight: loader.item ? loader.item.implicitHeight : 0
    readonly property int naturalHeight: {
        if (contentHeight >= 0)
            return contentHeight;
        const chrome = title.length > 0 ? 4 + Theme.titleBarHeight + 4 : 9;
        return chrome + measuredHeight + 9;
    }
    readonly property int boxH: Math.min(maxBoxH, naturalHeight)

    // Top-left corner of the box, relative to the popup window.
    property int boxX: padX
    readonly property int boxY: padY

    function reposition(): void {
        let x = padX;
        if (screenEdge === "right") {
            x = screenW - boxW - padX;
        } else if (screenEdge === "center") {
            x = Math.round(screenW / 2 - boxW / 2);
        } else if (screenEdge === "anchor" && anchorItem) {
            const rect = barWindow.itemRect(anchorItem);
            x = Math.round(rect.x + rect.width / 2 - boxW / 2);
        }
        // Keep the whole box on screen; on a narrow display the box shrinks
        // (boxW already clamps) instead of hanging off the right edge.
        boxX = Math.max(padX, Math.min(screenW - boxW - padX, x));
    }

    function close(): void {
        open = false;
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
    WlrLayershell.keyboardFocus: open && grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            ShellState.activatePopup(popupRoot);
            reposition();
        } else {
            ShellState.deactivatePopup(popupRoot);
        }
    }

    // Only while open: a closed popup still exists, and a disabled shortcut
    // avoids every popup on every screen claiming Escape at once.
    Shortcut {
        enabled: popupRoot.open
        sequences: ["Escape"]

        onActivated: popupRoot.close()
    }

    onVisibleChanged: if (visible)
        reposition()

    onContentWidthChanged: if (visible)
        reposition()

    onScreenEdgeChanged: if (visible)
        reposition()

    onAnchorItemChanged: if (visible)
        reposition()

    onBoxWChanged: if (visible)
        reposition()

    // Any click outside the box dismisses the popup.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: popupRoot.close()
    }

    // Clicks on the frame's border/padding belong to the popup, not to the
    // dismiss area underneath.
    MouseArea {
        x: popupRoot.boxX
        y: popupRoot.boxY
        width: popupRoot.boxW
        height: popupRoot.boxH
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    }

    Box {
        x: popupRoot.boxX
        y: popupRoot.boxY
        width: popupRoot.boxW
        height: popupRoot.boxH
        title: popupRoot.title

        Loader {
            id: loader

            anchors.fill: parent
            sourceComponent: popupRoot.content
        }
    }
}
