import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.components

// Compact task-manager style performance panel.
Rectangle {
    id: root

    property string title: ""
    property string value: ""
    property var values: []
    property color graphColor: Theme.accent
    property string detail1: ""
    property string detail2: ""

    implicitWidth: 200
    implicitHeight: 165

    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        RowLayout {
            width: parent.width

            RText {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textDim
                elide: Text.ElideRight
                font.pixelSize: Theme.fontExtraSmall + 2
            }

            RText {
                text: root.value
                color: Theme.textHigh
                font.pixelSize: Theme.fontSmall + 2
            }
        }

        HistoryGraph {
            width: parent.width
            height: 82
            values: root.values
            barColor: root.graphColor
        }

        RText {
            width: parent.width
            text: root.detail1
            color: Theme.textDim
            elide: Text.ElideRight
            font.pixelSize: Theme.fontExtraSmall
        }

        RText {
            width: parent.width
            text: root.detail2
            color: Theme.textMuted
            elide: Text.ElideRight
            font.pixelSize: Theme.fontExtraSmall
        }
    }
}
