pragma Singleton

import QtQuick
import Quickshell
import qs.Theme

Singleton {
    id: root

    property string query: ""
    property var results: []
    property int selectedIndex: 0

    readonly property var allApps: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    property string trimmed: query.trim()
    property bool packageMode: isPackageMode(query.trim())
    property string pkgQuery: pkgQueryOf(query.trim())
    property bool fileMode: isFileMode(query.trim())
    property string fileQuery: fileQueryOf(query.trim())

    function isPackageMode(q: string): bool {
        const t = q.trim();
        return /^(?:install|pkg)(?:\s|$)/i.test(t) && t.length > 0;
    }

    function pkgQueryOf(q: string): string {
        const m = q.trim().match(/^(?:install|pkg)\s+(.*)$/i);
        return m ? m[1].trim() : "";
    }

    function isFileMode(q: string): bool {
        const t = q.trim();
        return /^(?:file)(?:\s|$)/i.test(t) && t.length > 0;
    }

    function fileQueryOf(q: string): string {
        const m = q.trim().match(/^(?:file)\s+(.*)$/i);
        return m ? m[1].trim() : "";
    }

    function score(entry: DesktopEntry, q: string): int {
        const name = entry.name.toLowerCase();
        const id = entry.id.toLowerCase();
        const comment = (entry.comment ?? "").toLowerCase();
        const keywords = (entry.keywords ?? []).join(" ").toLowerCase();

        if (name.startsWith(q))
            return 0;
        if (id.startsWith(q))
            return 1;
        if (name.includes(q))
            return 2;
        if (id.includes(q))
            return 3;
        if (keywords.includes(q))
            return 4;
        if (comment.includes(q))
            return 5;
        return -1;
    }

    function appResult(entry: DesktopEntry): var {
        return {
            "kind": "app",
            "label": entry.name,
            "subtitle": entry.comment ?? "",
            "entry": entry
        };
    }

    function searchApps(q: string): var {
        const query = q.trim().toLowerCase();
        let apps;
        if (query.length === 0) {
            apps = allApps.slice(0, 11);
        } else {
            apps = allApps.map(e => [score(e, query), e]).filter(p => p[0] >= 0).sort((a, b) => a[0] - b[0] || (a[1].name < b[1].name ? -1 : 1)).map(p => p[1]).slice(0, 11);
        }
        return apps.map(appResult);
    }

    function searchResults(q: string): var {
        if (isPackageMode(q)) {
            const p = pkgQueryOf(q);
            return [{
                    "kind": "pacseek",
                    "label": "OPEN PACSEEK",
                    "subtitle": p.length > 0 ? "SEARCH " + p + " IN PACSEEK · QUERY COPIED TO CLIPBOARD" : "VISUAL PACMAN + AUR PACKAGE BROWSER",
                    "query": p
                }];
        }

        if (isFileMode(q)) {
            const f = fileQueryOf(q);
            return FileSearch.query === f ? FileSearch.results : [];
        }

        return searchApps(q);
    }

    function refreshResults(): void {
        results = searchResults(query.trim());
        if (selectedIndex >= results.length)
            selectedIndex = Math.max(0, results.length - 1);
    }

    function search(): void {
        const q = query.trim();
        results = searchResults(q);
        selectedIndex = 0;
        if (isFileMode(q))
            FileSearch.search(fileQueryOf(q));
    }

    function _accentHueSat(): var {
        const c = Theme.accent;
        const r = c.r;
        const g = c.g;
        const b = c.b;
        const mx = Math.max(r, g, b);
        const mn = Math.min(r, g, b);
        const d = mx - mn;
        if (d <= 0 || mx <= 0)
            return {
                "h": 0,
                "s": 0
            };
        let h;
        if (mx === r)
            h = ((g - b) / d) % 6;
        else if (mx === g)
            h = (b - r) / d + 2;
        else
            h = (r - g) / d + 4;
        h *= 60;
        if (h < 0)
            h += 360;
        return {
            "h": h,
            "s": d / mx
        };
    }

    function pacseekTheme(): string {
        const hs = _accentHueSat();
        if (hs.s < 0.12)
            return "default";
        if (hs.h >= 250 && hs.h < 345)
            return "catppuccin-mocha";
        if (hs.h >= 120 && hs.h < 250)
            return "tokyo-night";
        if (hs.h >= 30 && hs.h < 120)
            return "gruvbox";
        return "default";
    }

    function openPacseek(q: string): void {
        const p = (q ?? "").trim();
        if (p.length > 0)
            Quickshell.execDetached(["wl-copy", p]);

        // pacseek is a TUI: on small logical screens also shrink the terminal
        // font so the grid stays dense enough to use (MesloLGS NF cells
        // measured at 11.0x23.5 logical px at the config's 14pt)
        const fm = Hypr.focusedMonitor?.name ?? "";
        const screen = Quickshell.screens.find(s => (Hypr.monitorFor(s)?.name ?? "") === fm) ?? null;
        const fit = screen ? Math.min(1, Math.min(screen.width / 1920, screen.height / 1080)) : 1;
        const fontPt = Math.max(10, Math.min(14, Math.round(14 * fit)));
        const cellW = 11.0 * fontPt / 14;
        const cellH = 23.5 * fontPt / 14;
        const cols = screen ? Math.max(60, Math.min(160, Math.floor(screen.width * 0.6 / cellW))) : 97;
        const rows = screen ? Math.max(20, Math.min(44, Math.floor(screen.height * 0.62 / cellH))) : 29;

        const theme = pacseekTheme();
        const configHome = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        // quickshell's PATH lacks ~/.local/bin (where go/user binaries like
        // pacseek live), so resolve the binary explicitly and fail loudly
        const script = "export PATH=\"$HOME/.local/bin:$PATH\"; bin=\"$(command -v pacseek || true)\"; if [ -z \"$bin\" ]; then command -v notify-send >/dev/null 2>&1 && notify-send -u critical \"Launcher\" \"pacseek not found in PATH\"; exit 127; fi; f=\"$1/pacseek/config.ini\"; t=\"theme = $2\"; if [ -f \"$f\" ]; then if ! grep -qxF \"$t\" \"$f\"; then tmp=$(mktemp); awk -v line=\"$t\" 'BEGIN{done=0} /^[[:space:]]*#?[[:space:]]*theme[[:space:]]*=/{if(!done){print line; done=1} else next; next} {print} END{if(!done) print line}' \"$f\" > \"$tmp\" && mv \"$tmp\" \"$f\"; fi; else mkdir -p \"$(dirname \"$f\")\"; printf '%s\\n' \"$t\" > \"$f\"; fi; exec ghostty --font-size=" + fontPt + " --window-width=" + cols + " --window-height=" + rows + " --title=pacseek --confirm-close-surface=false -e \"$bin\" --ascii";
        Quickshell.execDetached(["sh", "-c", script, "sh", configHome, theme]);
    }

    function execute(item: var): void {
        if (!item)
            return;
        if (item.kind === "app")
            item.entry.execute();
        else if (item.kind === "pacseek")
            openPacseek(item.query ?? "");
        else if (item.kind === "file")
            Quickshell.execDetached(["xdg-open", item.path]);
        ShellState.launcherOpen = false;
        query = "";
    }

    function moveSelection(delta: int): void {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
    }

    function confirm(): void {
        execute(results[selectedIndex]);
    }

    onQueryChanged: {
        trimmed = query.trim();
        packageMode = isPackageMode(query);
        pkgQuery = pkgQueryOf(query);
        fileMode = isFileMode(query);
        fileQuery = fileQueryOf(query);
        search();
    }

    // re-search when desktop entries finish async scanning
    Connections {
        function onValuesChanged() {
            if (!root.packageMode)
                root.search();
        }

        target: DesktopEntries.applications
    }

    Connections {
        function onResultsChanged() {
            root.refreshResults();
        }

        target: FileSearch
    }

    Component.onCompleted: search()
}
