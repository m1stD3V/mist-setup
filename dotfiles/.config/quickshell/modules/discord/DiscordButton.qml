import QtQuick
import qs.Theme
import qs.components

// Small inverse-video button used for call controls and tabs.
Rectangle {
    id: root

    property string label: ""
    property bool active: false
    property bool danger: false

    signal clicked

    implicitWidth: labelText.implicitWidth + 16
    implicitHeight: 24

    color: root.active || hover.hovered ? (root.danger ? Theme.textHigh : Theme.inverseBg) : Theme.surfaceHigh
    border.width: 1
    border.color: hover.hovered ? Theme.textHigh : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }

    RText {
        id: labelText

        anchors.centerIn: parent
        text: root.label
        color: {
            if (root.active || hover.hovered)
                return root.danger ? Theme.bg : Theme.inverseText;
            return root.danger ? Theme.textHigh : Theme.text;
        }
        font.pixelSize: Theme.fontExtraSmall + 2
    }
}
