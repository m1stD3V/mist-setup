import QtQuick
import QtQuick.Effects
import qs.Theme
import qs.components

// Square, desaturated avatar with an initials fallback, matching the
// monochrome phosphor look.
Item {
    id: root

    property string source: ""
    property string name: ""
    property int size: 24
    property bool dim: false

    implicitWidth: size
    implicitHeight: size

    function initials(): string {
        const n = (root.name || "?").trim();
        if (n.length === 0)
            return "?";
        const parts = n.split(/\s+/);
        if (parts.length >= 2 && parts[1].length > 0)
            return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
        return n.slice(0, 2).toUpperCase();
    }

    Image {
        id: img

        anchors.fill: parent
        source: root.source
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        saturation: -1.0
        brightness: root.dim ? 0.02 : 0.22
        visible: img.status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceHigh
        border.width: 1
        border.color: Theme.border
        visible: img.status !== Image.Ready

        RText {
            anchors.centerIn: parent
            text: root.initials()
            color: Theme.textDim
            font.pixelSize: Math.max(8, Math.round(root.size * 0.4))
        }
    }
}
