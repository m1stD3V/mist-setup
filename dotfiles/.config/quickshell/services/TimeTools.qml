pragma Singleton

import QtQuick
import Quickshell

// Alarm, countdown timer, and pomodoro state. Lives outside the bar
// so any of them keep running while the clock popup is closed.
Singleton {
    id: root

    readonly property string ringSound: Quickshell.shellPath("assets/ring.wav")

    // ---- alarms ----
    property var alarms: []
    property bool alarmRinging: false
    property int _nextAlarmId: 1

    // ---- countdown timer ----
    property int timerTotal: 25 * 60
    property int timerRemaining: 25 * 60
    property bool timerRunning: false
    property bool timerFinished: false

    readonly property int timerH: Math.floor(timerTotal / 3600)
    readonly property int timerM: Math.floor((timerTotal % 3600) / 60)
    readonly property int timerS: timerTotal % 60

    // ---- pomodoro ----
    property int pomoFocus: 25 * 60
    property int pomoBreak: 5 * 60
    property int pomoRemaining: 25 * 60
    property bool pomoRunning: false
    property string pomoMode: "focus"
    property int pomoCycles: 0
    property bool pomoFinished: false

    readonly property string pomoLabel: pomoMode === "focus" ? "FOCUS" : "BREAK"

    // ---- shared alert ----
    property bool alertActive: false
    property string alertKind: ""
    property int alertPlays: 0

    function _pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function fmt(secs: int): string {
        const total = Math.max(0, secs);
        return _pad(Math.floor(total / 60)) + ":" + _pad(total % 60);
    }

    function fmtLong(secs: int): string {
        const total = Math.max(0, secs);
        return _pad(Math.floor(total / 3600)) + ":" + _pad(Math.floor((total % 3600) / 60)) + ":" + _pad(total % 60);
    }

    function addAlarm(h: int, m: int): void {
        if (alarms.some(a => a.hour === h && a.minute === m))
            return;
        const list = alarms.concat([{
                "id": _nextAlarmId++,
                "hour": h,
                "minute": m,
                "enabled": true,
                "lastKey": ""
            }]);
        list.sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));
        alarms = list;
    }

    function removeAlarm(id: int): void {
        alarms = alarms.filter(a => a.id !== id);
    }

    function toggleAlarm(id: int): void {
        alarms = alarms.map(a => a.id === id ? Object.assign({}, a, {
            "enabled": !a.enabled
        }) : a);
    }

    // ---- timer controls ----
    function setTimerHMS(h: int, m: int, s: int): void {
        const total = Math.max(1, h * 3600 + m * 60 + s);
        timerTotal = total;
        timerRemaining = total;
        timerRunning = false;
        timerFinished = false;
        if (alertKind === "timer")
            dismissAlert();
    }

    function toggleTimer(): void {
        if (timerRunning) {
            timerRunning = false;
            return;
        }
        if (alertActive)
            dismissAlert();
        if (timerRemaining <= 0)
            timerRemaining = timerTotal;
        timerFinished = false;
        timerRunning = true;
    }

    function resetTimer(): void {
        timerRunning = false;
        timerRemaining = timerTotal;
        timerFinished = false;
        if (alertKind === "timer")
            dismissAlert();
    }

    // ---- pomodoro controls ----
    function togglePomo(): void {
        if (pomoRunning) {
            pomoRunning = false;
            return;
        }
        if (alertActive)
            dismissAlert();
        if (pomoRemaining <= 0)
            pomoRemaining = pomoMode === "focus" ? pomoFocus : pomoBreak;
        pomoFinished = false;
        pomoRunning = true;
    }

    function resetPomo(): void {
        pomoRunning = false;
        pomoMode = "focus";
        pomoRemaining = pomoFocus;
        pomoCycles = 0;
        pomoFinished = false;
        if (alertKind === "pomodoro")
            dismissAlert();
    }

    function skipPomo(): void {
        pomoRunning = false;
        pomoFinished = false;
        if (pomoMode === "focus") {
            pomoMode = "break";
            pomoRemaining = pomoBreak;
        } else {
            pomoMode = "focus";
            pomoRemaining = pomoFocus;
        }
    }

    // ---- alerting ----
    function startAlert(kind: string, summary: string, body: string): void {
        alertKind = kind;
        alertActive = true;
        alertPlays = 0;
        Quickshell.execDetached(["notify-send", "-a", "MIST-86", "-u", "normal", "-t", "10000", summary, body]);
    }

    function dismissAlert(): void {
        alertActive = false;
        alertKind = "";
        alertPlays = 0;
        alarmRinging = false;
        timerFinished = false;
        pomoFinished = false;
    }

    function _alarmKey(d: var): string {
        return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}-${d.getHours()}-${d.getMinutes()}`;
    }

    function tick(): void {
        const now = new Date();

        if (alarms.length > 0) {
            const key = _alarmKey(now);
            const fired = [];
            const updated = alarms.map(a => {
                if (a.enabled && now.getHours() === a.hour && now.getMinutes() === a.minute && a.lastKey !== key) {
                    fired.push(a);
                    return Object.assign({}, a, {
                        "lastKey": key
                    });
                }
                return a;
            });
            if (fired.length > 0) {
                alarms = updated;
                alarmRinging = true;
                const times = fired.map(a => _pad(a.hour) + ":" + _pad(a.minute)).join(", ");
                startAlert("alarm", "ALARM", "Alarm at " + times + ".");
            }
        }

        if (timerRunning && timerRemaining > 0) {
            timerRemaining--;
            if (timerRemaining <= 0) {
                timerRemaining = 0;
                timerRunning = false;
                timerFinished = true;
                startAlert("timer", "TIMER DONE", "Your countdown has finished.");
            }
        }

        if (pomoRunning && pomoRemaining > 0) {
            pomoRemaining--;
            if (pomoRemaining <= 0) {
                pomoRunning = false;
                pomoFinished = true;
                if (pomoMode === "focus") {
                    pomoCycles++;
                    pomoMode = "break";
                    pomoRemaining = pomoBreak;
                    startAlert("pomodoro", "FOCUS COMPLETE", "Time for a break.");
                } else {
                    pomoMode = "focus";
                    pomoRemaining = pomoFocus;
                    startAlert("pomodoro", "BREAK OVER", "Back to focus.");
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: root.tick()
    }

    // ring a few times, then stop on its own; the alert state remains
    // until dismissed so the popup can show what fired
    Timer {
        interval: 2500
        running: root.alertActive && root.alertPlays < 8
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!root.alertActive)
                return;
            root.alertPlays++;
            Quickshell.execDetached(["paplay", root.ringSound]);
        }
    }
}
