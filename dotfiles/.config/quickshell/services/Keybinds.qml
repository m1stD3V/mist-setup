pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Hyprland keybinds exposed to the settings panel. The catalog is the one
// place that knows every bind's label, default combo and action. Changes are
// persisted in Settings.keybinds and written to a generated Lua override file
// that hyprland.lua loads after its own binds.
Singleton {
    id: root

    readonly property string overridePath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/keybinds.lua"

    readonly property var catalog: buildCatalog()

    // Groups are derived once from the catalog; the panel only needs the
    // order the binds are declared in.
    readonly property var groups: {
        const out = [];
        for (const item of catalog) {
            let group = null;
            for (const g of out) {
                if (g.title === item.group) {
                    group = g;
                    break;
                }
            }
            if (!group) {
                group = {
                    "title": item.group,
                    "items": []
                };
                out.push(group);
            }
            group.items.push(item);
        }
        return out;
    }

    readonly property int overrideCount: {
        const values = Settings.keybinds || {};
        return Object.keys(values).length;
    }

    // Id of the bind being recorded, or "" when idle.
    property string recordingId: ""
    // "" for keyboard, "click" or "scroll" for mouse recording.
    property string mouseMode: ""
    // Last validation message shown above the list.
    property string error: ""

    // Writes the generated file only when its content actually differs, then
    // reloads Hyprland. The comparison happens in the shell so it stays honest
    // when the file was changed or deleted outside the panel.
    Process {
        id: writer

        property bool pending: false

        command: ["sh", "-c", root.writeScript(root.buildFile())]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim();
                if (writer.pending) {
                    writer.pending = false;
                    Qt.callLater(root.writeFile);
                } else if (result === "CHANGED") {
                    root.apply();
                } else if (result !== "SAME") {
                    root.error = "COULD NOT WRITE " + root.overridePath;
                }
            }
        }
    }

    Component.onCompleted: root.sync()

    Connections {
        function onLoadedChanged(): void {
            if (Settings.loaded)
                root.sync();
        }

        target: Settings
    }

    function buildCatalog(): var {
        const list = [{
            "id": "terminal",
            "group": "SHELL",
            "label": "OPEN TERMINAL",
            "combo": "SUPER + RETURN",
            "action": "hl.dsp.exec_cmd(\"ghostty\")"
        }, {
            "id": "filemanager",
            "group": "SHELL",
            "label": "OPEN FILE MANAGER",
            "combo": "SUPER + E",
            "action": "hl.dsp.exec_cmd(\"dolphin\")"
        }, {
            "id": "launcher",
            "group": "SHELL",
            "label": "OPEN LAUNCHER",
            "combo": "SUPER + G",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist toggleLauncher\")"
        }, {
            "id": "sysmon",
            "group": "SHELL",
            "label": "OPEN SYSTEM MONITOR",
            "combo": "SUPER + M",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist toggleSysmon\")"
        }, {
            "id": "lock",
            "group": "SHELL",
            "label": "LOCK SESSION",
            "combo": "SUPER + SHIFT + L",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist lock\")"
        }, {
            "id": "apps",
            "group": "SHELL",
            "label": "OPEN APPS",
            "combo": "SUPER + SHIFT + Escape",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist toggleApps\")"
        }, {
            "id": "wallpaper",
            "group": "SHELL",
            "label": "OPEN WALLPAPER PICKER",
            "combo": "SUPER + W",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist toggleWallpaper\")"
        }, {
            "id": "clipboard",
            "group": "SHELL",
            "label": "CLIPBOARD HISTORY",
            "combo": "SUPER + CTRL + V",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist toggleClipboard\")"
        }, {
            "id": "screenshot",
            "group": "SHELL",
            "label": "SCREENSHOT REGION",
            "combo": "SUPER + CTRL + S",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist screenshot\")"
        }, {
            "id": "screenshot-print",
            "group": "SHELL",
            "label": "SCREENSHOT REGION (PRINT)",
            "combo": "Print",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist screenshot\")"
        }, {
            "id": "screenshot-full",
            "group": "SHELL",
            "label": "SCREENSHOT FULL",
            "combo": "SUPER + CTRL + SHIFT + S",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist screenshotFull\")"
        }, {
            "id": "screenshot-full-print",
            "group": "SHELL",
            "label": "SCREENSHOT FULL (PRINT)",
            "combo": "SUPER + SHIFT + Print",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist screenshotFull\")"
        }, {
            "id": "capture-text",
            "group": "SHELL",
            "label": "CAPTURE TEXT",
            "combo": "SUPER + CTRL + T",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist captureText\")"
        }, {
            "id": "capture-text-print",
            "group": "SHELL",
            "label": "CAPTURE TEXT (PRINT)",
            "combo": "SUPER + CTRL + Print",
            "action": "hl.dsp.exec_cmd(\"qs ipc call mist captureText\")"
        }, {
            "id": "close",
            "group": "WINDOWS",
            "label": "CLOSE WINDOW",
            "combo": "SUPER + Q",
            "action": "hl.dsp.window.close()"
        }, {
            "id": "float",
            "group": "WINDOWS",
            "label": "TOGGLE FLOATING",
            "combo": "SUPER + F",
            "action": "hl.dsp.window.float({ action = \"toggle\" })"
        }, {
            "id": "fullscreen",
            "group": "WINDOWS",
            "label": "MAXIMIZE",
            "combo": "SUPER + L",
            "action": "hl.dsp.window.fullscreen(1)"
        }, {
            "id": "pseudo",
            "group": "WINDOWS",
            "label": "PSEUDO TILE",
            "combo": "SUPER + P",
            "action": "hl.dsp.window.pseudo()"
        }, {
            "id": "split",
            "group": "WINDOWS",
            "label": "TOGGLE SPLIT",
            "combo": "SUPER + J",
            "action": "hl.dsp.layout(\"togglesplit\")"
        }, {
            "id": "special",
            "group": "WINDOWS",
            "label": "TOGGLE SCRATCHPAD",
            "combo": "SUPER + S",
            "action": "hl.dsp.workspace.toggle_special(\"magic\")"
        }, {
            "id": "special-move",
            "group": "WINDOWS",
            "label": "MOVE TO SCRATCHPAD",
            "combo": "SUPER + SHIFT + S",
            "action": "hl.dsp.window.move({ workspace = \"special:magic\" })"
        }, {
            "id": "focus-left",
            "group": "WINDOWS",
            "label": "FOCUS LEFT",
            "combo": "SUPER + left",
            "action": "hl.dsp.focus({ direction = \"left\" })"
        }, {
            "id": "focus-right",
            "group": "WINDOWS",
            "label": "FOCUS RIGHT",
            "combo": "SUPER + right",
            "action": "hl.dsp.focus({ direction = \"right\" })"
        }, {
            "id": "focus-up",
            "group": "WINDOWS",
            "label": "FOCUS UP",
            "combo": "SUPER + up",
            "action": "hl.dsp.focus({ direction = \"up\" })"
        }, {
            "id": "focus-down",
            "group": "WINDOWS",
            "label": "FOCUS DOWN",
            "combo": "SUPER + down",
            "action": "hl.dsp.focus({ direction = \"down\" })"
        }, {
            "id": "scroll-next",
            "group": "MOUSE",
            "label": "NEXT WORKSPACE",
            "combo": "SUPER + mouse_down",
            "action": "hl.dsp.focus({ workspace = \"e+1\" })",
            "mouse": "scroll"
        }, {
            "id": "scroll-prev",
            "group": "MOUSE",
            "label": "PREVIOUS WORKSPACE",
            "combo": "SUPER + mouse_up",
            "action": "hl.dsp.focus({ workspace = \"e-1\" })",
            "mouse": "scroll"
        }, {
            "id": "drag",
            "group": "MOUSE",
            "label": "DRAG WINDOW",
            "combo": "SUPER + mouse:272",
            "action": "hl.dsp.window.drag()",
            "mouse": "click"
        }, {
            "id": "resize",
            "group": "MOUSE",
            "label": "RESIZE WINDOW",
            "combo": "SUPER + mouse:273",
            "action": "hl.dsp.window.resize()",
            "mouse": "click"
        }, {
            "id": "volume-up",
            "group": "MEDIA",
            "label": "VOLUME UP",
            "combo": "XF86AudioRaiseVolume",
            "action": "hl.dsp.exec_cmd(\"qs ipc call audio increment\")",
            "locked": true,
            "repeating": true
        }, {
            "id": "volume-down",
            "group": "MEDIA",
            "label": "VOLUME DOWN",
            "combo": "XF86AudioLowerVolume",
            "action": "hl.dsp.exec_cmd(\"qs ipc call audio decrement\")",
            "locked": true,
            "repeating": true
        }, {
            "id": "volume-mute",
            "group": "MEDIA",
            "label": "MUTE AUDIO",
            "combo": "XF86AudioMute",
            "action": "hl.dsp.exec_cmd(\"qs ipc call audio mute\")",
            "locked": true,
            "repeating": true
        }, {
            "id": "mic-mute",
            "group": "MEDIA",
            "label": "MUTE MICROPHONE",
            "combo": "XF86AudioMicMute",
            "action": "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\")",
            "locked": true,
            "repeating": true
        }, {
            "id": "brightness-up",
            "group": "MEDIA",
            "label": "BRIGHTNESS UP",
            "combo": "XF86MonBrightnessUp",
            "action": "hl.dsp.exec_cmd(\"sh -c 'brightnessctl -e4 -n2 set 5%+ && qs ipc call mist brightness'\")",
            "locked": true,
            "repeating": true
        }, {
            "id": "brightness-down",
            "group": "MEDIA",
            "label": "BRIGHTNESS DOWN",
            "combo": "XF86MonBrightnessDown",
            "action": "hl.dsp.exec_cmd(\"sh -c 'brightnessctl -e4 -n2 set 5%- && qs ipc call mist brightness'\")",
            "locked": true,
            "repeating": true
        }, {
            "id": "media-next",
            "group": "MEDIA",
            "label": "MEDIA NEXT",
            "combo": "XF86AudioNext",
            "action": "hl.dsp.exec_cmd(\"playerctl next\")",
            "locked": true
        }, {
            "id": "media-pause",
            "group": "MEDIA",
            "label": "MEDIA PAUSE",
            "combo": "XF86AudioPause",
            "action": "hl.dsp.exec_cmd(\"playerctl play-pause\")",
            "locked": true
        }, {
            "id": "media-play",
            "group": "MEDIA",
            "label": "MEDIA PLAY",
            "combo": "XF86AudioPlay",
            "action": "hl.dsp.exec_cmd(\"playerctl play-pause\")",
            "locked": true
        }, {
            "id": "media-prev",
            "group": "MEDIA",
            "label": "MEDIA PREVIOUS",
            "combo": "XF86AudioPrev",
            "action": "hl.dsp.exec_cmd(\"playerctl previous\")",
            "locked": true
        }];

        for (let i = 1; i <= 10; i++) {
            const key = i % 10;
            list.push({
                "id": "ws-focus-" + i,
                "group": "WORKSPACES",
                "label": "WORKSPACE " + i,
                "combo": "SUPER + " + key,
                "action": "hl.dsp.focus({ workspace = " + i + " })"
            });
            list.push({
                "id": "ws-move-" + i,
                "group": "WORKSPACES",
                "label": "MOVE TO WORKSPACE " + i,
                "combo": "SUPER + SHIFT + " + key,
                "action": "hl.dsp.window.move({ workspace = " + i + " })"
            });
        }
        return list;
    }

    function catalogFor(id: string): var {
        for (const item of catalog) {
            if (item.id === id)
                return item;
        }
        return null;
    }

    function comboFor(id: string, values: var): string {
        const item = catalogFor(id);
        if (!item)
            return "";
        const map = values || Settings.keybinds || {};
        const override = map[id];
        return typeof override === "string" && override.length > 0 ? override : item.combo;
    }

    function isOverridden(id: string, values: var): bool {
        const map = values || Settings.keybinds || {};
        return typeof map[id] === "string" && map[id].length > 0;
    }

    function startRecording(id: string): void {
        const item = catalogFor(id);
        if (!item)
            return;
        if (recordingId !== "")
            stopRecording();
        error = "";
        recordingId = id;
        mouseMode = item.mouse || "";
        // Suspend every global bind for the whole capture, mouse included, so
        // scrolling or clicking does not also trigger SUPER + mouse binds.
        if (!Hypr.usingLua) {
            if (mouseMode === "") {
                error = "HYPRLAND LUA CONFIG REQUIRED";
                return;
            }
            return;
        }
        Hypr.dispatch("hl.dsp.submap(\"qs-capture\")");
    }

    function stopRecording(): void {
        if (recordingId !== "" && Hypr.usingLua)
            Hypr.dispatch("hl.dsp.submap(\"reset\")");
        recordingId = "";
        mouseMode = "";
    }

    function cancelRecording(): void {
        error = "";
        stopRecording();
    }

    function capture(key: int, modifiers: int): bool {
        if (recordingId === "" || mouseMode !== "")
            return false;
        const combo = comboForEvent(key, modifiers);
        if (combo === "") {
            if (isModifierKey(key))
                return false;
            error = "KEY NOT SUPPORTED";
            return true;
        }
        if (setCombo(recordingId, combo))
            stopRecording();
        return true;
    }

    function mouseClicked(button: int): void {
        if (recordingId === "" || mouseMode !== "click")
            return;
        let key = "mouse:272";
        if (button === Qt.RightButton)
            key = "mouse:273";
        else if (button === Qt.MiddleButton)
            key = "mouse:274";
        if (setCombo(recordingId, mouseCombo(key)))
            stopRecording();
    }

    function mouseWheel(delta: int): void {
        if (recordingId === "" || mouseMode !== "scroll")
            return;
        if (setCombo(recordingId, mouseCombo(delta > 0 ? "mouse_up" : "mouse_down")))
            stopRecording();
    }

    function mouseCombo(key: string): string {
        const current = comboFor(recordingId);
        const parts = current.split(" + ");
        if (parts.length <= 1)
            return key;
        return parts.slice(0, -1).join(" + ") + " + " + key;
    }

    function setCombo(id: string, combo: string): bool {
        const item = catalogFor(id);
        if (!item)
            return false;
        if (combo.length === 0) {
            error = "EMPTY SHORTCUT";
            return false;
        }
        for (const other of catalog) {
            if (other.id !== id && comboFor(other.id) === combo) {
                error = "ALREADY USED BY " + other.label;
                return false;
            }
        }
        const next = Object.assign({}, Settings.keybinds || {});
        if (combo === item.combo)
            delete next[id];
        else
            next[id] = combo;
        Settings.keybinds = next;
        Settings.save();
        error = "";
        writeFile();
        return true;
    }

    function reset(id: string): void {
        const values = Settings.keybinds || {};
        if (!(id in values))
            return;
        const next = Object.assign({}, values);
        delete next[id];
        Settings.keybinds = next;
        Settings.save();
        error = "";
        writeFile();
    }

    function resetAll(): void {
        if (overrideCount === 0)
            return;
        Settings.keybinds = {};
        Settings.save();
        error = "";
        writeFile();
    }

    function sync(): void {
        if (!Settings.loaded)
            return;
        writeFile();
    }

    function writeFile(): void {
        if (writer.running) {
            writer.pending = true;
            return;
        }
        writer.running = true;
    }

    // Single shell pass: create the directory, write the file when the content
    // changed, and report back so only real changes trigger a reload.
    function writeScript(next: string): string {
        const path = overridePath;
        const dir = path.slice(0, path.lastIndexOf("/"));
        const marker = "MIST_KEYBINDS_EOF";
        return "mkdir -p '" + dir + "'\n" +
            "new=$(cat <<'" + marker + "'\n" + next + marker + "\n)\n" +
            "if [ -f '" + path + "' ] && [ \"$(cat '" + path + "')\" = \"$new\" ]; then\n" +
            "  echo SAME\n" +
            "  exit 0\n" +
            "fi\n" +
            "printf '%s\\n' \"$new\" > '" + path + "'\n" +
            "echo CHANGED\n";
    }

    function apply(): void {
        Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
    }

    function buildFile(): string {
        const lines = ["-- Generated by the mist settings panel. Do not edit by hand.",
            "-- Change keybinds in SETTINGS -> KEYBINDS.", ""];
        const values = Settings.keybinds || {};
        for (const item of catalog) {
            const combo = values[item.id];
            if (typeof combo !== "string" || combo.length === 0 || combo === item.combo)
                continue;
            lines.push("hl.unbind(" + luaString(item.combo) + ")");
            lines.push("hl.bind(" + luaString(combo) + ", " + item.action + ", " + bindOptions(item) + ")");
        }
        lines.push("");
        return lines.join("\n");
    }

    function bindOptions(item: var): string {
        const parts = ["description = " + luaString(item.label)];
        if (item.locked)
            parts.unshift("locked = true");
        if (item.repeating)
            parts.unshift("repeating = true");
        if (item.mouse === "click")
            parts.unshift("mouse = true");
        return "{ " + parts.join(", ") + " }";
    }

    function luaString(value: string): string {
        return "\"" + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n") + "\"";
    }

    function isModifierKey(key: int): bool {
        return key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Control || key === Qt.Key_Shift || key === Qt.Key_Alt || key === Qt.Key_AltGr || key === Qt.Key_Meta || key === Qt.Key_CapsLock || key === Qt.Key_NumLock || key === Qt.Key_ScrollLock || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R;
    }

    function keyName(key: int): string {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
            return "F" + (key - Qt.Key_F1 + 1);

        switch (key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return "RETURN";
        case Qt.Key_Escape:
            return "Escape";
        case Qt.Key_Space:
            return "SPACE";
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            return "TAB";
        case Qt.Key_Backspace:
            return "BACKSPACE";
        case Qt.Key_Delete:
            return "DELETE";
        case Qt.Key_Insert:
            return "Insert";
        case Qt.Key_Home:
            return "Home";
        case Qt.Key_End:
            return "End";
        case Qt.Key_PageUp:
            return "Page_Up";
        case Qt.Key_PageDown:
            return "Page_Down";
        case Qt.Key_Left:
            return "left";
        case Qt.Key_Right:
            return "right";
        case Qt.Key_Up:
            return "up";
        case Qt.Key_Down:
            return "down";
        case Qt.Key_Print:
            return "Print";
        case Qt.Key_Pause:
            return "Pause";
        case Qt.Key_VolumeUp:
            return "XF86AudioRaiseVolume";
        case Qt.Key_VolumeDown:
            return "XF86AudioLowerVolume";
        case Qt.Key_VolumeMute:
            return "XF86AudioMute";
        case Qt.Key_MicMute:
            return "XF86AudioMicMute";
        case Qt.Key_MonBrightnessUp:
            return "XF86MonBrightnessUp";
        case Qt.Key_MonBrightnessDown:
            return "XF86MonBrightnessDown";
        case Qt.Key_MediaNext:
            return "XF86AudioNext";
        case Qt.Key_MediaPrevious:
            return "XF86AudioPrev";
        case Qt.Key_MediaPlay:
            return "XF86AudioPlay";
        case Qt.Key_MediaPause:
            return "XF86AudioPause";
        case Qt.Key_MediaTogglePlayPause:
            return "XF86AudioPlay";
        case Qt.Key_Minus:
            return "minus";
        case Qt.Key_Equal:
            return "equal";
        case Qt.Key_BracketLeft:
            return "bracketleft";
        case Qt.Key_BracketRight:
            return "bracketright";
        case Qt.Key_Backslash:
            return "backslash";
        case Qt.Key_Semicolon:
            return "semicolon";
        case Qt.Key_Apostrophe:
            return "apostrophe";
        case Qt.Key_Comma:
            return "comma";
        case Qt.Key_Period:
            return "period";
        case Qt.Key_Slash:
            return "slash";
        case Qt.Key_QuoteLeft:
            return "grave";
        case Qt.Key_Menu:
            return "Menu";
        default:
            return "";
        }
    }

    function comboForEvent(key: int, modifiers: int): string {
        const name = keyName(key);
        if (name === "")
            return "";
        const mods = [];
        if (modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        if (modifiers & Qt.AltModifier)
            mods.push("ALT");
        return mods.length > 0 ? mods.join(" + ") + " + " + name : name;
    }
}
