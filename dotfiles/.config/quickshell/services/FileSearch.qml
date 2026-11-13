pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Asynchronous file/directory search used by the program executor and
// the bar search dropdown. Runs a debounced `find` under $HOME and
// returns matching paths.
Singleton {
    id: root

    property string query: ""
    property string searchQuery: ""
    property var results: []

    function clear(): void {
        query = "";
        searchQuery = "";
        results = [];
        if (proc.running)
            proc.running = false;
        debounce.stop();
    }

    function search(q: string): void {
        const t = q.trim();
        if (t.length < 2) {
            clear();
            return;
        }
        if (t === query && (proc.running || results.length > 0))
            return;
        query = t;
        results = [];
        debounce.restart();
    }

    function run(): void {
        if (query.length < 2)
            return;
        searchQuery = query;
        const pattern = "*" + query.replace(/[\\*?\[\]]/g, "\\$&") + "*";
        if (proc.running)
            proc.running = false;
        proc.command = ["sh", "-c", "find \"$HOME\" -maxdepth 5 -iname \"$1\" -not -path \"*/.git/*\" -not -path \"*/node_modules/*\" -printf '%y\\t%p\\n' 2>/dev/null | head -n 300", "sh", pattern];
        proc.running = true;
    }

    function parse(text: string): void {
        if (searchQuery !== query)
            return;
        const q = query.toLowerCase();
        const rows = [];
        for (const line of text.split("\n")) {
            const m = line.match(/^([df])\t(.+)$/);
            if (!m)
                continue;
            const path = m[2];
            const base = path.split("/").pop() || path;
            const lower = base.toLowerCase();
            let score = 4;
            if (lower === q)
                score = 0;
            else if (lower.startsWith(q))
                score = 1;
            else if (lower.includes(q))
                score = 2;
            else if (path.toLowerCase().includes(q))
                score = 3;
            rows.push({
                "kind": "file",
                "label": base,
                "subtitle": path,
                "path": path,
                "isDir": m[1] === "d",
                "score": score
            });
        }
        rows.sort((a, b) => a.score - b.score || a.label.localeCompare(b.label));
        results = rows.slice(0, 20);
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        id: debounce

        interval: 180
        repeat: false

        onTriggered: root.run()
    }
}
