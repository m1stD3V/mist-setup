import QtQuick
import qs.Theme
import qs.components

// Read-only key/value row for status and about information.
Item {
    id: root

    property string label: ""
    property string value: ""

    implicitHeight: 24

    RText {
        anchors.left: parent.left
        anchors.right: valueText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall + 2
        elide: Text.ElideRight
    }

    RText {
        id: valueText

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
    }
}
