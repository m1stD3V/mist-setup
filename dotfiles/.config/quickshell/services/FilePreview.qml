pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hover preview metadata for files/directories shown in search results.
// Runs a small python helper asynchronously so the UI never blocks.
Singleton {
    id: root

    property string path: ""
    property string requestPath: ""
    property bool loading: false
    property var preview: null

    function clear(): void {
        path = "";
        requestPath = "";
        preview = null;
        loading = false;
        if (proc.running)
            proc.running = false;
    }

    function show(p: string): void {
        const target = (p ?? "").trim();
        if (target.length === 0) {
            clear();
            return;
        }
        if (target === path && preview && !loading)
            return;
        path = target;
        requestPath = target;
        preview = null;
        loading = true;
        if (proc.running)
            proc.running = false;
        proc.command = ["python3", Quickshell.shellPath("scripts/file-preview.py"), target];
        proc.running = true;
    }

    function parse(text: string): void {
        if (requestPath !== path) {
            return;
        }
        try {
            const parsed = JSON.parse(text);
            if (parsed.path !== path)
                return;
            loading = false;
            preview = parsed;
        } catch (e) {
            loading = false;
            preview = {
                "path": path,
                "error": "Could not read preview"
            };
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
}
