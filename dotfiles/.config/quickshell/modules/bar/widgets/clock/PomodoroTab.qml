import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.components
import qs.services

// Pomodoro tab.
Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 6

    RowLayout {
        width: parent.width

        RText {
            Layout.fillWidth: true
            text: TimeTools.pomoLabel
            color: TimeTools.pomoMode === "focus" ? Theme.textHigh : Theme.textDim
            font.pixelSize: Theme.fontSmall
        }

        RText {
            text: "CYCLE " + TimeTools.pomoCycles
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
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
        text: TimeTools.pomoFocus / 60 + "M FOCUS  /  " + TimeTools.pomoBreak / 60 + "M BREAK"
        color: Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall
    }
}
