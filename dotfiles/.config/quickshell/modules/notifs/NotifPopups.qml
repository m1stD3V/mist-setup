pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Theme
import qs.components
import qs.services

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        right: true
    }
    margins.top: Theme.barHeight + 12
    margins.right: 12
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "transparent"
    implicitWidth: 400
    implicitHeight: stack.implicitHeight
    visible: stack.implicitHeight > 0 && (!Notifs.dnd || Notifs.criticalActive)
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: stack

        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.width
        spacing: 10

        Repeater {
            model: ScriptModel {
                values: Notifs.server.trackedNotifications.values.slice(-4).reverse()
            }

            delegate: NotifCard {
                required property Notification modelData

                notif: modelData
            }
        }
    }

    component NotifCard: Box {
        id: card

        required property Notification notif

        readonly property bool critical: notif.urgency === NotificationUrgency.Critical
        readonly property int timeout: notif.resident ? 0 : (notif.expireTimeout > 0 ? notif.expireTimeout : (notif.transient ? 3000 : 5000))
        readonly property bool hasImage: (notif.image ?? "").length > 0

        width: parent.width
        height: contentCol.implicitHeight + 33
        borderColor: critical && Theme.blink ? Theme.textHigh : Theme.borderHigh

        Timer {
            running: card.timeout > 0 && !card.critical
            interval: card.timeout

            onTriggered: card.notif.expire()
        }

        Column {
            id: contentCol

            anchors.fill: parent
            spacing: Theme.spacingXs

            RText {
                width: parent.width
                text: card.notif.summary
                color: Theme.textHigh
                font.pixelSize: Theme.fontSmall + 2
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Row {
                width: parent.width
                spacing: Theme.spacingSm

                Image {
                    visible: card.hasImage
                    width: card.hasImage ? 48 : 0
                    height: 48
                    source: card.hasImage ? Qt.resolvedUrl(card.notif.image) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                RText {
                    width: parent.width - (card.hasImage ? 56 : 0)
                    height: implicitHeight
                    text: card.notif.body
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
            }

            Row {
                spacing: Theme.spacingSm

                Repeater {
                    model: card.notif.actions

                    delegate: Rectangle {
                        id: actionBtn

                        required property var modelData

                        width: actionText.implicitWidth + 16
                        height: 22
                        color: actionMouse.hovered ? Theme.highlight : Theme.surfaceHigh
                        border.width: 1
                        border.color: Theme.borderHigh

                        HoverHandler {
                            id: actionMouse
                        }

                        TapHandler {
                            onTapped: actionBtn.modelData.invoke()
                        }

                        RText {
                            id: actionText

                            anchors.centerIn: parent
                            text: actionBtn.modelData.text.toUpperCase()
                            color: actionMouse.hovered ? Theme.inverseText : Theme.text
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }
                    }
                }
            }
        }
    }
}
