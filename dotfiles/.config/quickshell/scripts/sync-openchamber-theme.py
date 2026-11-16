#!/usr/bin/env python3
"""Derive an OpenChamber theme from the wallpaper, mirroring qs Theme.retheme().

Writes ~/.config/openchamber/themes/openchamber-dark.json. The file uses the
built-in dark theme's id, so it shadows the stock theme in OpenChamber's theme
registry: the app keeps using "openchamber-dark" while the palette follows the
wallpaper. OpenChamber watches the themes folder and reloads custom themes on
change, so a running app updates without a restart.

Run by Wallpapers.qml whenever the wallpaper (and therefore the shell palette)
changes. The analysis and palette ladder are the same as sync-firefox-theme.py
and Theme.qml, so the shell, Firefox and OpenChamber stay in step.
"""

import colorsys
import json
import os
import subprocess
import sys
import tempfile

HOME = os.environ.get("HOME", os.path.expanduser("~"))
STATE = os.path.join(HOME, ".local/state/mist/wallpaper")
DEFAULT_WALL = os.path.join(HOME, ".config/wallpaper/THINK.png")
DATA_DIR = os.environ.get("OPENCHAMBER_DATA_DIR") or os.path.join(HOME, ".config/openchamber")
THEMES_DIR = os.path.join(DATA_DIR, "themes")
THEME_ID = "openchamber-dark"
THEME_PATH = os.path.join(THEMES_DIR, "openchamber-dark.json")

# Theme.highlight: the shell's fixed interactive pink. It is deliberately not
# rethemed from the wallpaper, so selected/primary surfaces match the bar.
HIGHLIGHT = (332.6, 0.929, 0.557)

# Semantic colours stay stable so error/warning/success keep their meaning.
STATUS = {
    "error": "#da5b4a",
    "warning": "#c67f13",
    "success": "#76ad4f",
    "info": "#479fe6",
}


def hsl(h, s, l):
    h = ((h % 360) + 360) % 360 / 360.0
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return (r, g, b)


def hexc(rgb):
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02x}" for c in rgb)


def hexa(rgb, alpha):
    return hexc(rgb) + f"{max(0, min(255, round(alpha * 255))):02x}"


def rgb(hex_value):
    value = hex_value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


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
    return {
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
        "accentHue": ah,
        "accentSat": a_s,
        "neutralHue": nh,
        "neutralSat": ns,
    }


def build_theme(c):
    nh = c["neutralHue"]
    ns = c["neutralSat"]
    ah = c["accentHue"]
    a_s = c["accentSat"]

    # Syntax colours get a saturation floor so code stays legible even when the
    # wallpaper has no vibrant colour; the hues still follow the wallpaper.
    def syn(hue_offset, lightness, sat_scale=0.9):
        return hsl(ah + hue_offset, max(0.40, a_s * sat_scale), lightness)

    keyword = syn(0, 0.66, 1.0)
    string = syn(35, 0.68)
    number = syn(-60, 0.64)
    function = syn(90, 0.68, 0.85)
    variable = syn(15, 0.64)
    type_ = syn(-120, 0.68, 0.80)
    operator = syn(-25, 0.64, 1.0)
    comment = hsl(nh, ns * 0.5, 0.50)
    punctuation = c["textMuted"]

    hl = hexc(hsl(*HIGHLIGHT))
    hl_hover = hexc(hsl(HIGHLIGHT[0], HIGHLIGHT[1], HIGHLIGHT[2] + 0.07))
    hl_active = hexc(hsl(HIGHLIGHT[0], HIGHLIGHT[1], HIGHLIGHT[2] + 0.14))

    status = {}
    for name, value in STATUS.items():
        base = rgb(value)
        status[name] = value
        status[name + "Foreground"] = hexc(c["inverseText"])
        status[name + "Background"] = hexa(base, 0.125)
        status[name + "Border"] = hexa(base, 0.31)

    return {
        "metadata": {
            "id": THEME_ID,
            "name": "Mist",
            "variant": "dark",
            "description": "The quickshell palette, rethemed from the current wallpaper",
            "version": "1.0.0",
            "author": "quickshell",
            "tags": ["dark", "wallpaper", "generated", "mist"],
        },
        "colors": {
            "primary": {
                "base": hl,
                "foreground": hexc(c["inverseText"]),
                "hover": hl_hover,
                "active": hl_active,
                "muted": hexa(hsl(*HIGHLIGHT), 0.5),
            },
            "surface": {
                "background": hexc(c["bg"]),
                "foreground": hexc(c["text"]),
                "muted": hexc(hsl(nh, ns, 0.035)),
                "mutedForeground": hexc(c["textDim"]),
                "elevated": hexc(c["surfaceHigh"]),
                "overlay": hexa(c["bg"], 0.5),
                "subtle": hexc(c["surface"]),
            },
            "interactive": {
                "border": hexc(c["border"]),
                "selection": hexa(hsl(*HIGHLIGHT), 0.17),
                "borderHover": hexc(c["borderHigh"]),
                "focus": hexa(hsl(*HIGHLIGHT), 0.0),
                "focusRing": hexa(hsl(*HIGHLIGHT), 0.33),
                "cursor": hexc(c["textHigh"]),
                "hover": hexa(hsl(*HIGHLIGHT), 0.07),
                "active": hexa(hsl(*HIGHLIGHT), 0.13),
            },
            "status": status,
            "syntax": {
                "base": {
                    "background": hexc(hsl(nh, ns, 0.035)),
                    "comment": hexc(comment),
                    "keyword": hexc(keyword),
                    "string": hexc(string),
                    "number": hexc(number),
                    "function": hexc(function),
                    "variable": hexc(variable),
                    "type": hexc(type_),
                    "operator": hexc(operator),
                },
                "tokens": {
                    "commentDoc": hexc(comment),
                    "stringEscape": hexc(c["textHigh"]),
                    "keywordImport": hexc(keyword),
                    "storageModifier": hexc(type_),
                    "method": hexc(function),
                    "variableProperty": hexc(number),
                    "variableOther": hexc(function),
                    "variableGlobal": hexc(variable),
                    "variableLocal": hexc(c["text"]),
                    "className": hexc(type_),
                    "typeParameter": hexc(type_),
                    "boolean": hexc(number),
                    "constant": hexc(variable),
                    "jsxTag": hexc(string),
                    "tagAttribute": hexc(number),
                    "decorator": hexc(variable),
                    "label": hexc(variable),
                    "preprocessor": hexc(variable),
                    "url": hexc(c["accent"]),
                    "key": hexc(function),
                    "exception": hexc(operator),
                    "punctuation": hexc(punctuation),
                },
                "highlights": {
                    "diffAdded": STATUS["success"],
                    "diffRemoved": STATUS["error"],
                    "diffModified": STATUS["info"],
                    "diffModifiedBackground": hexa(rgb(STATUS["info"]), 0.125),
                },
            },
            "pr": {
                "open": STATUS["success"],
                "draft": hexc(c["textMuted"]),
                "blocked": STATUS["warning"],
                "merged": hexc(c["accent"]),
                "closed": STATUS["error"],
            },
            "chat": {
                "userMessageBackground": hexc(
                    hsl(ah, min(0.45, max(0.18, a_s * 0.4)), 0.18)
                ),
                "divider": hexc(c["border"]),
                "background": hexc(c["bg"]),
            },
            "markdown": {
                "link": hexc(c["accent"]),
                "linkHover": hexc(c["textHigh"]),
                "inlineCode": hexc(c["accent"]),
                "inlineCodeBackground": hexc(c["surface"]),
                "blockquote": hexc(c["textDim"]),
                "blockquoteBorder": hexc(c["border"]),
                "listMarker": hexa(c["accent"], 0.6),
                "bold": hexc(c["textHigh"]),
                "italic": hexc(c["text"]),
            },
            "tools": {
                "border": hexa(c["border"], 0.45),
                "icon": hexc(c["textDim"]),
                "title": hexc(c["textHigh"]),
                "description": hexc(c["textDim"]),
                "edit": {
                    "addedBackground": hexa(rgb(STATUS["success"]), 0.145),
                    "removedBackground": hexa(rgb(STATUS["error"]), 0.145),
                    "lineNumber": hexc(c["textDim"]),
                },
            },
        },
        "config": {
            "transitions": {
                "fast": "150ms ease",
                "normal": "250ms ease",
                "slow": "350ms ease",
            }
        },
    }


def write_if_changed(path, text):
    try:
        with open(path, encoding="utf-8") as f:
            if f.read() == text:
                return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".openchamber-theme-", dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return True


def main():
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        try:
            with open(STATE) as f:
                path = f.read().strip()
        except OSError:
            path = ""
    if not path:
        path = DEFAULT_WALL

    # A path the shell could not sample (missing or unreadable) means the
    # shell reset its palette; mirror that instead of using a different image.
    p = None
    if os.path.exists(path):
        try:
            p = analyze(path)
        except (OSError, subprocess.CalledProcessError, ValueError):
            p = None
    if p is None:
        p = {"neutralH": 0, "neutralS": 0, "accentH": 0, "accentS": 0}

    theme = build_theme(palette(p))
    write_if_changed(THEME_PATH, json.dumps(theme, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
