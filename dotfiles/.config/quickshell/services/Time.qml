pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property alias date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    readonly property int seconds: clock.seconds

    readonly property string timeStr: Qt.formatDateTime(clock.date, "hh:mm:ss")
    readonly property string dateStr: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }
}
