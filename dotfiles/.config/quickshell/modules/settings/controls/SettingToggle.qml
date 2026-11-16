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

    implicitHeight: root.description.length > 0 ? 40 : 30

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
            font.pixelSize: Theme.fontSmall
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
        width: 46
        height: 20
        color: root.checked ? Theme.highlight : Theme.surfaceHigh
        border.width: 1
        border.color: hover.hovered ? Theme.textHigh : Theme.borderHigh

        Rectangle {
            width: 14
            height: 14
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
