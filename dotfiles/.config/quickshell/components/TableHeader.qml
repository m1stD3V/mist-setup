import QtQuick
import qs.Theme

// Clickable table header with an active sort indicator.
RText {
    id: root

    property string label: ""
    property bool numeric: false
    property bool active: false
    property bool descending: true
    signal clicked

    text: root.label + (root.active ? (root.descending ? " v" : " ^") : "")
    color: root.active ? Theme.textHigh : Theme.textMuted
    horizontalAlignment: root.numeric ? Text.AlignRight : Text.AlignLeft
    font.pixelSize: Theme.fontExtraSmall

    TapHandler {
        onTapped: root.clicked()
    }
}
