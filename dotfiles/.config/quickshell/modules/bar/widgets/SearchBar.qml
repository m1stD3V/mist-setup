pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Compact application search field in the bar. Opens a dropdown
// powered by the program executor's app index.
Rectangle {
    id: root

    property PanelWindow window

    function closePopup(): void {
        popup.open = false;
    }

    implicitWidth: 150
    implicitHeight: Theme.barHeight - 10
    color: hover.hovered || popup.open ? Theme.inverseBg : "transparent"
    border.width: 1
    border.color: hover.hovered || popup.open ? Theme.inverseBg : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: popup.open = !popup.open
    }

    RText {
        anchors.centerIn: parent
        text: "SEARCH"
        color: hover.hovered || popup.open ? Theme.inverseText : Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
    }

    SearchPopup {
        id: popup

        barWindow: root.window
    }
}
