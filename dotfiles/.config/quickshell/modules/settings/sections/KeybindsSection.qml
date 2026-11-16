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
        title: "KEYBINDS"

        Controls.SettingInfo {
            width: parent.width
            label: "STATUS"
            value: {
                if (Keybinds.recordingId === "")
                    return "READY";
                if (Keybinds.mouseMode !== "")
                    return Keybinds.mouseMode === "scroll" ? "SCROLL TO SET // ESC CANCEL" : "CLICK TO SET // ESC CANCEL";
                return "PRESS A COMBINATION // ESC CANCEL";
            }
        }

        Controls.SettingInfo {
            width: parent.width
            label: "BINDS"
            value: Keybinds.catalog.length + " TOTAL"
        }

        Controls.SettingInfo {
            width: parent.width
            label: "OVERRIDES"
            value: Keybinds.overrideCount + " ACTIVE"
        }

        Controls.SettingInfo {
            width: parent.width
            label: "FILE"
            value: Keybinds.overridePath
        }

        RText {
            visible: Keybinds.error.length > 0
            width: parent.width
            text: Keybinds.error
            color: Theme.highlight
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.Wrap
        }

        RText {
            width: parent.width
            text: "CLICK A ROW, PRESS THE NEW COMBO. RESET RESTORES THE DEFAULT."
            color: Theme.textMuted
            font.pixelSize: Theme.fontExtraSmall
            wrapMode: Text.Wrap
        }

        Controls.SettingAction {
            width: parent.width
            visible: Keybinds.overrideCount > 0
            label: "RESET ALL KEYBINDS"
            hint: "RESET"
            danger: true
            onClicked: Keybinds.resetAll()
        }
    }

    Repeater {
        model: Keybinds.groups

        delegate: Controls.SettingSection {
            required property var modelData

            width: parent.width
            title: modelData.title

            Repeater {
                model: modelData.items

                delegate: Controls.SettingKeybind {
                    required property var modelData

                    width: parent.width
                    label: modelData.label
                    combo: {
                        const values = Settings.keybinds;
                        return Keybinds.comboFor(modelData.id, values);
                    }
                    overridden: {
                        const values = Settings.keybinds;
                        return Keybinds.isOverridden(modelData.id, values);
                    }
                    recording: Keybinds.recordingId === modelData.id
                    onClicked: Keybinds.startRecording(modelData.id)
                    onResetClicked: Keybinds.reset(modelData.id)
                }
            }
        }
    }
}
