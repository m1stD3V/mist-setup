import QtQuick
import qs.Theme
import qs.components

// Full-width action row used inside bar popups. Disabled rows stay visible but
// dimmed and inert, so a menu that depends on a target window still reads as a
// menu while making it obvious which actions cannot run.
Rectangle {
    id: root

    property string label: ""
    property string hint: ""
    property bool enabled: true

    signal clicked

    implicitWidth: labelText.implicitWidth + 20
    implicitHeight: Theme.popupRowHeight
    color: root.enabled && hover.hovered ? Theme.highlight : "transparent"
    border.width: 0
    opacity: root.enabled ? 1 : 0.45

    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.onPressAction: if (root.enabled)
        root.clicked()

    HoverHandler {
        id: hover

        enabled: root.enabled
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }

    RText {
        id: labelText

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: hover.hovered && root.enabled ? Theme.inverseText : Theme.text
        font.pixelSize: Theme.fontSmall
    }

    RText {
        visible: root.hint.length > 0

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.hint
        color: hover.hovered && root.enabled ? Theme.inverseText : Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall
    }
}
