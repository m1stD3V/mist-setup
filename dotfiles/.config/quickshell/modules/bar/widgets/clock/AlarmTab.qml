pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.components
import qs.services

// Alarm list and add-alarm row.
Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 6

    readonly property int rowH: 28
    readonly property int maxRows: 5
    readonly property int listHeight: Math.min(Math.max(1, TimeTools.alarms.length), root.maxRows) * root.rowH

    RowLayout {
        width: parent.width

        RText {
            Layout.fillWidth: true
            text: "ALARMS"
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
        }

        RText {
            text: TimeTools.alarms.filter(a => a.enabled).length + " ACTIVE"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }
    }

    Item {
        width: parent.width
        height: root.listHeight

        RText {
            visible: TimeTools.alarms.length === 0
            anchors.centerIn: parent
            text: "NO ALARMS SET"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }

        ListView {
            anchors.fill: parent
            visible: TimeTools.alarms.length > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: TimeTools.alarms

            delegate: Item {
                id: alarmRow

                required property var modelData

                width: ListView.view.width
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    color: rowHover.hovered ? Theme.surfaceHigh : "transparent"
                }

                HoverHandler {
                    id: rowHover
                }

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: TimeTools.pad2(alarmRow.modelData.hour) + ":" + TimeTools.pad2(alarmRow.modelData.minute)
                    color: alarmRow.modelData.enabled ? Theme.text : Theme.textMuted
                    font.pixelSize: Theme.fontSmall + 2
                }

                TextButton {
                    anchors.right: removeBtn.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    label: alarmRow.modelData.enabled ? "ON" : "OFF"
                    active: alarmRow.modelData.enabled
                    onClicked: TimeTools.toggleAlarm(alarmRow.modelData.id)
                }

                TextButton {
                    id: removeBtn

                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 20
                    label: "X"
                    danger: true
                    onClicked: TimeTools.removeAlarm(alarmRow.modelData.id)
                }
            }
        }
    }

    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        NumberField {
            id: hourField

            label: "HOUR"
            maxValue: 23
            value: TimeTools.newAlarmHour
            onSubmitted: v => TimeTools.newAlarmHour = v
        }

        NumberField {
            id: minuteField

            label: "MIN"
            maxValue: 59
            value: TimeTools.newAlarmMinute
            onSubmitted: v => TimeTools.newAlarmMinute = v
        }

        TextButton {
            Layout.alignment: Qt.AlignVCenter
            label: "ADD"
            onClicked: TimeTools.addAlarm(TimeTools.newAlarmHour, TimeTools.newAlarmMinute)
        }
    }
}
