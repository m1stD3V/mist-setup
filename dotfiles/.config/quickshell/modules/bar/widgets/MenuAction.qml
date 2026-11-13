import QtQuick
import qs.Theme
import qs.components

// Full-width action row used inside the bar overflow menu.
Rectangle {
    id: root

    property string label: ""
    property string hint: ""

    signal clicked

    implicitWidth: labelText.implicitWidth + 20
    implicitHeight: Theme.popupRowHeight
    color: hover.hovered ? Theme.inverseBg : "transparent"
    border.width: 0
    border.color: Theme.inverseBg

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }

    RText {
        id: labelText

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: hover.hovered ? Theme.inverseText : Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
    }

    RText {
        visible: root.hint.length > 0

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.hint
        color: hover.hovered ? Theme.inverseText : Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall
    }
}
