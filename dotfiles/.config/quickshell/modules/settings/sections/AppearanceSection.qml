import QtQuick
import qs.Theme
import qs.components
import qs.services
import "../controls" as Controls

Column {
    id: root

    readonly property string wallpaperName: {
        const parts = Wallpapers.current.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : "NONE";
    }

    width: parent ? parent.width : 0
    spacing: 12

    Controls.SettingSection {
        width: parent.width
        title: "WALLPAPER"

        Controls.SettingInfo {
            width: parent.width
            label: "CURRENT"
            value: root.wallpaperName
        }

        Controls.SettingAction {
            width: parent.width
            label: "OPEN WALLPAPER PICKER"
            hint: "OPEN"
            onClicked: {
                ShellState.settingsOpen = false;
                ShellState.toggleWallpaper();
            }
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "THEME"

        Controls.SettingInfo {
            width: parent.width
            label: "ACCENT"
            value: String(Theme.accent).toUpperCase()
        }

        Controls.SettingInfo {
            width: parent.width
            label: "SURFACE"
            value: String(Theme.bg).toUpperCase()
        }

        Controls.SettingAction {
            width: parent.width
            label: "RETHEME FROM WALLPAPER"
            hint: "APPLY"
            onClicked: Wallpapers.sample(Wallpapers.current)
        }

        Controls.SettingAction {
            width: parent.width
            label: "RESTORE DEFAULT COLORS"
            hint: "RESET"
            onClicked: Theme.reset()
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "FILES"

        Controls.SettingInfo {
            width: parent.width
            label: "WALLPAPER DIRECTORY"
            value: Wallpapers.wallpaperDir
        }
    }
}
