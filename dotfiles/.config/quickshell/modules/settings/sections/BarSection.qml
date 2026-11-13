import QtQuick
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
        title: "BAR STYLE"

        Controls.SettingSlider {
            width: parent.width
            label: "HEIGHT"
            value: Settings.barHeight
            from: 28
            to: 60
            step: 1
            suffix: "px"
            onMoved: v => Settings.barHeight = Math.round(v)
        }

        Controls.SettingSlider {
            width: parent.width
            label: "GLASS OPACITY"
            value: Settings.barOpacity
            from: 0.05
            to: 1
            step: 0.01
            displayScale: 100
            suffix: "%"
            onMoved: v => Settings.barOpacity = v
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "BAR MODULES"

        Controls.SettingToggle {
            width: parent.width
            label: "MENU"
            checked: Settings.showMenu
            onToggled: Settings.showMenu = !Settings.showMenu
        }

        Controls.SettingToggle {
            width: parent.width
            label: "SEARCH"
            checked: Settings.showSearch
            onToggled: Settings.showSearch = !Settings.showSearch
        }

        Controls.SettingToggle {
            width: parent.width
            label: "WORKSPACES"
            checked: Settings.showWorkspaces
            onToggled: Settings.showWorkspaces = !Settings.showWorkspaces
        }

        Controls.SettingToggle {
            width: parent.width
            label: "ACTIVE WINDOW"
            checked: Settings.showActiveWindow
            onToggled: Settings.showActiveWindow = !Settings.showActiveWindow
        }

        Controls.SettingToggle {
            width: parent.width
            label: "TRAY"
            checked: Settings.showTray
            onToggled: Settings.showTray = !Settings.showTray
        }

        Controls.SettingToggle {
            width: parent.width
            label: "BATTERY"
            checked: Settings.showBattery
            onToggled: Settings.showBattery = !Settings.showBattery
        }

        Controls.SettingToggle {
            width: parent.width
            label: "NOTIFICATIONS"
            checked: Settings.showNotifications
            onToggled: Settings.showNotifications = !Settings.showNotifications
        }

        Controls.SettingToggle {
            width: parent.width
            label: "DISCORD"
            checked: Settings.showDiscord
            onToggled: Settings.showDiscord = !Settings.showDiscord
        }

        Controls.SettingToggle {
            width: parent.width
            label: "VOLUME"
            checked: Settings.showVolume
            onToggled: Settings.showVolume = !Settings.showVolume
        }

        Controls.SettingToggle {
            width: parent.width
            label: "CLOCK"
            checked: Settings.showClock
            onToggled: Settings.showClock = !Settings.showClock
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "CLOCK"

        Controls.SettingToggle {
            width: parent.width
            label: "24-HOUR TIME"
            checked: Settings.clock24h
            onToggled: Settings.clock24h = !Settings.clock24h
        }

        Controls.SettingToggle {
            width: parent.width
            label: "SHOW SECONDS"
            checked: Settings.clockSeconds
            onToggled: Settings.clockSeconds = !Settings.clockSeconds
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "RESET"

        Controls.SettingAction {
            width: parent.width
            label: "RESTORE BAR DEFAULTS"
            hint: "RESET"
            onClicked: Settings.resetBar()
        }
    }
}
