pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Notification toggle button: shows the unread count, opens the
// notification tray (history, DND toggle, clear all).
Rectangle {
    id: root

    property PanelWindow window

    implicitWidth: btnRow.implicitWidth + 10
    implicitHeight: Theme.barHeight - 10
    color: hover.hovered || popup.open ? Theme.inverseBg : "transparent"
    border.width: 1
    border.color: hover.hovered || popup.open ? Theme.inverseBg : Theme.borderHigh

    function closePopup(): void {
        popup.open = false;
    }

    HoverHandler {
        id: hover
    }

    Row {
        id: btnRow

        anchors.centerIn: parent
        spacing: 6

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: "NTF"
            color: hover.hovered || popup.open ? Theme.inverseText : Theme.text
            font.pixelSize: Theme.fontExtraSmall + 2
        }

        Rectangle {
            visible: Notifs.dnd
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: dndText.implicitWidth + 6
            implicitHeight: dndText.implicitHeight + 2
            color: Theme.blink ? Theme.textHigh : Theme.textDim

            RText {
                id: dndText

                anchors.centerIn: parent
                text: "DND"
                color: Theme.bg
                font.pixelSize: Theme.fontExtraSmall
            }
        }

        Rectangle {
            visible: !Notifs.dnd && Notifs.unread > 0
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: unreadText.implicitWidth + 6
            implicitHeight: unreadText.implicitHeight + 2
            color: Theme.inverseBg

            RText {
                id: unreadText

                anchors.centerIn: parent
                text: String(Notifs.unread)
                color: Theme.inverseText
                font.pixelSize: Theme.fontExtraSmall
            }
        }
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: {
            if (!popup.open)
                Notifs.clearUnread();
            popup.open = !popup.open;
        }
    }

    BarPopup {
        id: popup

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

        barWindow: root.window
        screenEdge: "right"
        title: "NOTIFICATIONS"
        contentWidth: Theme.popupWidth
        contentHeight: rows.length * Theme.popupRowHeight + Theme.popupChromeHeight
        open: false

        content: Component {
            Column {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: popup.rows

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
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            visible: row.type === "dnd"
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            text: Notifs.dnd ? "ON" : "OFF"
                            color: Notifs.dnd ? Theme.textHigh : Theme.textDim
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            visible: row.type === "clear"
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            text: "CLEAR ALL"
                            color: Theme.textDim
                            font.pixelSize: Theme.fontExtraSmall + 2
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
                                text: row.modelData.h.app
                                color: row.modelData.h.urgent ? (Theme.blink ? Theme.textHigh : Theme.textDim) : Theme.text
                                font.pixelSize: Theme.fontExtraSmall + 2
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            RText {
                                width: parent.width
                                text: row.modelData.h.summary + (row.modelData.h.body.length > 0 ? " — " + row.modelData.h.body : "")
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
                            text: row.modelData.h.time
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall
                        }

                        RText {
                            visible: row.type === "empty"
                            anchors.centerIn: parent
                            text: "NO NOTIFICATIONS"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }
                    }
                }
            }
        }
    }
}