pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Centered incoming-call prompt on the focused monitor.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onFocused: {
        const fm = Hypr.focusedMonitor;
        return !!fm && fm.name === (Hypr.monitorFor(modelData)?.name ?? "");
    }

    readonly property bool showHere: Discord.ringing && onFocused

    screen: modelData
    visible: showHere
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "#99000000"
    focusable: showHere

    WlrLayershell.layer: WlrLayer.Overlay

    Box {
        anchors.centerIn: parent
        width: 380
        height: 178
        title: "INCOMING CALL"
        borderColor: Theme.blink ? Theme.textHigh : Theme.borderHigh

        Column {
            anchors.fill: parent
            spacing: Theme.spacingSm

            Row {
                width: parent.width
                spacing: Theme.spacingMd

                DiscordAvatar {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 56
                    source: Discord.incoming?.avatar ?? ""
                    name: Discord.incoming?.fromName ?? ""
                }

                Column {
                    width: parent.width - 68
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    RText {
                        width: parent.width
                        text: (Discord.incoming?.fromName ?? "UNKNOWN").toUpperCase()
                        color: Theme.textHigh
                        font.pixelSize: Theme.fontMedium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    RText {
                        width: parent.width
                        text: {
                            const g = Discord.incoming?.guildName ?? "";
                            const n = Discord.incoming?.name ?? "";
                            return (g.length > 0 ? g + " / " : "") + n;
                        }
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    RText {
                        width: parent.width
                        text: "IS CALLING YOU"
                        color: Theme.blink ? Theme.textHigh : Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }

            Item {
                width: 1
                height: 4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingMd

                DiscordButton {
                    label: "ACCEPT"
                    onClicked: Discord.acceptCall()
                }

                DiscordButton {
                    label: "DECLINE"
                    danger: true
                    onClicked: Discord.declineCall()
                }
            }
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]

        onActivated: Discord.acceptCall()
    }

    Shortcut {
        sequences: ["Escape"]

        onActivated: Discord.declineCall()
    }
}
