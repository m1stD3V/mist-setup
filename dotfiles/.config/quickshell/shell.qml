//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme
import qs.services
import qs.modules.bar
import qs.modules.launcher
import qs.modules.osd
import qs.modules.notifs
import qs.modules.sysmon
import qs.modules.session
import qs.modules.lock
import qs.modules.wallpaper
import qs.modules.discord
import qs.modules.apps
import qs.modules.settings
import qs.modules.clipboard
import qs.modules.polkit

ShellRoot {
    id: root

    FontLoader {
        source: Quickshell.shellPath("assets/Tiny5.ttf")
    }

    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens

        Launcher {}
    }

    Variants {
        model: Quickshell.screens

        Osd {}
    }

    Variants {
        model: Quickshell.screens

        NotifPopups {}
    }

    Variants {
        model: Quickshell.screens

        Sysmon {}
    }

    Variants {
        model: Quickshell.screens

        Session {}
    }

    // session lock is one global object; it creates a surface per screen
    LockScreen {}

    Variants {
        model: Quickshell.screens

        WallpaperPicker {}
    }

    Variants {
        model: Quickshell.screens

        DiscordRing {}
    }

    Variants {
        model: Quickshell.screens

        Apps {}
    }

    Variants {
        model: Quickshell.screens

        SettingsPanel {}
    }

    Variants {
        model: Quickshell.screens

        ClipboardPicker {}
    }

    Variants {
        model: Quickshell.screens

        PolkitPrompt {}
    }

    IpcHandler {
        function toggleLauncher(): void {
            ShellState.toggleLauncher();
        }

        function toggleSysmon(): void {
            ShellState.toggleSysmon();
        }

        function toggleSession(): void {
            ShellState.toggleSession();
        }

        function toggleWallpaper(): void {
            ShellState.toggleWallpaper();
        }

        function toggleApps(): void {
            ShellState.toggleApps();
        }

        function toggleSettings(): void {
            ShellState.toggleSettings();
        }

        function toggleClipboard(): void {
            ShellState.toggleClipboard();
        }

        function screenshot(): void {
            Capture.region();
        }

        function screenshotFull(): void {
            Capture.full();
        }

        function captureText(): void {
            Capture.ocr();
        }

        function lock(): void {
            Lock.lock();
        }

        function brightness(): void {
            Brightness.show();
        }

        target: "mist"
    }
}
