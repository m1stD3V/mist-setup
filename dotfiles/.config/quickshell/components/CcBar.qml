import QtQuick
import qs.Theme

// Stretchy segmented bar for control-center tiles. Segments divide whatever
// width the tile gives them, so the same component works in a half-width tile
// and in a full-width one without a fixed pixel count. Dragging along it or
// using the wheel sets the value; set interactive: false for a read-only
// gauge.
Item {
    id: root

    property real value: 0
    property int segments: 20
    property int gap: 2
    // muted/off: filled blocks drop to the dim text colour instead of accent
    property bool muted: false
    property bool interactive: true
    property color fill: Theme.accent
    property color empty: Theme.surfaceHighest

    signal setValue(real value)

    implicitHeight: 12

    function setFromX(x: real): void {
        if (root.width <= 0)
            return;
        root.setValue(Math.max(0, Math.min(1, x / root.width)));
    }

    Row {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.segments

            delegate: Rectangle {
                required property int index

                width: Math.max(1, (root.width - root.gap * (root.segments - 1)) / root.segments)
                height: root.height
                color: index < Math.round(root.value * root.segments) ? (root.muted ? Theme.textMuted : root.fill) : root.empty
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.setFromX(mouse.x);
        }
        onWheel: wheel => root.setValue(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
