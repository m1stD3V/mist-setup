import QtQuick
import qs.Theme
import qs.components

// Titled group of settings controls.
Column {
    id: root

    property string title: ""

    default property alias content: body.data

    width: parent ? parent.width : 0
    spacing: 6

    RText {
        width: parent.width
        text: root.title
        color: Theme.textDim
        font.pixelSize: Theme.fontExtraSmall
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.border
    }

    Column {
        id: body

        width: parent.width
        spacing: 2
    }
}
