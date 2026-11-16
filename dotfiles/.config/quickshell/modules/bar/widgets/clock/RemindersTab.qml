pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.components
import qs.services

// Reminders tab: quick "in N minutes" adds, an "at HH:MM" add, and the list of
// pending/fired reminders.
Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 6

    readonly property int rowH: 28
    readonly property int maxRows: 3
    readonly property int listHeight: Math.min(Math.max(1, Reminders.items.length), root.maxRows) * root.rowH
    readonly property var quickAdds: [5, 15, 30, 60, 120]

    function focusField(): void {
        remindField.forceActiveFocus();
    }

    RowLayout {
        width: parent.width

        RText {
            Layout.fillWidth: true
            text: "REMINDERS"
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
        }

        RText {
            text: Reminders.firedCount > 0 ? "CLEAR DONE" : Reminders.pendingCount + " PENDING"
            color: clearMouse.containsMouse ? Theme.textHigh : Theme.textMuted
            font.pixelSize: Theme.fontSmall

            MouseArea {
                id: clearMouse

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                enabled: Reminders.firedCount > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: Reminders.clearFired()
            }
        }
    }

    Item {
        width: parent.width
        height: root.listHeight

        RText {
            visible: Reminders.items.length === 0
            anchors.centerIn: parent
            text: "NO REMINDERS"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }

        ListView {
            anchors.fill: parent
            visible: Reminders.items.length > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Reminders.items

            delegate: Item {
                id: reminderRow

                required property var modelData

                width: ListView.view.width
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    color: reminderHover.hovered ? Theme.surfaceHigh : "transparent"
                }

                HoverHandler {
                    id: reminderHover
                }

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.right: labelText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: reminderRow.modelData.text.toUpperCase()
                    color: reminderRow.modelData.fired ? Theme.textMuted : Theme.text
                    font.pixelSize: Theme.fontSmall
                    font.strikeout: reminderRow.modelData.fired
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                RText {
                    id: labelText

                    anchors.right: removeBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: Reminders.label(reminderRow.modelData)
                    color: reminderRow.modelData.fired ? Theme.textMuted : Theme.textDim
                    font.pixelSize: Theme.fontExtraSmall
                }

                TextButton {
                    id: removeBtn

                    width: 22
                    height: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    label: "X"
                    danger: true
                    onClicked: Reminders.remove(reminderRow.modelData.id)
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 30
        color: Theme.surfaceHigh
        border.width: 1
        border.color: remindField.activeFocus ? Theme.highlight : Theme.borderHigh

        RText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: remindField.text.length === 0
            text: "REMIND ME TO..."
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }

        TextInput {
            id: remindField

            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.textHigh
            font.family: Theme.family
            font.pixelSize: Theme.fontSmall
            selectionColor: Theme.inverseBg
            selectedTextColor: Theme.inverseText
            clip: true

            onAccepted: {
                if (Reminders.addIn(text, TimeTools.reminderMinutes))
                    remindField.text = "";
            }
        }
    }

    Row {
        spacing: 6

        Repeater {
            model: root.quickAdds

            TextButton {
                required property int modelData

                label: modelData >= 60 ? (modelData / 60) + "H" : modelData + "M"
                onClicked: {
                    if (Reminders.addIn(remindField.text, modelData))
                        remindField.text = "";
                }
            }
        }
    }

    RowLayout {
        spacing: 8

        RText {
            text: "AT"
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
        }

        NumberField {
            label: "HOUR"
            maxValue: 23
            value: TimeTools.reminderHour
            onSubmitted: v => TimeTools.reminderHour = v
        }

        NumberField {
            label: "MIN"
            maxValue: 59
            value: TimeTools.reminderMinute
            onSubmitted: v => TimeTools.reminderMinute = v
        }

        TextButton {
            Layout.alignment: Qt.AlignTop
            label: "SET"
            onClicked: {
                if (Reminders.addClock(remindField.text, TimeTools.reminderHour, TimeTools.reminderMinute))
                    remindField.text = "";
            }
        }
    }
}
