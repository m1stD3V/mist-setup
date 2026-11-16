pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen capture helpers: region/full screenshots saved to
// ~/Pictures/Screenshots and copied to the clipboard, plus OCR of a
// selected region into the clipboard. External tools do the work:
// grim, slurp, wl-copy and (for OCR) tesseract.
Singleton {
    id: root

    readonly property string shotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    // slurp styling matched to the shell: dimmed backdrop, pink border
    readonly property string slurpArgs: "-d -b 00000060 -c f72585ff -s f72585aa -w 2"

    property bool busy: false

    function region(): void {
        run(commonPrelude() + "geom=$(timeout 60 slurp " + slurpArgs + " < /dev/null) || exit 0\n"
            + "[ -z \"$geom\" ] && exit 0\n"
            + captureScript());
    }

    function full(): void {
        run(commonPrelude() + "grim \"$file\" || { notify-send -u critical \"Screenshot\" \"Capture failed\"; exit 1; }\n"
            + "wl-copy --type image/png < \"$file\" || exit 1\n"
            + "notify-send -i \"$file\" \"Screenshot saved\" \"$(basename \"$file\") · copied to clipboard\"\n");
    }

    function ocr(): void {
        run("if ! command -v tesseract >/dev/null 2>&1; then\n"
            + "  notify-send -u critical \"Text capture\" \"tesseract is not installed (pacman -S tesseract)\"\n"
            + "  exit 1\n"
            + "fi\n"
            + commonPrelude()
            + "geom=$(timeout 60 slurp " + slurpArgs + " < /dev/null) || exit 0\n"
            + "[ -z \"$geom\" ] && exit 0\n"
            + "text=$(grim -g \"$geom\" - | tesseract - - -l eng 2>/dev/null)\n"
            + "if [ -z \"$(printf '%s' \"$text\" | tr -d '[:space:]')\" ]; then\n"
            + "  notify-send \"Text capture\" \"No text found in the selection\"\n"
            + "  exit 0\n"
            + "fi\n"
            + "printf '%s' \"$text\" | wl-copy\n"
            + "notify-send \"Text captured\" \"$(printf '%s' \"$text\" | head -n 1 | cut -c1-70) · copied to clipboard\"\n");
    }

    // Shared setup: target directory and a unique timestamped file name.
    function commonPrelude(): string {
        return "dir=\"" + shotDir + "\"\n"
            + "mkdir -p \"$dir\" || { notify-send -u critical \"Screenshot\" \"Cannot create $dir\"; exit 1; }\n"
            + "file=\"$dir/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png\"\n";
    }

    function captureScript(): string {
        return "grim -g \"$geom\" \"$file\" || { notify-send -u critical \"Screenshot\" \"Capture failed\"; exit 1; }\n"
            + "wl-copy --type image/png < \"$file\" || exit 1\n"
            + "notify-send -i \"$file\" \"Screenshot saved\" \"$(basename \"$file\") · copied to clipboard\"\n";
    }

    function run(script: string): void {
        if (proc.running)
            return;
        busy = true;
        proc.command = ["sh", "-c", script];
        proc.running = true;
    }

    Process {
        id: proc

        onExited: root.busy = false
    }
}
