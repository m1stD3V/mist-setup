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
        title: "MASTER OUTPUT"

        Controls.SettingSlider {
            width: parent.width
            label: "VOLUME"
            value: Audio.muted ? 0 : Audio.volume
            from: 0
            to: 1
            step: 0.01
            displayScale: 100
            suffix: "%"
            onMoved: v => Audio.setVolume(v)
        }

        Controls.SettingToggle {
            width: parent.width
            label: "MUTE"
            checked: Audio.muted
            onToggled: Audio.toggleMuted()
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "OUTPUT DEVICES"

        Controls.SettingInfo {
            visible: Audio.sinks.length === 0
            width: parent.width
            label: "STATUS"
            value: "NO OUTPUT DEVICES"
        }

        Repeater {
            model: Audio.sinks

            delegate: Column {
                id: sinkBlock

                required property var modelData

                width: parent.width
                spacing: 2

                Controls.SettingSlider {
                    width: parent.width
                    label: Audio.sinkLabel(sinkBlock.modelData)
                    value: sinkBlock.modelData?.audio?.volume ?? 0
                    from: 0
                    to: 1
                    step: 0.01
                    displayScale: 100
                    suffix: "%"
                    onMoved: v => Audio.setSinkVolume(sinkBlock.modelData, v)
                }

                Controls.SettingToggle {
                    width: parent.width
                    label: "MUTE"
                    checked: sinkBlock.modelData?.audio?.muted ?? false
                    onToggled: Audio.toggleSinkMuted(sinkBlock.modelData)
                }
            }
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "APPLICATIONS"

        Controls.SettingInfo {
            visible: Audio.streams.length === 0
            width: parent.width
            label: "STATUS"
            value: "NO ACTIVE STREAMS"
        }

        Repeater {
            model: Audio.streams

            delegate: Column {
                id: streamBlock

                required property var modelData

                width: parent.width
                spacing: 2

                Controls.SettingSlider {
                    width: parent.width
                    label: Audio.streamLabel(streamBlock.modelData)
                    value: streamBlock.modelData?.audio?.volume ?? 0
                    from: 0
                    to: 1
                    step: 0.01
                    displayScale: 100
                    suffix: "%"
                    onMoved: v => Audio.setStreamVolume(streamBlock.modelData, v)
                }

                Controls.SettingToggle {
                    width: parent.width
                    label: "MUTE"
                    checked: streamBlock.modelData?.audio?.muted ?? false
                    onToggled: Audio.toggleNodeMuted(streamBlock.modelData)
                }
            }
        }
    }
}
