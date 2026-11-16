pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history backed by cliphist. A watcher mirrors the Wayland
// clipboard into cliphist's database; the picker reads it back with
// `cliphist list`. Images are stored as PNG and decoded for the preview
// only while they are selected.
Singleton {
    id: root

    // cliphist renders non-text entries as "[[ binary data 1234 png WxH ]]"
    readonly property string binaryPrefix: "[[ binary data"

    property var entries: []
    property int maxEntries: 120
    // file the selected image entry was decoded to, empty for text entries
    property string imagePreviewPath: ""
    property string _previewId: ""

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function parse(text: string): void {
        const rows = [];
        for (const line of text.split("\n")) {
            if (line.length === 0)
                continue;
            const tab = line.indexOf("\t");
            const id = parseInt(tab >= 0 ? line.slice(0, tab) : line);
            if (isNaN(id))
                continue;
            const preview = tab >= 0 ? line.slice(tab + 1) : "";
            rows.push({
                "id": id,
                "preview": preview,
                "image": preview.startsWith(root.binaryPrefix)
            });
            if (rows.length >= root.maxEntries)
                break;
        }
        entries = rows;
    }

    function copy(entry: var): void {
        if (!entry)
            return;
        const type = entry.image ? " --type image/png" : "";
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + entry.id + " | wl-copy" + type]);
    }

    function remove(entry: var): void {
        if (!entry)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' " + entry.id + " | cliphist delete"]);
        if (String(entry.id) === _previewId) {
            _previewId = "";
            imagePreviewPath = "";
        }
        refreshTimer.restart();
    }

    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        Quickshell.execDetached(["sh", "-c", "rm -f /tmp/mist-clip-*.png"]);
        entries = [];
        _previewId = "";
        imagePreviewPath = "";
    }

    // Decode the selected image into /tmp so the picker can show it. Only one
    // decode runs at a time: a fast selection change queues the newest id.
    property string _pendingId: ""

    function previewImage(entry: var): void {
        if (!entry || !entry.image) {
            _previewId = "";
            _pendingId = "";
            imagePreviewPath = "";
            return;
        }
        const id = String(entry.id);
        if (_previewId === id && (previewProc.running || imagePreviewPath.length > 0))
            return;
        if (previewProc.running) {
            _pendingId = id;
            return;
        }
        startPreview(id);
    }

    function startPreview(id: string): void {
        _previewId = id;
        imagePreviewPath = "";
        previewProc.command = ["sh", "-c", "cliphist decode " + id + " > /tmp/mist-clip-" + id + ".png"];
        previewProc.running = true;
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: previewProc

        onExited: {
            const pending = root._pendingId;
            root._pendingId = "";
            if (pending.length > 0 && pending !== root._previewId) {
                root.startPreview(pending);
                return;
            }
            if (root._previewId.length > 0)
                root.imagePreviewPath = "/tmp/mist-clip-" + root._previewId + ".png";
        }
    }

    Timer {
        id: refreshTimer

        interval: 120
        onTriggered: root.refresh()
    }

    // Keep exactly one cliphist watcher alive. flock makes a second copy wait
    // for the current one instead of storing everything twice; when the active
    // watcher exits (shell reload, kill) the waiting copy takes over at once.
    // The wait is bounded so a hard restart cannot leave wrappers behind.
    Process {
        id: watchProc

        command: ["sh", "-c", "exec 9>/tmp/mist-cliphist.lock; flock -w 30 9 || exit 1; exec wl-paste --watch cliphist store"]

        onExited: {
            watchRestart.interval = exitCode === 0 ? 1000 : 3000;
            watchRestart.restart();
        }
    }

    Timer {
        id: watchRestart

        interval: 1500
        onTriggered: watchProc.running = true
    }

    Component.onCompleted: {
        refresh();
        watchProc.running = true;
        // drop stale preview decodes from earlier sessions
        Quickshell.execDetached(["sh", "-c", "find /tmp -maxdepth 1 -name 'mist-clip-*.png' -mtime +0 -delete 2>/dev/null"]);
    }
}
