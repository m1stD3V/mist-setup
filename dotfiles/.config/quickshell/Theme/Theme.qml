pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ---- palette: monochrome phosphor, rethemed from the wallpaper ----
    // One literal per colour, shared by the properties below and reset(), so
    // the two can never drift apart.
    readonly property var defaultPalette: ({
            "bg": "#0a0a0a",
            "surface": "#121212",
            "surfaceHigh": "#1d1d1d",
            "surfaceHighest": "#2a2a2a",
            "border": "#303030",
            "borderHigh": "#565656",
            "text": "#d4d4d4",
            "textHigh": "#ffffff",
            "textDim": "#8f8f8f",
            "textMuted": "#585858",
            "inverseBg": "#e6e6e6",
            "inverseText": "#0d0d0d",
            "accent": "#e6e6e6",
            "accentDim": "#565656"
        })

    property color bg: root.defaultPalette.bg
    property color surface: root.defaultPalette.surface
    property color surfaceHigh: root.defaultPalette.surfaceHigh
    property color surfaceHighest: root.defaultPalette.surfaceHighest
    property color border: root.defaultPalette.border
    property color borderHigh: root.defaultPalette.borderHigh
    property color text: root.defaultPalette.text
    property color textHigh: root.defaultPalette.textHigh
    property color textDim: root.defaultPalette.textDim
    property color textMuted: root.defaultPalette.textMuted
    property color inverseBg: root.defaultPalette.inverseBg
    property color inverseText: root.defaultPalette.inverseText
    property color accent: root.defaultPalette.accent
    property color accentDim: root.defaultPalette.accentDim
    // fixed highlight for interactive states (hover/active/selected);
    // unlike inverseBg this is not rethemed from the wallpaper
    property color highlight: "#f72585"
    // translucent tint for the bar, recomputed from the wallpaper;
    // barOpacity is adjustable from Settings
    property real barOpacity: 0.78
    property real barTintHue: 0
    property real barTintSat: 0
    readonly property color barBg: hsla(barTintHue, barTintSat, 0.10, barOpacity)
    readonly property color barBorder: hsla(barTintHue, Math.min(0.55, barTintSat + 0.12), 0.34, 0.65)

    // ---- font: Tiny5 (5x5 pixel grid) ----
    // Tiny5 needs a larger pixel size than a normal font to stay legible, so
    // every popup shares this ladder: extraSmall for hints/footers, small for
    // body text and rows, medium for inputs and headings.
    readonly property string family: "Tiny5"
    readonly property int fontExtraSmall: 12
    readonly property int fontSmall: 15
    readonly property int fontMedium: 20
    readonly property int fontLarge: 25
    readonly property int fontHuge: 30

    // ---- dimensions ----
    // barHeight is owned by Settings (persisted, user adjustable); this is the
    // fallback used before the settings file is loaded.
    property int barHeight: 40
    // every bar chip and read-only module shares one height and one gap so the
    // bar reads as a single row instead of a set of hand-tuned boxes
    readonly property int barChipHeight: Math.max(18, barHeight - 10)
    readonly property int barPad: spacingSm
    readonly property int barSpacing: 6
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16

    // ---- shared bar popup metrics ----
    // Sized around the popup font ladder above: rows fit body text with a
    // little breathing room, and the popup is wide enough not to truncate it.
    readonly property int popupWidth: 400
    readonly property int popupRowHeight: 30
    readonly property int popupRowSpacing: 4
    readonly property int popupChromeHeight: Theme.titleBarHeight + 13

    // ---- popup window chrome ----
    readonly property int titleBarHeight: 22

    property bool blink: false

    // Fits a fixed-size frame onto the screen, shrinking it only when it truly
    // does not fit. Do not scale from a design reference resolution: a
    // 1080p-designed frame on a 1280x800 desktop would otherwise shrink its
    // text to an unreadable size even though the frame fits at full size.
    function fitScale(screenW: real, screenH: real, frameW: real, frameH: real): real {
        const margin = 24;
        const availW = Math.max(1, screenW - margin * 2);
        const availH = Math.max(1, screenH - barHeight - margin * 2);
        return Math.min(1, availW / frameW, availH / frameH);
    }

    // apply a palette of {h: hue 0-360, s: saturation 0-1} with a fixed
    // lightness ladder; keeps the monochrome feel, tinted by the wallpaper
    function retheme(p: var): void {
        const nh = p.neutralH ?? 0;
        const ns = Math.max(0, Math.min(0.30, (p.neutralS ?? 0) * 0.9));
        const ah = p.accentH ?? nh;
        const as = Math.max(0, Math.min(0.85, (p.accentS ?? 0) * 1.15));

        bg = hsl(nh, ns, 0.05);
        surface = hsl(nh, ns, 0.10);
        surfaceHigh = hsl(nh, ns, 0.16);
        surfaceHighest = hsl(nh, ns, 0.22);
        border = hsl(nh, ns * 0.9, 0.28);
        borderHigh = hsl(ah, ns * 0.7 + as * 0.15, 0.48);
        text = hsl(nh, ns * 0.7, 0.84);
        textHigh = hsl(nh, ns * 0.5, 0.97);
        textDim = hsl(ah, ns * 0.7 + as * 0.25, 0.60);
        textMuted = hsl(nh, ns * 0.7, 0.38);
        inverseBg = hsl(ah, Math.min(as, 0.45), 0.86);
        inverseText = hsl(nh, ns, 0.08);
        accent = hsl(ah, as, 0.62);
        accentDim = hsl(ah, as * 0.8, 0.40);

        barTintHue = nh;
        barTintSat = Math.max(0.18, Math.min(0.42, ns * 0.8 + 0.14));
    }

    function reset(): void {
        for (const key of Object.keys(root.defaultPalette))
            root[key] = root.defaultPalette[key];
        barTintHue = 0;
        barTintSat = 0;
    }

    function hsla(h: real, s: real, l: real, a: real): color {
        const c = hsl(h, s, l);
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function hsl(h: real, s: real, l: real): color {
        const c = (1 - Math.abs(2 * l - 1)) * s;
        const hp = ((h % 360) + 360) % 360 / 60;
        const x = c * (1 - Math.abs(hp % 2 - 1));
        let r = 0;
        let g = 0;
        let b = 0;
        if (hp < 1) {
            r = c;
            g = x;
        } else if (hp < 2) {
            r = x;
            g = c;
        } else if (hp < 3) {
            g = c;
            b = x;
        } else if (hp < 4) {
            g = x;
            b = c;
        } else if (hp < 5) {
            r = x;
            b = c;
        } else {
            r = c;
            b = x;
        }
        const m = l - c / 2;
        return Qt.rgba(Math.abs(r + m), Math.abs(g + m), Math.abs(b + m), 1);
    }

    Timer {
        interval: 530
        running: true
        repeat: true

        onTriggered: root.blink = !root.blink
    }
}
