import QtQuick
import qs.Theme

// Segmented block meter, styled like old BIOS/DOS resource bars.
// Label is rendered inverse-video on the left, like a DOS field label.
Item {
    id: root

    property string label: ""
    property real value: 0
    property int segments: 10
    property bool showPct: true
    property int segW: 4
    property int segH: 12
    property int gap: 2

    implicitWidth: labelBox.implicitWidth + spacing + grid.width + (showPct ? spacing + pct.width : 0)
    implicitHeight: Math.max(labelBox.implicitHeight, grid.height, pct.implicitHeight)

    property int spacing: Theme.spacingSm

    Rectangle {
        id: labelBox

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: labelText.implicitWidth + 8
        implicitHeight: labelText.implicitHeight + 4
        color: Theme.inverseBg
        visible: root.label.length > 0

        RText {
            id: labelText

            anchors.centerIn: parent
            text: root.label
            color: Theme.inverseText
            font.pixelSize: Theme.fontSmall
        }
    }

    Row {
        id: grid

        anchors.verticalCenter: parent.verticalCenter
        x: labelBox.visible ? labelBox.width + root.spacing : 0
        spacing: root.gap

        Repeater {
            model: root.segments

            Rectangle {
                width: root.segW
                height: root.segH
                color: index < Math.round(root.value * root.segments) ? Theme.accent : Theme.surfaceHighest
            }
        }
    }

    RText {
        id: pct

        anchors.verticalCenter: parent.verticalCenter
        x: grid.x + grid.width + root.spacing
        visible: root.showPct
        text: Math.round(root.value * 100) + "%"
        color: Theme.textDim
        font.pixelSize: Theme.fontSmall
    }
}
