import QtQuick
import qs.Theme
import qs.components

// Labeled horizontal slider with keyboard-free drag and wheel support.
Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.01
    property real displayScale: 1
    property string suffix: ""

    signal moved(real value)

    readonly property real ratio: Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))

    implicitHeight: 46

    function clampValue(v: real): real {
        const clamped = Math.max(root.from, Math.min(root.to, v));
        if (root.step <= 0)
            return clamped;
        return Math.max(root.from, Math.min(root.to, Math.round(clamped / root.step) * root.step));
    }

    function emitAt(px: real): void {
        const r = Math.max(0, Math.min(1, px / track.width));
        root.moved(root.clampValue(root.from + r * (root.to - root.from)));
    }

    RText {
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
    }

    RText {
        anchors.right: parent.right
        anchors.top: parent.top
        text: Math.round(root.value * root.displayScale) + root.suffix
        color: Theme.textDim
        font.pixelSize: Theme.fontExtraSmall + 2
    }

    Item {
        id: trackArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 22
        height: 18

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            color: Theme.surfaceHigh
            border.width: 1
            border.color: Theme.border
        }

        Rectangle {
            anchors.left: track.left
            anchors.verticalCenter: track.verticalCenter
            width: track.width * root.ratio
            height: track.height
            color: Theme.inverseBg
        }

        Rectangle {
            anchors.verticalCenter: track.verticalCenter
            x: Math.max(0, Math.min(track.width - width, track.width * root.ratio - width / 2))
            width: 8
            height: 16
            color: hover.hovered || mouse.pressed ? Theme.textHigh : Theme.text
            border.width: 1
            border.color: Theme.bg
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => root.emitAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    root.emitAt(mouse.x);
            }
            onWheel: wheel => {
                const delta = root.step > 0 ? root.step : (root.to - root.from) / 20;
                root.moved(root.clampValue(root.value + (wheel.angleDelta.y > 0 ? delta : -delta)));
            }
        }
    }
}
