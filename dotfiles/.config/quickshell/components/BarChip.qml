import QtQuick
import qs.Theme

// Shared chrome for anything that sits in the bar: a bordered box that turns
// into an inverse-video highlight on hover or while its popup is open.
//
// Every popup opener used to reimplement this block (border, height, hover
// colours, press guard, closePopup) which is why the bar's look drifted
// between widgets. One definition keeps them aligned.
//
// `bar` is the owning Bar. The chip arms the bar's click guard on press so the
// click that opens a popup cannot also be read as "click on empty bar space,
// dismiss popups". A timestamp guard (rather than a sticky boolean) means a
// drag or a press on another monitor can never swallow a later click.
Rectangle {
    id: root

    default property alias content: contentItem.data

    // owning Bar (PanelWindow); used only for armPopupGuard()
    property var bar: null
    // true while the chip's popup is open
    property bool active: false
    // false for read-only modules: no hover highlight, no cursor change
    property bool interactive: true
    property string accessibleName: ""

    readonly property bool hovered: hover.hovered
    readonly property bool hot: (root.interactive && hover.hovered) || root.active

    signal tapped

    implicitWidth: contentItem.implicitWidth + 14
    implicitHeight: Theme.barChipHeight
    color: root.hot ? Theme.highlight : "transparent"
    border.width: 1
    border.color: root.hot ? Theme.highlight : Theme.borderHigh

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.description: root.accessibleName

    HoverHandler {
        id: hover

        enabled: root.interactive
    }

    TapHandler {
        enabled: root.interactive

        onPressedChanged: {
            if (pressed && root.bar && root.bar.armPopupGuard)
                root.bar.armPopupGuard();
        }
        onTapped: root.tapped()
    }

    // A Row (not a bare Item with childrenRect) so the chip's implicit size is
    // derived exactly once from its children's implicit sizes. childrenRect
    // reported a binding loop whenever a child was centred or laid out against
    // the container.
    Row {
        id: contentItem

        anchors.centerIn: parent
        spacing: 0
    }
}
