import QtQuick
import qs.Theme
import qs.components

// Clickable shortcut row. The left side starts recording; the right side
// appears only when the combo differs from its default and restores it.
Item {
    id: root

    property string label: ""
    property string combo: ""
    property bool recording: false
    property bool overridden: false

    signal clicked
    signal resetClicked

    implicitHeight: 30

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent
        color: root.recording || hover.hovered ? Theme.highlight : "transparent"
    }

    RText {
        id: labelText

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: comboText.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.recording || hover.hovered ? Theme.bg : Theme.text
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideRight
    }

    RText {
        id: comboText

        anchors.right: resetText.visible ? resetText.left : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.recording ? "PRESS A COMBO..." : root.combo
        color: root.recording || hover.hovered ? Theme.bg : (root.overridden ? Theme.text : Theme.textDim)
        font.pixelSize: Theme.fontSmall
    }

    RText {
        id: resetText

        visible: root.overridden && !root.recording
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "RESET"
        color: hover.hovered ? Theme.bg : Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.resetClicked()
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: resetText.visible ? resetText.width + 8 : 8
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
