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
        title: "AUTOMATIC LOCK"

        Controls.SettingToggle {
            width: parent.width
            label: "IDLE LOCK"
            description: "Lock the session after the timeout below."
            checked: Settings.lockEnabled
            onToggled: Settings.lockEnabled = !Settings.lockEnabled
        }

        Controls.SettingSlider {
            width: parent.width
            label: "IDLE TIMEOUT"
            value: Settings.lockTimeout
            from: 1
            to: 60
            step: 1
            suffix: " MIN"
            onMoved: v => Settings.lockTimeout = Math.round(v)
        }

        Controls.SettingToggle {
            width: parent.width
            label: "LOCK ON SLEEP"
            description: "Lock before suspend and when the laptop wakes."
            checked: Settings.lockOnSleep
            onToggled: Settings.lockOnSleep = !Settings.lockOnSleep
        }

        Controls.SettingInfo {
            width: parent.width
            label: "STATUS"
            value: Lock.locked ? "LOCKED" : (Settings.lockEnabled ? "ARMED // " + Settings.lockTimeout + " MIN" : "IDLE LOCK OFF")
        }

        Controls.SettingInfo {
            width: parent.width
            label: "SLEEP MONITOR"
            value: Lock.sleepWatcherActive ? "ACTIVE" : "RESTARTING"
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "SESSION"

        Controls.SettingAction {
            width: parent.width
            label: "LOCK NOW"
            hint: "LOCK"
            onClicked: {
                ShellState.settingsOpen = false;
                Lock.lock();
            }
        }

        Controls.SettingInfo {
            width: parent.width
            label: "SHORTCUT"
            value: "SUPER + SHIFT + L"
        }

        Controls.SettingInfo {
            width: parent.width
            label: "AUTHENTICATION"
            value: "PAM // LOGIN"
        }
    }
}
