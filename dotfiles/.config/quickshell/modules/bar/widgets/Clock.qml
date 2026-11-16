pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services
import "clock"

// Bar clock. The popup (alarms, timer, pomodoro, reminders, world clocks) lives
// in clock/ — this file used to hold both and was 850 lines of unrelated state.
BarChip {
    id: root

    property var window

    bar: root.window
    active: popup.open
    accessibleName: qsTr("Clock %1:%2").arg(Time.format("hh")).arg(Time.format("mm"))

    onTapped: popup.open = !popup.open

    readonly property color fg: root.hot ? Theme.inverseText : (TimeTools.alertActive && Theme.blink ? Theme.textHigh : Theme.text)
    readonly property color fgDim: root.hot ? Theme.inverseText : (TimeTools.alertActive ? Theme.textHigh : Theme.textMuted)
    readonly property int hour12: {
        const h = Time.hours % 12;
        return h === 0 ? 12 : h;
    }
    readonly property string hourText: Settings.clock24h ? Time.format("hh") : TimeTools.pad2(root.hour12)

    Row {
        id: timeRow

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

    ClockPopup {
        id: popup

        barWindow: root.window
    }
}
