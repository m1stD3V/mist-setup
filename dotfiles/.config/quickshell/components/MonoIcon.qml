import QtQuick
import QtQuick.Effects
import Quickshell

// System tray / desktop icon rendered as a desaturated (grayscale)
// image to fit the monochrome phosphor look.
Item {
    id: root

    property string icon: ""
    property real size: 18
    property real brightness: 0.25

    readonly property bool loaded: img.status === Image.Ready

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img

        anchors.centerIn: parent
        width: root.size
        height: root.size
        source: root.icon
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        mipmap: true
        visible: false
        asynchronous: true
    }

    MultiEffect {
        anchors.fill: img
        source: img
        saturation: -1.0
        brightness: root.brightness
        visible: img.status === Image.Ready
    }
}
