import QtQuick
import qs.Theme

// Thin bordered container that makes a bar widget read as a button
// and separates it from its neighbours.
Rectangle {
    id: root

    default property alias content: contentItem.data

    implicitWidth: contentItem.implicitWidth + 10
    implicitHeight: Theme.barHeight - 10
    color: "transparent"
    border.width: 1
    border.color: hover.hovered ? Theme.inverseBg : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    Item {
        id: contentItem

        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
