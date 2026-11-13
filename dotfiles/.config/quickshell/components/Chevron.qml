import QtQuick
import qs.Theme

// Pixel-art chevron: points right when closed, down when expanded.
Item {
    id: root

    property bool expanded: false
    property color tint: Theme.text

    width: 8
    height: 8

    Rectangle {
        width: 2
        height: 2
        color: root.tint
    }

    Rectangle {
        x: 3
        y: 3
        width: 2
        height: 2
        color: root.tint
    }

    Rectangle {
        x: root.expanded ? 6 : 0
        y: root.expanded ? 0 : 6
        width: 2
        height: 2
        color: root.tint

        Behavior on x {
            NumberAnimation {
                duration: 140
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 140
            }
        }
    }
}
