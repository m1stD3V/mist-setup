pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Compact application search field in the bar. Opens a dropdown powered by the
// program executor's app index.
BarChip {
    id: root

    property var window

    bar: root.window
    active: popup.open
    accessibleName: qsTr("Search")

    implicitWidth: 150

    onTapped: popup.open = !popup.open

    RText {
        text: "SEARCH"
        color: root.hot ? Theme.inverseText : Theme.text
        font.pixelSize: Theme.fontExtraSmall + 2
    }

    SearchPopup {
        id: popup

        barWindow: root.window
    }
}
