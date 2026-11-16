pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Notification panel: do-not-disturb, clear-all and the recent history.
// Opened from the control-center notifications tile.
BarPopup {
    id: root

    readonly property var rows: [{
            "type": "dnd"
        }, {
            "type": "clear"
        }, {
            "type": "sep"
        }].concat(Notifs.history.length > 0 ? Notifs.history.map((h, i) => ({
                "type": "entry",
                "h": h,
                "i": i
            })) : [{
            "type": "empty"
        }])

    screenEdge: "right"
    title: "NOTIFICATIONS"
    contentWidth: Theme.popupWidth
    open: false

    // opening the list is what "reads" them, same as the old bar chip
    onOpenChanged: {
        if (open)
            Notifs.clearUnread();
    }

    content: Component {
        Column {
            width: parent.width
            spacing: 0

            Repeater {
                model: root.rows

                delegate: Item {
                    id: row

                    required property var modelData

                    readonly property string type: modelData.type
                    readonly property bool interactive: type === "dnd" || type === "clear" || type === "entry"

                    width: parent.width
                    height: Theme.popupRowHeight

                    Rectangle {
                        anchors.fill: parent
                        color: mouse.containsMouse && row.interactive ? Theme.surfaceHigh : "transparent"
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        enabled: row.interactive
                        hoverEnabled: true
                        cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (row.type === "dnd")
                                Notifs.dnd = !Notifs.dnd;
                            else if (row.type === "clear")
                                Notifs.clearHistory();
                            else if (row.type === "entry")
                                Notifs.dismissAt(row.modelData.i);
                        }
                    }

                    RText {
                        visible: row.type === "dnd"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        text: "DO NOT DISTURB"
                        color: Notifs.dnd ? Theme.text : Theme.textDim
                        font.pixelSize: Theme.fontSmall
                    }

                    RText {
                        visible: row.type === "dnd"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        text: Notifs.dnd ? "ON" : "OFF"
                        color: Notifs.dnd ? Theme.textHigh : Theme.textDim
                        font.pixelSize: Theme.fontSmall
                    }

                    RText {
                        visible: row.type === "clear"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        text: "CLEAR ALL"
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                    }

                    Rectangle {
                        visible: row.type === "sep"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.borderHigh
                    }

                    Column {
                        visible: row.type === "entry"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: timeText.left
                        anchors.rightMargin: 8
                        spacing: 0

                        RText {
                            width: parent.width
                            text: row.modelData.h?.app ?? ""
                            color: (row.modelData.h?.urgent ?? false) ? (Theme.blink ? Theme.textHigh : Theme.textDim) : Theme.text
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        RText {
                            width: parent.width
                            text: {
                                const h = row.modelData.h;
                                if (!h)
                                    return "";
                                return h.summary + (h.body.length > 0 ? " — " + h.body : "");
                            }
                            color: Theme.textDim
                            font.pixelSize: Theme.fontExtraSmall
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    RText {
                        id: timeText

                        visible: row.type === "entry"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        text: row.modelData.h?.time ?? ""
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontExtraSmall
                    }

                    RText {
                        visible: row.type === "empty"
                        anchors.centerIn: parent
                        text: "NO NOTIFICATIONS"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
        }
    }
}
