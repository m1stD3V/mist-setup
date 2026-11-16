#!/usr/bin/env python3
"""Derive a Firefox theme from the wallpaper, mirroring qs Theme.retheme().

Writes chrome/userChrome.css, chrome/userContent.css and a managed block in
user.js inside the active Firefox profile. Run by Wallpapers.qml whenever the
wallpaper (and therefore the shell palette) changes.

Chrome CSS is only read at Firefox startup, so changes from a running shell
apply on the next launch. Nothing here touches web page colours.
"""

import configparser
import colorsys
import os
import subprocess
import sys

HOME = os.environ.get("HOME", os.path.expanduser("~"))
STATE = os.path.join(HOME, ".local/state/mist/wallpaper")
DEFAULT_WALL = os.path.join(HOME, ".config/wallpaper/THINK.png")
HIGHLIGHT = "#f72585"  # Theme.highlight, fixed in the shell

PREFS = [
    ("toolkit.legacyUserProfileCustomizations.stylesheets", "true"),
    ("ui.systemUsesDarkTheme", "1"),
    ("browser.theme.toolbar-theme", "0"),
    ("browser.theme.content-theme", "0"),
    ("layout.css.prefers-color-scheme.content-override", "0"),
    ("widget.non-native-theme.enabled", "true"),
]

BEGIN = "// >>> mist theme (generated, do not edit) >>>"
END = "// <<< mist theme <<<"

# Firefox 160 chrome is built from design tokens, many of them set inside a
# shadow root, so userChrome.css reaches it by overriding the tokens (as user
# !important, which outranks the browser's own sheets) rather than elements.
CHROME_TOKENS = [
    # toolbar / window
    ("toolbar-background-color", "var(--mist-bar)"),
    ("toolbox-background-color", "var(--mist-bar)"),
    ("toolbox-background-color-inactive", "var(--mist-bar)"),
    ("toolbox-text-color", "var(--mist-text)"),
    ("toolbar-text-color", "var(--mist-text)"),
    ("titlebar-background-color", "var(--mist-bar)"),
    ("titlebar-text-color", "var(--mist-text)"),
    # surfaces
    ("background-color-canvas", "var(--mist-bg)"),
    ("background-color-box", "var(--mist-surface)"),
    ("background-color-list-item-hover", "var(--mist-surface-high)"),
    ("panel-background-color", "var(--mist-surface-high)"),
    ("popup-background-color", "var(--mist-surface-high)"),
    # text and borders
    ("text-color", "var(--mist-text)"),
    ("text-color-deemphasized", "var(--mist-text-dim)"),
    ("border-color", "var(--mist-border)"),
    ("border-color-deemphasized", "var(--mist-border)"),
    ("border-color-interactive", "var(--mist-border-high)"),
    ("focus-outline-color", "var(--mist-highlight)"),
    ("color-accent-primary", "var(--mist-accent)"),
    ("color-accent-primary-hover", "var(--mist-accent)"),
    ("color-accent-primary-active", "var(--mist-accent-dim)"),
    ("color-accent-primary-selected", "var(--mist-accent)"),
    # buttons
    ("button-background-color", "var(--mist-surface-high)"),
    ("button-background-color-hover", "var(--mist-surface-highest)"),
    ("button-background-color-active", "var(--mist-surface-highest)"),
    ("button-text-color", "var(--mist-text)"),
    ("link-color", "var(--mist-accent)"),
    ("link-color-hover", "var(--mist-text-high)"),
    ("link-color-active", "var(--mist-accent)"),
    ("link-color-visited", "var(--mist-accent-dim)"),
    # sharp corners everywhere, like the shell
    ("border-radius-small", "0px"),
    ("border-radius-medium", "0px"),
    ("border-radius-large", "0px"),
    ("border-radius-xlarge", "0px"),
    ("button-border-radius", "0px"),
    ("panel-border-radius", "0px"),
    ("popup-border-radius", "0px"),
    ("tab-border-radius", "0px"),
    # toolbar buttons
    ("toolbarbutton-background-color", "transparent"),
    ("toolbarbutton-background-color-hover", "var(--mist-surface-high)"),
    ("toolbarbutton-background-color-active", "var(--mist-surface-highest)"),
    ("toolbarbutton-hover-background", "var(--mist-surface-high)"),
    ("toolbarbutton-active-background", "var(--mist-surface-highest)"),
    ("toolbarbutton-border-radius", "0px"),
    # urlbar
    ("toolbar-field-background-color", "var(--mist-surface)"),
    ("toolbar-field-background-color-focus", "var(--mist-surface)"),
    ("toolbar-field-color", "var(--mist-text-high)"),
    ("toolbar-field-color-focus", "var(--mist-text-high)"),
    ("toolbar-field-border-color", "var(--mist-border-high)"),
    ("toolbar-field-border-color-focus", "var(--mist-highlight)"),
    ("urlbar-background-color", "var(--mist-surface)"),
    ("urlbar-background-color-focus", "var(--mist-surface)"),
    ("urlbar-border-radius", "0px"),
    ("urlbarview-border-radius", "0px"),
    ("urlbar-box-background-color", "var(--mist-surface-high)"),
    ("urlbar-box-background-color-hover", "var(--mist-surface-highest)"),
    ("urlbar-box-background-color-active", "var(--mist-surface-highest)"),
    ("urlbarview-background-color-hover", "var(--mist-surface-high)"),
    ("urlbarview-background-color-selected", "var(--mist-surface-highest)"),
    ("urlbarview-text-color-hover", "var(--mist-text-high)"),
    ("urlbarview-text-color-selected", "var(--mist-text-high)"),
    ("urlbarview-text-color-secondary", "var(--mist-text-dim)"),
    ("urlbarview-text-color-action", "var(--mist-accent)"),
    ("urlbarview-separator-color", "var(--mist-border)"),
    # tabs
    ("tab-selected-bgcolor", "var(--mist-highlight)"),
    ("tab-selected-textcolor", "var(--mist-inverse-text)"),
    ("tab-hover-background-color", "var(--mist-surface-high)"),
    ("tab-text-color", "var(--mist-text-dim)"),
    # panels and menus
    ("panel-background", "var(--mist-surface-high)"),
    ("panel-color", "var(--mist-text)"),
    ("panel-border-color", "var(--mist-border-high)"),
    ("panel-separator-color", "var(--mist-border)"),
    ("arrowpanel-background", "var(--mist-surface-high)"),
    ("arrowpanel-color", "var(--mist-text)"),
    ("arrowpanel-border-color", "var(--mist-border-high)"),
    ("arrowpanel-dimmed", "var(--mist-surface-highest)"),
    ("menu-background-color", "var(--mist-surface-high)"),
    ("menu-color", "var(--mist-text)"),
    ("menu-border-color", "var(--mist-border-high)"),
    ("menuitem-hover-background-color", "var(--mist-highlight)"),
    ("menuitem-hover-color", "var(--mist-inverse-text)"),
    ("menuitem-disabled-hover-background-color", "var(--mist-surface-highest)"),
    ("autocomplete-popup-background", "var(--mist-surface-high)"),
    ("autocomplete-popup-color", "var(--mist-text)"),
    ("autocomplete-popup-highlight-background", "var(--mist-surface-highest)"),
    # sidebar
    ("sidebar-background-color", "var(--mist-bg)"),
    ("sidebar-text-color", "var(--mist-text)"),
    ("sidebar-border-color", "var(--mist-border)"),
    ("lwt-sidebar-background-color", "var(--mist-bg)"),
    ("lwt-sidebar-text-color", "var(--mist-text)"),
]


def hsl(h, s, l):
    h = ((h % 360) + 360) % 360 / 360.0
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return (r, g, b)


def hexc(rgb):
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02x}" for c in rgb)


def analyze(path):
    raw = subprocess.check_output(
        [
            "sh",
            "-c",
            "ffmpeg -hide_banner -loglevel error -i '"
            + path
            + "' -vf scale=16:9 -frames:v 1 -f rawvideo -pix_fmt rgb24 - | od -An -tu1 -v",
        ]
    )
    b = [int(x) for x in raw.split()]
    n = len(b) // 3
    if n < 4:
        return None

    tr = tg = tb = 0.0
    best_score = 0.0
    best = None
    for i in range(n):
        r, g, bl = (b[i * 3 + j] / 255.0 for j in range(3))
        tr += r
        tg += g
        tb += bl
        mx, mn = max(r, g, bl), min(r, g, bl)
        l = (mx + mn) / 2
        sat = 0.0
        h = 0.0
        if mx != mn:
            d = mx - mn
            sat = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
            if mx == r:
                h = (g - bl) / d + (6 if g < bl else 0)
            elif mx == g:
                h = (bl - r) / d + 2
            else:
                h = (r - g) / d + 4
            h *= 60
        score = sat * (1 - abs(l - 0.5) * 1.4)
        if sat > 0.12 and score > best_score:
            best_score = score
            best = {"h": h, "s": sat}

    ar, ag, ab = tr / n, tg / n, tb / n
    amx, amn = max(ar, ag, ab), min(ar, ag, ab)
    al = (amx + amn) / 2
    ns = nh = 0.0
    if amx != amn:
        d = amx - amn
        ns = d / (2 - amx - amn) if al > 0.5 else d / (amx + amn)
        if amx == ar:
            nh = (ag - ab) / d + (6 if ag < ab else 0)
        elif amx == ag:
            nh = (ab - ar) / d + 2
        else:
            nh = (ar - ag) / d + 4
        nh *= 60

    return {
        "neutralH": best["h"] if best else nh,
        "neutralS": ns,
        "accentH": best["h"] if best else nh,
        "accentS": best["s"] if best else 0.0,
    }


def palette(p):
    nh = p["neutralH"]
    ns = max(0.0, min(0.30, p["neutralS"] * 0.9))
    ah = p["accentH"]
    a_s = max(0.0, min(0.85, p["accentS"] * 1.15))
    c = {
        "bg": hsl(nh, ns, 0.05),
        "surface": hsl(nh, ns, 0.10),
        "surfaceHigh": hsl(nh, ns, 0.16),
        "surfaceHighest": hsl(nh, ns, 0.22),
        "border": hsl(nh, ns * 0.9, 0.28),
        "borderHigh": hsl(ah, ns * 0.7 + a_s * 0.15, 0.48),
        "text": hsl(nh, ns * 0.7, 0.84),
        "textHigh": hsl(nh, ns * 0.5, 0.97),
        "textDim": hsl(ah, ns * 0.7 + a_s * 0.25, 0.60),
        "textMuted": hsl(nh, ns * 0.7, 0.38),
        "inverseBg": hsl(ah, min(a_s, 0.45), 0.86),
        "inverseText": hsl(nh, ns, 0.08),
        "accent": hsl(ah, a_s, 0.62),
        "accentDim": hsl(ah, a_s * 0.8, 0.40),
    }
    # same tint as Theme.barBg, flattened: Firefox chrome cannot be translucent
    barSat = max(0.18, min(0.42, ns * 0.8 + 0.14))
    c["bar"] = hsl(nh, barSat, 0.10)
    return c


VAR_KEYS = [
    ("bg", "bg"),
    ("surface", "surface"),
    ("surface-high", "surfaceHigh"),
    ("surface-highest", "surfaceHighest"),
    ("border", "border"),
    ("border-high", "borderHigh"),
    ("text", "text"),
    ("text-high", "textHigh"),
    ("text-dim", "textDim"),
    ("text-muted", "textMuted"),
    ("inverse-bg", "inverseBg"),
    ("inverse-text", "inverseText"),
    ("accent", "accent"),
    ("accent-dim", "accentDim"),
    ("bar", "bar"),
]


def variables(c, indent, important=False):
    bang = " !important" if important else ""
    lines = [f"{indent}color-scheme: dark{bang};"]
    for name, key in VAR_KEYS:
        lines.append(f"{indent}--mist-{name}: {hexc(c[key])}{bang};")
    lines.append(f"{indent}--mist-highlight: {HIGHLIGHT}{bang};")
    return "\n".join(lines)


def chrome_css(c):
    tokens = "\n".join(
        f"  --{name}: {value} !important;" for name, value in CHROME_TOKENS
    )
    return (
        "/* Generated by sync-firefox-theme.py - do not edit by hand. */\n"
        "/* Palette follows the current quickshell (mist) theme; read at startup. */\n\n"
        ":root {\n"
        + variables(c, "  ")
        + "\n  scrollbar-color: var(--mist-border-high) var(--mist-bg) !important;\n\n"
        + tokens
        + "\n}\n\n"
        "/* ---- window chrome ---- */\n"
        "#navigator-toolbox {\n"
        "  background: var(--mist-bar) !important;\n"
        "  border-bottom: 1px solid var(--mist-border) !important;\n"
        "  box-shadow: none !important;\n"
        "}\n"
        "#nav-bar {\n"
        "  background: transparent !important;\n"
        "  border: none !important;\n"
        "  box-shadow: none !important;\n"
        "}\n"
        "#TabsToolbar { background: transparent !important; }\n"
        "#PersonalToolbar {\n"
        "  background: var(--mist-bar) !important;\n"
        "  border-top: 1px solid var(--mist-border) !important;\n"
        "  padding-inline: 4px !important;\n"
        "}\n"
        "#titlebar, #toolbar-menubar { background: transparent !important; }\n"
        "#toolbar-menubar > menubar > menu { color: var(--mist-text-dim) !important; }\n"
        "#toolbar-menubar > menubar > menu:hover {\n"
        "  background: var(--mist-highlight) !important;\n"
        "  color: var(--mist-inverse-text) !important;\n"
        "}\n\n"
        "/* ---- tabs ---- */\n"
        ".tabbrowser-tab { padding-inline: 0 !important; }\n"
        ".tab-background {\n"
        "  border-radius: 0 !important;\n"
        "  border: 1px solid transparent !important;\n"
        "  margin: 2px 1px !important;\n"
        "  background: transparent !important;\n"
        "  box-shadow: none !important;\n"
        "}\n"
        ".tabbrowser-tab:hover .tab-background { background: var(--mist-surface-high) !important; }\n"
        "/* active tab uses the shell's highlight, like the bar's active workspace */\n"
        ".tab-background[selected],\n"
        ".tabbrowser-tab[selected] .tab-background {\n"
        "  background: var(--mist-highlight) !important;\n"
        "  border-color: var(--mist-highlight) !important;\n"
        "  box-shadow: none !important;\n"
        "}\n"
        ".tab-label { color: var(--mist-text-dim) !important; }\n"
        ".tabbrowser-tab:hover .tab-label { color: var(--mist-text) !important; }\n"
        ".tabbrowser-tab[selected] .tab-label { color: var(--mist-inverse-text) !important; }\n"
        ".tab-close-button {\n"
        "  fill: var(--mist-text-dim) !important;\n"
        "  color: var(--mist-text-dim) !important;\n"
        "  border-radius: 0 !important;\n"
        "  opacity: .9 !important;\n"
        "}\n"
        ".tabbrowser-tab:hover .tab-close-button {\n"
        "  fill: var(--mist-text) !important;\n"
        "  color: var(--mist-text) !important;\n"
        "}\n"
        "/* the active tab is highlight pink, so its close button must be dark */\n"
        ".tabbrowser-tab[selected] .tab-close-button {\n"
        "  fill: var(--mist-inverse-text) !important;\n"
        "  color: var(--mist-inverse-text) !important;\n"
        "  opacity: .7 !important;\n"
        "}\n"
        ".tabbrowser-tab[selected] .tab-icon-overlay {\n"
        "  fill: var(--mist-inverse-text) !important;\n"
        "  color: var(--mist-inverse-text) !important;\n"
        "}\n"
        ".tabbrowser-tab:hover .tab-close-button:hover {\n"
        "  background: var(--mist-highlight) !important;\n"
        "  fill: var(--mist-inverse-text) !important;\n"
        "  color: var(--mist-inverse-text) !important;\n"
        "  opacity: 1 !important;\n"
        "}\n"
        "/* the active tab is already highlight, so invert its close button */\n"
        ".tabbrowser-tab[selected] .tab-close-button:hover {\n"
        "  background: var(--mist-inverse-text) !important;\n"
        "  fill: var(--mist-highlight) !important;\n"
        "  color: var(--mist-highlight) !important;\n"
        "  opacity: 1 !important;\n"
        "}\n"
        ".tab-icon-image { opacity: .9; }\n"
        "#tabs-newtab-button, #new-tab-button { fill: var(--mist-text-dim) !important; }\n"
        "#tabs-newtab-button:hover, #new-tab-button:hover { fill: var(--mist-text-high) !important; }\n\n"
        "/* ---- urlbar (element rules for the non-shadow chrome) ---- */\n"
        ".urlbar-background, #urlbar-background {\n"
        "  background: var(--mist-surface) !important;\n"
        "  border: 1px solid var(--mist-border-high) !important;\n"
        "  border-radius: 0 !important;\n"
        "  box-shadow: none !important;\n"
        "}\n"
        ".urlbar:is([focused], [open]) > .urlbar-background,\n"
        "#urlbar:is([focused], [breakout-extend]) > #urlbar-background {\n"
        "  border-color: var(--mist-highlight) !important;\n"
        "  box-shadow: none !important;\n"
        "}\n"
        "#urlbar-input, .urlbar-input { color: var(--mist-text-high) !important; }\n"
        "#urlbar-input::placeholder { color: var(--mist-text-muted) !important; }\n"
        "#identity-box, #tracking-protection-icon-container { fill: var(--mist-text-dim) !important; }\n"
        "#identity-box:hover, #tracking-protection-icon-container:hover { fill: var(--mist-text-high) !important; }\n"
        ".urlbarView-row { border-radius: 0 !important; }\n"
        ".urlbarView-title { color: var(--mist-text) !important; }\n"
        ".urlbarView-title-separator, .urlbarView-url { color: var(--mist-text-dim) !important; }\n"
        "#urlbar-results { padding-inline: 0 !important; }\n\n"
        "/* ---- panels and menus ---- */\n"
        "panelview, .panel-subview-body, .panel-arrowcontent { background: transparent !important; }\n"
        "menupopup menuitem, menupopup menu {\n"
        "  border-radius: 0 !important;\n"
        "  color: var(--mist-text) !important;\n"
        "}\n"
        "menupopup menuitem[_moz-menuactive=\"true\"],\n"
        "menupopup menu[_moz-menuactive=\"true\"] {\n"
        "  background-color: var(--mist-highlight) !important;\n"
        "  color: var(--mist-inverse-text) !important;\n"
        "}\n"
        "menupopup menuitem[_moz-menuactive=\"true\"] > label,\n"
        "menupopup menu[_moz-menuactive=\"true\"] > label { color: var(--mist-inverse-text) !important; }\n"
        "menuseparator { border-top: 1px solid var(--mist-border) !important; }\n"
        ".subviewbutton { border-radius: 0 !important; color: var(--mist-text) !important; }\n"
        ".subviewbutton:hover { background: var(--mist-surface-highest) !important; }\n"
        ".subviewbutton[checked=\"true\"] {\n"
        "  background: var(--mist-highlight) !important;\n"
        "  color: var(--mist-inverse-text) !important;\n"
        "}\n\n"
        "/* ---- toolbar buttons ---- */\n"
        "toolbarbutton > .toolbarbutton-icon,\n"
        "toolbarbutton > .toolbarbutton-badge-stack { border-radius: 0 !important; }\n"
        ".bookmark-item { color: var(--mist-text-dim) !important; border-radius: 0 !important; }\n"
        ".bookmark-item:hover { background: var(--mist-surface-high) !important; color: var(--mist-text) !important; }\n\n"
        "/* ---- sidebar ---- */\n"
        "#sidebar-box {\n"
        "  background: var(--mist-bg) !important;\n"
        "  border-right: 1px solid var(--mist-border) !important;\n"
        "  box-shadow: none !important;\n"
        "}\n"
        "#sidebar-box, #sidebar-main, #sidebar { color: var(--mist-text) !important; }\n"
        "#sidebar-header {\n"
        "  background: var(--mist-surface) !important;\n"
        "  color: var(--mist-text) !important;\n"
        "  border-bottom: 1px solid var(--mist-border) !important;\n"
        "}\n"
        "#sidebar-splitter { background: var(--mist-border) !important; border: none !important; }\n"
        ".sidebar-panel { background: var(--mist-bg) !important; color: var(--mist-text) !important; }\n\n"
        "/* ---- findbar, status, notifications ---- */\n"
        "findbar {\n"
        "  background: var(--mist-surface) !important;\n"
        "  border-top: 1px solid var(--mist-border-high) !important;\n"
        "  color: var(--mist-text) !important;\n"
        "}\n"
        "findbar .findbar-textbox {\n"
        "  background: var(--mist-bg) !important;\n"
        "  color: var(--mist-text-high) !important;\n"
        "  border: 1px solid var(--mist-border) !important;\n"
        "  border-radius: 0 !important;\n"
        "}\n"
        "#statuspanel-label {\n"
        "  background: var(--mist-surface) !important;\n"
        "  border: 1px solid var(--mist-border-high) !important;\n"
        "  color: var(--mist-text-dim) !important;\n"
        "  border-radius: 0 !important;\n"
        "}\n"
        "notification-message, .notificationbox-stack {\n"
        "  background: var(--mist-surface) !important;\n"
        "  color: var(--mist-text) !important;\n"
        "  border-radius: 0 !important;\n"
        "}\n\n"
        "/* ---- scrollbars ---- */\n"
        "scrollbar { -moz-appearance: none !important; background: var(--mist-bg) !important; }\n"
        "scrollbar thumb { background: var(--mist-border) !important; border-radius: 0 !important; }\n"
        "scrollbar thumb:hover { background: var(--mist-border-high) !important; }\n"
        "scrollbar scrollbarbutton { display: none !important; }\n\n"
        "/* ---- misc ---- */\n"
        "::selection { background: var(--mist-highlight) !important; color: var(--mist-inverse-text) !important; }\n"
        "#customization-container { background: var(--mist-bg) !important; color: var(--mist-text) !important; }\n"
    )


CONTENT_TOKENS = [
    ("in-content-page-background", "var(--mist-bg)"),
    ("in-content-page-color", "var(--mist-text)"),
    ("in-content-text-color", "var(--mist-text)"),
    ("in-content-deemphasized-text", "var(--mist-text-dim)"),
    ("in-content-box-background", "var(--mist-surface)"),
    ("in-content-box-background-odd", "var(--mist-surface-high)"),
    ("in-content-box-border-color", "var(--mist-border)"),
    ("in-content-border-color", "var(--mist-border)"),
    ("in-content-border-hover", "var(--mist-border-high)"),
    ("in-content-button-background", "var(--mist-surface-high)"),
    ("in-content-button-background-hover", "var(--mist-surface-highest)"),
    ("in-content-button-background-active", "var(--mist-surface-highest)"),
    ("in-content-primary-button-background", "var(--mist-highlight)"),
    ("in-content-primary-button-background-hover", "var(--mist-highlight)"),
    ("in-content-primary-button-text-color", "var(--mist-inverse-text)"),
    ("in-content-accent-color", "var(--mist-accent)"),
    ("in-content-link-color", "var(--mist-accent)"),
    ("in-content-link-color-hover", "var(--mist-text-high)"),
    ("in-content-focus-outline-color", "var(--mist-highlight)"),
    ("in-content-item-hover", "var(--mist-surface-high)"),
    ("in-content-item-selected", "var(--mist-highlight)"),
    ("in-content-item-selected-text", "var(--mist-inverse-text)"),
    ("in-content-table-background", "var(--mist-surface)"),
    ("in-content-table-border-color", "var(--mist-border)"),
    ("card-outline-color", "var(--mist-border)"),
    ("background-color-canvas", "var(--mist-bg)"),
    ("background-color-box", "var(--mist-surface)"),
    ("background-color-list-item-hover", "var(--mist-surface-high)"),
    ("text-color", "var(--mist-text)"),
    ("text-color-deemphasized", "var(--mist-text-dim)"),
    ("border-color", "var(--mist-border)"),
    ("border-color-deemphasized", "var(--mist-border)"),
    ("color-accent-primary", "var(--mist-accent)"),
    ("color-accent-primary-hover", "var(--mist-accent)"),
    ("color-accent-primary-active", "var(--mist-accent-dim)"),
    ("input-background-color", "var(--mist-surface)"),
    ("input-text-color", "var(--mist-text-high)"),
    ("input-border-color", "var(--mist-border)"),
    ("input-border-radius", "0px"),
    ("input-search-border-radius", "0px"),
    ("newtab-search-border-radius", "0px"),
    ("card-border-radius", "0px"),
    ("card-border-radius-compact", "0px"),
    ("panel-menuitem-border-radius", "0px"),
    ("tab-border-radius", "0px"),
    ("panel-background-color", "var(--mist-surface)"),
    ("popup-background-color", "var(--mist-surface-high)"),
    ("link-color", "var(--mist-accent)"),
    ("link-color-hover", "var(--mist-text-high)"),
    ("newtab-background-color", "var(--mist-bg)"),
    ("newtab-background-color-secondary", "var(--mist-surface)"),
    ("newtab-text-primary-color", "var(--mist-text)"),
    ("newtab-text-secondary-color", "var(--mist-text-dim)"),
    ("newtab-border-color", "var(--mist-border)"),
    ("newtab-element-hover-color", "var(--mist-surface-high)"),
    ("newtab-primary-action-background", "var(--mist-highlight)"),
    ("newtab-card-background-color", "var(--mist-surface)"),
    ("newtab-card-shadow", "none"),
    # the shell has square corners; Firefox's own pages are rounded by default
    ("border-radius-small", "0px"),
    ("border-radius-medium", "0px"),
    ("border-radius-large", "0px"),
    ("border-radius-xlarge", "0px"),
    ("button-border-radius", "0px"),
    ("panel-border-radius", "0px"),
    ("popup-border-radius", "0px"),
]


def content_css(c):
    tokens = "\n".join(
        f"    --{name}: {value} !important;" for name, value in CONTENT_TOKENS
    )
    return (
        "/* Generated by sync-firefox-theme.py - do not edit by hand. */\n"
        "/* Themes Firefox's own pages only; web pages keep their colours. */\n\n"
        "@-moz-document url-prefix(\"about:\") {\n"
        "  :root {\n"
        + variables(c, "    ", important=True)
        + "\n"
        + tokens
        + "\n    scrollbar-color: var(--mist-border-high) var(--mist-bg) !important;\n"
        "  }\n"
        "}\n\n"
        "@-moz-document url(\"about:blank\"), url(\"about:home\"), url(\"about:newtab\"),\n"
        "               url(\"about:privatebrowsing\"), url(\"about:sessionrestore\"),\n"
        "               url(\"about:welcome\"), url-prefix(\"view-source\") {\n"
        "  html, body {\n"
        "    background-color: var(--mist-bg) !important;\n"
        "    color: var(--mist-text) !important;\n"
        "  }\n"
        "}\n\n"
        "@-moz-document url-prefix(\"about:reader\") {\n"
        "  :root {\n"
        "    --main-background: var(--mist-bg) !important;\n"
        "    --main-foreground: var(--mist-text) !important;\n"
        "    --link-foreground: var(--mist-accent) !important;\n"
        "    --link-selected-foreground: var(--mist-text-high) !important;\n"
        "    --visited-link-foreground: var(--mist-accent-dim) !important;\n"
        "    --selected-background: var(--mist-highlight) !important;\n"
        "    --font-color: var(--mist-text) !important;\n"
        "  }\n"
        "  body { background-color: var(--mist-bg) !important; color: var(--mist-text) !important; }\n"
        "}\n"
    )


def prefs_js():
    out = [BEGIN, "// Dark scheme and the legacy stylesheet switch. user.js is applied"]
    out.append("// at every startup, so these override changes made in about:preferences.")
    for k, val in PREFS:
        out.append(f'user_pref("{k}", {val});')
    out.append(END)
    return "\n".join(out) + "\n"


def merge_user_js(path, block):
    managed = {f'user_pref("{k}"' for k, _ in PREFS}
    try:
        with open(path, encoding="utf-8") as f:
            old = f.read()
    except OSError:
        old = ""

    kept = []
    skipping = False
    for line in old.splitlines():
        if line.strip() == BEGIN:
            skipping = True
            continue
        if line.strip() == END:
            skipping = False
            continue
        if skipping:
            continue
        if any(line.startswith(p) for p in managed):
            continue
        kept.append(line)

    while kept and not kept[-1].strip():
        kept.pop()
    text = ("\n".join(kept) + "\n\n" if kept else "") + block
    return text


def profiles_roots():
    for rel in (".config/mozilla/firefox", ".mozilla/firefox"):
        yield os.path.join(HOME, rel)


def find_profile():
    for root in profiles_roots():
        ini = os.path.join(root, "profiles.ini")
        if not os.path.exists(ini):
            continue
        cp = configparser.RawConfigParser(strict=False)
        try:
            cp.read(ini)
        except configparser.Error:
            continue

        known = {}
        for section in cp.sections():
            if not section.startswith("Profile"):
                continue
            try:
                path = cp.get(section, "Path")
                rel = cp.get(section, "IsRelative", fallback="1") == "1"
            except configparser.NoOptionError:
                continue
            full = os.path.join(root, path) if rel else path
            if os.path.isdir(full):
                known[full] = cp.get(section, "Default", fallback="0") == "1"

        if not known:
            continue

        # the install that actually launches first
        for section in cp.sections():
            if not section.startswith("Install"):
                continue
            name = cp.get(section, "Default", fallback="")
            for full in known:
                if os.path.basename(full).lower() == name.lower():
                    return full
        for full, is_default in known.items():
            if is_default:
                return full
        return next(iter(known))
    return None


def write_if_changed(path, text):
    try:
        with open(path, encoding="utf-8") as f:
            if f.read() == text:
                return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return True


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else ""
    if not path:
        try:
            with open(STATE) as f:
                path = f.read().strip()
        except OSError:
            path = ""
    if not path or not os.path.exists(path):
        path = DEFAULT_WALL

    p = analyze(path) if os.path.exists(path) else None
    if p is None:
        p = {"neutralH": 0, "neutralS": 0, "accentH": 0, "accentS": 0}

    c = palette(p)
    profile = find_profile()
    if not profile:
        return 0

    chrome = os.path.join(profile, "chrome")
    write_if_changed(os.path.join(chrome, "userChrome.css"), chrome_css(c))
    write_if_changed(os.path.join(chrome, "userContent.css"), content_css(c))

    user_js = os.path.join(profile, "user.js")
    merged = merge_user_js(user_js, prefs_js())
    write_if_changed(user_js, merged)
    return 0


if __name__ == "__main__":
    sys.exit(main())
