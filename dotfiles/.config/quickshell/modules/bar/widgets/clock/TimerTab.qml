import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.components
import qs.services

// Countdown timer tab.
Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 6

    RowLayout {
        width: parent.width

        RText {
            Layout.fillWidth: true
            text: "COUNTDOWN"
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
        }

        RText {
            text: TimeTools.timerRunning ? "RUNNING" : TimeTools.timerFinished ? "DONE" : "READY"
            color: TimeTools.timerRunning ? Theme.textHigh : Theme.textMuted
            font.pixelSize: Theme.fontSmall
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
