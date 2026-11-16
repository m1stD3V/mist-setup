import QtQuick
import qs.Theme

// Control-center tile: a bordered block with an inverse-video title strip.
// The header's right-hand state doubles as a switch when stateClickable is
// set, so "ON"/"OFF" style controls stay in the title row instead of adding
// another row of buttons to the body.
Rectangle {
    id: root

    default property alias content: body.data
    property string title: ""
    property string state: ""
    // filled header: the tile's feature is currently on
    property bool active: false
    // the tile body opens something; gives it a hover border and a click
    property bool interactive: false
    property bool stateClickable: false

    signal clicked
    signal stateClicked

    readonly property int headerH: 22
    readonly property int bodyTop: 7
    readonly property int bodyBottom: 8
    readonly property bool hot: hover.hovered && root.interactive

    implicitHeight: headerH + bodyTop + body.implicitHeight + bodyBottom
    color: Theme.surface
    border.width: 1
    border.color: root.hot ? Theme.highlight : (root.active ? Theme.borderHigh : Theme.border)

    HoverHandler {
        id: hover

        enabled: root.interactive
    }

    TapHandler {
        enabled: root.interactive
        onTapped: root.clicked()
    }

    Rectangle {
        id: header

        x: 1
        y: 1
        width: parent.width - 2
        height: root.headerH
        color: root.active ? Theme.inverseBg : "transparent"

        Rectangle {
            visible: !root.active
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        RText {
            anchors.left: parent.left
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.active ? Theme.inverseText : Theme.textDim
            font.pixelSize: Theme.fontExtraSmall + 2
        }

        RText {
            id: stateText

            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: root.state
            color: root.active ? Theme.inverseText : (stateMouse.containsMouse ? Theme.textHigh : (root.stateClickable ? Theme.text : Theme.textMuted))
            font.pixelSize: Theme.fontExtraSmall + 2
        }

        MouseArea {
            id: stateMouse

            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: stateText.width + 8
            height: parent.height
            enabled: root.stateClickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stateClicked()
        }
    }

    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: root.bodyTop
        implicitHeight: childrenRect.height
    }
}
