pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme

Singleton {
    id: root

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.config/wallpaper"
    readonly property string defaultWallpaper: wallpaperDir + "/THINK.png"
    readonly property string savePath: Quickshell.env("HOME") + "/.local/state/mist/wallpaper"

    property string current: ""
    property bool restored: false

    readonly property url currentUrl: current.length > 0 ? Qt.resolvedUrl(current) : ""
    readonly property bool animated: /\.gif$/i.test(current)
    readonly property bool video: isVideoFile(current)

    function isVideoFile(nameOrPath: var): bool {
        return /\.(mp4|webm|mkv|mov|m4v|avi|ogv)$/i.test(String(nameOrPath ?? ""));
    }

    function apply(pathOrUrl: var): void {
        let p = String(pathOrUrl ?? "");
        if (p.startsWith("file://")) {
            p = decodeURIComponent(p.slice(7));
        }
        if (p.length === 0)
            return;
        current = p;
        stateFile.setText(p + "\n");
    }

    function restore(): void {
        if (restored)
            return;
        const saved = stateFile.text().trim();
        const target = saved.length > 0 ? saved : defaultWallpaper;
        current = target;
        restored = true;
    }

    FileView {
        id: stateFile

        path: root.savePath
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    Component.onCompleted: root.restore()

    // wallpaper palette sampling: 16x9 rgb dump as decimal text, then
    // full palette extraction in QML (neutral cast + vibrant accent)
    property var pixelBytes: []

    Process {
        id: ghosttyThemeProc

        command: ["python3", Quickshell.env("HOME") + "/.config/ghostty/sync-theme.py", root.current]
    }

    Process {
        id: samplerProc

        stdout: SplitParser {
            onRead: data => {
                const nums = data.trim().split(/\s+/);
                for (const t of nums) {
                    const v = parseInt(t);
                    if (!isNaN(v) && v >= 0 && v <= 255)
                        root.pixelBytes.push(v);
                }
            }
        }

        onExited: root.analyze()
    }

    function analyze(): void {
        const bytes = pixelBytes;
        pixelBytes = [];
        const n = Math.floor(bytes.length / 3);
        if (n < 4) {
            Theme.reset();
            ghosttyThemeProc.running = true;
            return;
        }
        let tr = 0;
        let tg = 0;
        let tb = 0;
        let bestScore = 0;
        let best = null;
        let hSum = 0;
        let hCount = 0;
        for (let i = 0; i < n; i++) {
            const r = bytes[i * 3] / 255;
            const g = bytes[i * 3 + 1] / 255;
            const b = bytes[i * 3 + 2] / 255;
            tr += r;
            tg += g;
            tb += b;
            const mx = Math.max(r, g, b);
            const mn = Math.min(r, g, b);
            const l = (mx + mn) / 2;
            let sat = 0;
            let h = 0;
            if (mx !== mn) {
                const d = mx - mn;
                sat = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
                if (mx === r)
                    h = (g - b) / d + (g < b ? 6 : 0);
                else if (mx === g)
                    h = (b - r) / d + 2;
                else
                    h = (r - g) / d + 4;
                h *= 60;
            }
            const score = sat * (1 - Math.abs(l - 0.5) * 1.4);
            if (sat > 0.12 && score > bestScore) {
                bestScore = score;
                best = {
                    "h": h,
                    "s": sat
                };
            }
        }
        const ar = tr / n;
        const ag = tg / n;
        const ab = tb / n;
        const amx = Math.max(ar, ag, ab);
        const amn = Math.min(ar, ag, ab);
        const al = (amx + amn) / 2;
        let ns = 0;
        let nh = 0;
        if (amx !== amn) {
            const d = amx - amn;
            ns = al > 0.5 ? d / (2 - amx - amn) : d / (amx + amn);
            if (amx === ar)
                nh = (ag - ab) / d + (ag < ab ? 6 : 0);
            else if (amx === ag)
                nh = (ab - ar) / d + 2;
            else
                nh = (ar - ag) / d + 4;
            nh *= 60;
        }
        Theme.retheme({
            "neutralH": best ? best.h : nh,
            "neutralS": ns,
            "accentH": best ? best.h : nh,
            "accentS": best ? best.s : 0
        });
        ghosttyThemeProc.running = true;
    }

    function sample(path: string): void {
        pixelBytes = [];
        if (path.length === 0) {
            Theme.reset();
            return;
        }
        samplerProc.command = ["sh", "-c", "ffmpeg -hide_banner -loglevel error -i '" + path + "' -vf scale=16:9 -frames:v 1 -f rawvideo -pix_fmt rgb24 - | od -An -tu1 -v"];
        samplerProc.running = true;
    }

    onCurrentChanged: root.sample(current)
}
