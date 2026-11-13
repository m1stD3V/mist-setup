import QtQuick
import qs.Theme
import qs.components

// Labeled on/off row used throughout the settings panel.
Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false

    signal toggled

    implicitHeight: root.description.length > 0 ? 36 : 28

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.toggled()
    }

    Column {
        anchors.left: parent.left
        anchors.right: switchBox.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        RText {
            width: parent.width
            text: root.label
            color: Theme.text
            font.pixelSize: Theme.fontExtraSmall + 2
            elide: Text.ElideRight
        }

        RText {
            visible: root.description.length > 0
            width: parent.width
            text: root.description
            color: Theme.textMuted
            font.pixelSize: Theme.fontExtraSmall
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: switchBox

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 18
        color: root.checked ? Theme.inverseBg : Theme.surfaceHigh
        border.width: 1
        border.color: hover.hovered ? Theme.textHigh : Theme.borderHigh

        Rectangle {
            width: 12
            height: 12
            y: 2
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.inverseText : Theme.textDim

            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
    }
}
