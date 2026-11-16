pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Local times for the extra timezones in Settings.worldZones. `date` applies
// each zone's own DST rules, so the clock popup stays correct without a
// timezone database in QML. One shell pass fills every zone at once.
Singleton {
    id: root

    // { "<zone>": { "time": "14:32", "offset": 1 } }
    property var times: ({})
    property string localTime: ""
    property string localDate: ""

    readonly property var zones: Settings.worldZones

    function key(zone: string): string {
        const parts = zone.split("/");
        return (parts[parts.length - 1] ?? zone).replace(/_/g, " ").toUpperCase();
    }

    function timeFor(zone: string): string {
        return times[zone]?.time ?? "--:--";
    }

    function offsetFor(zone: string): int {
        return times[zone]?.offset ?? 0;
    }

    function refresh(): void {
        const list = zones.filter(z => typeof z === "string" && /^[A-Za-z0-9_+\-\/]{2,48}$/.test(z));
        if (list.length === 0) {
            times = ({});
            return;
        }

        const quoted = list.map(z => "'" + z + "'").join(" ");
        clockProc.command = ["sh", "-c", "printf 'local|%s|%s\\n' \"$(date +%H:%M)\" \"$(date +%Y-%m-%d)\"; for z in " + quoted + "; do printf '%s|%s|%s\\n' \"$z\" \"$(TZ=\"$z\" date +%H:%M)\" \"$(TZ=\"$z\" date +%Y-%m-%d)\"; done"];
        clockProc.running = true;
    }

    function ingest(text: string): void {
        const found = {};
        let local = "";
        let localDay = "";

        for (const line of text.trim().split("\n")) {
            const parts = line.split("|");
            if (parts.length < 3)
                continue;
            const zone = parts[0];
            if (zone === "local") {
                local = parts[1];
                localDay = parts[2];
                continue;
            }
            found[zone] = {
                "time": parts[1],
                "date": parts[2]
            };
        }

        const out = {};
        for (const zone of Object.keys(found)) {
            let offset = 0;
            if (localDay.length > 0 && found[zone].date > localDay)
                offset = 1;
            else if (localDay.length > 0 && found[zone].date < localDay)
                offset = -1;
            out[zone] = {
                "time": found[zone].time,
                "offset": offset
            };
        }

        localTime = local;
        localDate = localDay;
        times = out;
    }

    onZonesChanged: refresh()

    Process {
        id: clockProc

        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
