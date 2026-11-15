import QtQuick
import qs.Theme
import qs.components

// Clickable action row, also used as the settings sidebar navigation item.
Rectangle {
    id: root

    property string label: ""
    property string hint: ""
    property bool active: false
    property bool danger: false

    signal clicked

    implicitHeight: 28
    color: root.active || hover.hovered ? (root.danger ? Theme.textHigh : Theme.highlight) : "transparent"
    border.width: 0

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }

    RText {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: hintText.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.active || hover.hovered ? (root.danger ? Theme.bg : Theme.inverseText) : (root.danger ? Theme.textHigh : Theme.text)
        font.pixelSize: Theme.fontExtraSmall + 2
        elide: Text.ElideRight
    }

    RText {
        id: hintText

        visible: root.hint.length > 0
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.hint
        color: root.active || hover.hovered ? (root.danger ? Theme.bg : Theme.inverseText) : Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall
    }
}
