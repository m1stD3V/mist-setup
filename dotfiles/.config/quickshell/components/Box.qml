import QtQuick
import qs.Theme

// Classic DOS-style double-bordered window box with a full-width
// inverse-video title bar (Norton Commander style).
Rectangle {
    id: root

    default property alias content: contentArea.data
    property string title: ""
    property color borderColor: Theme.borderHigh
    property color innerBorderColor: Theme.border

    readonly property bool hasTitle: title.length > 0
    readonly property int titleBarH: 18

    color: Theme.barBg
    border.width: 1
    border.color: root.borderColor

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2

        color: "transparent"
        border.width: 1
        border.color: root.innerBorderColor
    }

    Rectangle {
        visible: root.hasTitle
        x: 4
        y: 4
        width: parent.width - 8
        height: root.titleBarH
        color: Theme.inverseBg

        RText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            text: root.title
            color: Theme.inverseText
            font.pixelSize: Theme.fontExtraSmall + 2
        }
    }

    Item {
        id: contentArea

        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.bottomMargin: 9
        anchors.topMargin: root.hasTitle ? 4 + root.titleBarH + 4 : 9
    }
}
