pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One-shot reminders, listed in the clock popup's REMIND tab. They fire
// through notify-send, so the shell's own notification server shows them even
// with the popup closed. Session-only, like the alarms in TimeTools.
Singleton {
    id: root

    // [{ id, text, at, fired }]
    property var items: []
    property int nextId: 1

    // bumped every second so the labels ("IN 4M") stay live
    property double nowMs: Date.now()

    readonly property int pendingCount: items.filter(i => !i.fired).length
    readonly property int firedCount: items.length - pendingCount

    function schedule(text: string, atMs: double): bool {
        const body = text.trim();
        if (body.length === 0)
            return false;
        const list = items.concat([{
                "id": nextId++,
                "text": body,
                "at": atMs,
                "fired": false
            }]);
        list.sort((a, b) => a.at - b.at);
        items = list;
        return true;
    }

    function addIn(text: string, minutes: int): bool {
        return schedule(text, Date.now() + Math.max(1, minutes) * 60000);
    }

    function addClock(text: string, hour: int, minute: int): bool {
        const now = new Date();
        const target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0, 0);
        if (target.getTime() <= now.getTime())
            target.setDate(target.getDate() + 1);
        return schedule(text, target.getTime());
    }

    function remove(id: int): void {
        items = items.filter(i => i.id !== id);
    }

    function clearFired(): void {
        items = items.filter(i => !i.fired);
    }

    function label(item: var): string {
        if (item.fired)
            return "DONE";
        const left = Math.round((item.at - nowMs) / 1000);
        if (left <= 0)
            return "NOW";
        if (left < 60)
            return left + "S";
        if (left < 3600)
            return Math.floor(left / 60) + "M";
        if (left < 86400) {
            const hours = Math.floor(left / 3600);
            const minutes = Math.floor((left % 3600) / 60);
            return minutes > 0 ? hours + "H " + minutes + "M" : hours + "H";
        }
        return Math.floor(left / 86400) + "D";
    }

    function clock(item: var): string {
        const d = new Date(item.at);
        const h = d.getHours();
        const m = d.getMinutes();
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    function tick(): void {
        nowMs = Date.now();
        const due = items.filter(i => !i.fired && i.at <= nowMs);
        if (due.length === 0)
            return;
        items = items.map(i => due.some(d => d.id === i.id) ? Object.assign({}, i, {
            "fired": true
        }) : i);
        for (const item of due)
            Quickshell.execDetached(["notify-send", "-a", "MIST-86", "-u", "normal", "-t", "10000", "REMINDER", item.text]);
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }
}
