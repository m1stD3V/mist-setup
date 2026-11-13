import QtQuick
import qs.Theme
import qs.components

Item {
    id: root

    readonly property int h: Theme.barHeight - 10

    implicitWidth: box.width
    implicitHeight: h

    Rectangle {
        id: box

        width: label.implicitWidth + 12
        height: parent.h
        color: Theme.inverseBg

        RText {
            id: label

            anchors.centerIn: parent
            text: "MIST-86"
            color: Theme.inverseText
            font.pixelSize: Theme.fontSmall
        }
    }
}
