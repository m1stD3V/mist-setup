import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services
import "../controls" as Controls

Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 12

    Controls.SettingSection {
        width: parent.width
        title: "TOOLS"

        Controls.SettingAction {
            width: parent.width
            label: "SYSTEM MONITOR"
            hint: "OPEN"
            onClicked: {
                ShellState.settingsOpen = false;
                ShellState.openApps("performance");
            }
        }

        Controls.SettingAction {
            width: parent.width
            label: "CLIPBOARD HISTORY"
            hint: "OPEN"
            onClicked: {
                ShellState.settingsOpen = false;
                ShellState.toggleClipboard();
            }
        }

        Controls.SettingAction {
            width: parent.width
            label: "SCREENSHOT REGION"
            hint: "CAPTURE"
            onClicked: {
                ShellState.settingsOpen = false;
                Capture.region();
            }
        }

        Controls.SettingAction {
            width: parent.width
            label: "EXTRACT TEXT"
            hint: "OCR"
            onClicked: {
                ShellState.settingsOpen = false;
                Capture.ocr();
            }
        }

        Controls.SettingAction {
            width: parent.width
            label: "PACKAGE INSTALLER"
            hint: "OPEN"
            onClicked: {
                ShellState.settingsOpen = false;
                Launcher.openPacseek("");
            }
        }

        Controls.SettingAction {
            width: parent.width
            label: "WALLPAPERS"
            hint: "OPEN"
            onClicked: {
                ShellState.settingsOpen = false;
                ShellState.toggleWallpaper();
            }
        }

        Controls.SettingAction {
            width: parent.width
            label: "SESSION / POWER"
            hint: "OPEN"
            onClicked: {
                ShellState.settingsOpen = false;
                ShellState.toggleSession();
            }
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "HYPRLAND"

        Controls.SettingAction {
            width: parent.width
            label: "RELOAD CONFIGURATION"
            hint: "APPLY"
            onClicked: Quickshell.execDetached(["hyprctl", "reload"])
        }

        Controls.SettingAction {
            width: parent.width
            label: "OPEN CONFIG DIRECTORY"
            hint: "OPEN"
            onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.config/hypr"])
        }
    }
}
