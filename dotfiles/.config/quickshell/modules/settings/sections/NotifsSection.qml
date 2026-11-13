pragma ComponentBehavior: Bound

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
        title: "BEHAVIOR"

        Controls.SettingToggle {
            width: parent.width
            label: "DO NOT DISTURB"
            description: "Suppress notification popups while keeping history."
            checked: Settings.dnd
            onToggled: Settings.dnd = !Settings.dnd
        }

        Controls.SettingInfo {
            width: parent.width
            label: "UNREAD"
            value: String(Notifs.unread)
        }

        Controls.SettingAction {
            width: parent.width
            label: "MARK ALL AS READ"
            hint: "CLEAR"
            onClicked: Notifs.clearUnread()
        }

        Controls.SettingAction {
            width: parent.width
            label: "CLEAR NOTIFICATION HISTORY"
            hint: "CLEAR"
            onClicked: Notifs.clearHistory()
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "RECENT"

        Controls.SettingInfo {
            visible: Notifs.history.length === 0
            width: parent.width
            label: "STATUS"
            value: "NO NOTIFICATIONS"
        }

        Repeater {
            model: Notifs.history

            delegate: Controls.SettingInfo {
                id: historyRow

                required property var modelData

                width: parent.width
                label: modelData.app + "  " + modelData.time
                value: modelData.summary
            }
        }
    }
}
