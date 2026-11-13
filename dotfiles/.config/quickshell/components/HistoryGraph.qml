import QtQuick
import qs.Theme

// Rolling bar graph for normalized 0..1 samples, newest on the right.
Item {
    id: root

    property var values: []
    property color barColor: Theme.accent
    property color idleColor: Theme.surfaceHighest
    property int gap: 1

    Row {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.values

            delegate: Item {
                id: bar

                required property real modelData

                width: Math.max(1, (root.width - (root.values.length - 1) * root.gap) / Math.max(1, root.values.length))
                height: root.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, Math.round(parent.height * Math.max(0, Math.min(1, bar.modelData))))
                    color: bar.modelData > 0.005 ? root.barColor : root.idleColor
                }
            }
        }
    }
}
