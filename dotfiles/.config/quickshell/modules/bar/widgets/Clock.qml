import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.components
import qs.services

Rectangle {
    id: root

    property PanelWindow window
    property string tab: "alarm"
    property int newAlarmHour: 7
    property int newAlarmMinute: 0

    readonly property bool hot: hover.hovered || popup.open
    readonly property color fg: hot ? Theme.inverseText : (TimeTools.alertActive && Theme.blink ? Theme.textHigh : Theme.text)
    readonly property color fgDim: hot ? Theme.inverseText : (TimeTools.alertActive ? Theme.textHigh : Theme.textMuted)
    readonly property int hour12: {
        const h = Time.hours % 12;
        return h === 0 ? 12 : h;
    }
    readonly property string hourText: Settings.clock24h ? Time.format("hh") : (hour12 < 10 ? "0" + hour12 : "" + hour12)

    function closePopup(): void {
        popup.open = false;
    }

    implicitWidth: timeRow.implicitWidth + 14
    implicitHeight: Theme.barHeight - 10
    color: hot ? Theme.highlight : "transparent"
    border.width: 1
    border.color: hot ? Theme.highlight : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: popup.open = !popup.open
    }

    Row {
        id: timeRow

        anchors.centerIn: parent
        spacing: 0

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hourText
            color: root.fg
            font.pixelSize: Theme.fontSmall + 2
        }

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            color: root.fg
            opacity: Theme.blink ? 1.0 : 0.15
            font.pixelSize: Theme.fontSmall + 2
        }

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("mm")
            color: root.fg
            font.pixelSize: Theme.fontSmall + 2
        }

        RText {
            visible: Settings.clockSeconds
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            color: root.fg
            opacity: Theme.blink ? 1.0 : 0.15
            font.pixelSize: Theme.fontSmall + 2
        }

        RText {
            visible: Settings.clockSeconds
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("ss")
            color: root.fgDim
            font.pixelSize: Theme.fontExtraSmall + 2
        }

        RText {
            visible: !Settings.clock24h
            anchors.verticalCenter: parent.verticalCenter
            text: " " + (Time.hours < 12 ? "AM" : "PM")
            color: root.fgDim
            font.pixelSize: Theme.fontExtraSmall
        }
    }

    BarPopup {
        id: popup

        barWindow: root.window
        screenEdge: "right"
        title: "CLOCK"
        contentWidth: Theme.popupWidth
        contentHeight: Theme.popupChromeHeight + 35 + (TimeTools.alertActive ? 34 : 0) + (root.tab === "alarm" ? 250 : 140)
        open: false

        content: Component {
            Item {
                id: page

                anchors.fill: parent

                Column {
                    anchors.fill: parent
                    spacing: 6

                    Rectangle {
                        visible: TimeTools.alertActive
                        width: parent.width
                        height: visible ? 28 : 0
                        color: Theme.surfaceHigh
                        border.width: 1
                        border.color: Theme.blink ? Theme.textHigh : Theme.borderHigh

                        RText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: stopBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: TimeTools.alertKind === "alarm" ? "ALARM RINGING" : TimeTools.alertKind === "timer" ? "TIMER DONE" : "POMODORO " + TimeTools.pomoLabel
                            color: Theme.blink ? Theme.textHigh : Theme.text
                            font.pixelSize: Theme.fontExtraSmall + 2
                            elide: Text.ElideRight
                        }

                        TextButton {
                            id: stopBtn

                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            label: "STOP"
                            onClicked: TimeTools.dismissAlert()
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 4

                        TextButton {
                            label: "ALARM"
                            active: root.tab === "alarm"
                            onClicked: root.tab = "alarm"
                        }

                        TextButton {
                            label: "TIMER"
                            active: root.tab === "timer"
                            onClicked: root.tab = "timer"
                        }

                        TextButton {
                            label: "POMODORO"
                            active: root.tab === "pomodoro"
                            onClicked: root.tab = "pomodoro"
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.borderHigh
                    }

                    Item {
                        width: parent.width
                        height: root.tab === "alarm" ? 250 : 140

                        // ---------- alarms ----------
                        Column {
                            anchors.fill: parent
                            spacing: 6
                            visible: root.tab === "alarm"

                            RowLayout {
                                width: parent.width

                                RText {
                                    Layout.fillWidth: true
                                    text: "ALARMS"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }

                                RText {
                                    text: TimeTools.alarms.filter(a => a.enabled).length + " ACTIVE"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }
                            }

                            Item {
                                width: parent.width
                                height: 160

                                RText {
                                    visible: TimeTools.alarms.length === 0
                                    anchors.centerIn: parent
                                    text: "NO ALARMS SET"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }

                                ListView {
                                    anchors.fill: parent
                                    visible: TimeTools.alarms.length > 0
                                    clip: true
                                    spacing: 2
                                    model: TimeTools.alarms

                                    delegate: Item {
                                        id: alarmRow

                                        required property var modelData

                                        width: ListView.view.width
                                        height: 26

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
                                            text: (alarmRow.modelData.hour < 10 ? "0" : "") + alarmRow.modelData.hour + ":" + (alarmRow.modelData.minute < 10 ? "0" : "") + alarmRow.modelData.minute
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
                                    label: "HOUR"
                                    maxValue: 23
                                    value: root.newAlarmHour
                                    onSubmitted: v => root.newAlarmHour = v
                                }

                                NumberField {
                                    label: "MIN"
                                    maxValue: 59
                                    value: root.newAlarmMinute
                                    onSubmitted: v => root.newAlarmMinute = v
                                }

                                TextButton {
                                    Layout.alignment: Qt.AlignVCenter
                                    label: "ADD"
                                    onClicked: TimeTools.addAlarm(root.newAlarmHour, root.newAlarmMinute)
                                }
                            }
                        }

                        // ---------- countdown timer ----------
                        Column {
                            anchors.fill: parent
                            spacing: 6
                            visible: root.tab === "timer"

                            RowLayout {
                                width: parent.width

                                RText {
                                    Layout.fillWidth: true
                                    text: "COUNTDOWN"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }

                                RText {
                                    text: TimeTools.timerRunning ? "RUNNING" : TimeTools.timerFinished ? "DONE" : "READY"
                                    color: TimeTools.timerRunning ? Theme.textHigh : Theme.textMuted
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }
                            }

                            RText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: TimeTools.fmtLong(TimeTools.timerRemaining)
                                color: TimeTools.timerRemaining === 0 ? Theme.textHigh : Theme.text
                                font.pixelSize: Theme.fontHuge
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                NumberField {
                                    label: "HOURS"
                                    maxValue: 99
                                    value: TimeTools.timerH
                                    onSubmitted: v => TimeTools.setTimerHMS(v, TimeTools.timerM, TimeTools.timerS)
                                }

                                NumberField {
                                    label: "MIN"
                                    maxValue: 59
                                    value: TimeTools.timerM
                                    onSubmitted: v => TimeTools.setTimerHMS(TimeTools.timerH, v, TimeTools.timerS)
                                }

                                NumberField {
                                    label: "SEC"
                                    maxValue: 59
                                    value: TimeTools.timerS
                                    onSubmitted: v => TimeTools.setTimerHMS(TimeTools.timerH, TimeTools.timerM, v)
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                TextButton {
                                    label: TimeTools.timerRunning ? "PAUSE" : "START"
                                    active: TimeTools.timerRunning
                                    onClicked: TimeTools.toggleTimer()
                                }

                                TextButton {
                                    label: "RESET"
                                    onClicked: TimeTools.resetTimer()
                                }
                            }
                        }

                        // ---------- pomodoro ----------
                        Column {
                            anchors.fill: parent
                            spacing: 6
                            visible: root.tab === "pomodoro"

                            RowLayout {
                                width: parent.width

                                RText {
                                    Layout.fillWidth: true
                                    text: TimeTools.pomoLabel
                                    color: TimeTools.pomoMode === "focus" ? Theme.textHigh : Theme.textDim
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }

                                RText {
                                    text: "CYCLE " + TimeTools.pomoCycles
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontExtraSmall + 2
                                }
                            }

                            RText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: TimeTools.fmt(TimeTools.pomoRemaining)
                                color: TimeTools.pomoRemaining === 0 ? Theme.textHigh : Theme.text
                                font.pixelSize: Theme.fontHuge
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                TextButton {
                                    label: TimeTools.pomoRunning ? "PAUSE" : "START"
                                    active: TimeTools.pomoRunning
                                    onClicked: TimeTools.togglePomo()
                                }

                                TextButton {
                                    label: "RESET"
                                    onClicked: TimeTools.resetPomo()
                                }

                                TextButton {
                                    label: "SKIP"
                                    onClicked: TimeTools.skipPomo()
                                }
                            }

                            RText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "25M FOCUS  /  5M BREAK"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                            }
                        }
                    }
                }
            }
        }
    }
}
