pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services
import "controls" as Controls

// Centered settings panel: persistent bar configuration, audio, notifications,
// appearance, tools, and system information.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onFocused: {
        const fm = Hypr.focusedMonitor;
        return !!fm && fm.name === (Hypr.monitorFor(modelData)?.name ?? "");
    }
    readonly property bool showHere: ShellState.settingsOpen && onFocused

    readonly property int frameWidth: 900
    readonly property int frameHeight: 600

    // shrink only if the frame cannot fit this screen at full size
    readonly property real frameScale: Theme.fitScale(modelData.width, modelData.height, root.frameWidth, root.frameHeight)

    readonly property var sections: [{
            "id": "bar",
            "label": "BAR"
        }, {
            "id": "appearance",
            "label": "APPEARANCE"
        }, {
            "id": "audio",
            "label": "AUDIO"
        }, {
            "id": "notifs",
            "label": "NOTIFICATIONS"
        }, {
            "id": "lock",
            "label": "LOCK SCREEN"
        }, {
            "id": "keybinds",
            "label": "KEYBINDS"
        }, {
            "id": "system",
            "label": "SYSTEM"
        }, {
            "id": "about",
            "label": "ABOUT"
        }]

    property string tab: "bar"

    readonly property string sectionSource: {
        switch (tab) {
        case "appearance":
            return "sections/AppearanceSection.qml";
        case "audio":
            return "sections/AudioSection.qml";
        case "notifs":
            return "sections/NotifsSection.qml";
        case "lock":
            return "sections/LockSection.qml";
        case "keybinds":
            return "sections/KeybindsSection.qml";
        case "system":
            return "sections/SystemSection.qml";
        case "about":
            return "sections/AboutSection.qml";
        default:
            return "sections/BarSection.qml";
        }
    }

    function close(): void {
        if (Keybinds.recordingId !== "")
            Keybinds.cancelRecording();
        ShellState.settingsOpen = false;
    }

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
    color: "#b0050505"
    focusable: showHere

    WlrLayershell.layer: WlrLayer.Overlay

    MouseArea {
        anchors.fill: parent

        onClicked: root.close()
    }

    Box {
        id: frame

        anchors.centerIn: parent
        width: root.frameWidth
        height: root.frameHeight
        // transformOrigin defaults to Item.Center, so the scaled frame stays centered
        scale: root.frameScale
        title: "SETTINGS"
        focus: root.showHere

        Keys.onPressed: event => {
            if (Keybinds.recordingId !== "") {
                if (event.key === Qt.Key_Escape) {
                    Keybinds.cancelRecording();
                    event.accepted = true;
                    return;
                }
                if (Keybinds.capture(event.key, event.modifiers))
                    event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            spacing: 10

            Item {
                Layout.preferredWidth: 180
                Layout.fillHeight: true

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 4

                    RText {
                        width: parent.width
                        text: "SECTIONS"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontExtraSmall + 2
                    }

                    Repeater {
                        model: root.sections

                        delegate: Controls.SettingAction {
                            required property var modelData

                            width: parent.width
                            label: modelData.label
                            active: root.tab === modelData.id
                            onClicked: root.tab = modelData.id
                        }
                    }
                }

                RText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: "ESC CLOSE"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontExtraSmall + 2
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Theme.border
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: flick

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: sectionColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: sectionColumn

                        width: flick.width
                        spacing: 12

                        Loader {
                            id: loader

                            width: parent.width
                            height: item ? item.implicitHeight : 0
                            source: Qt.resolvedUrl(root.sectionSource)
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: Keybinds.mouseMode !== ""
            z: 50
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => Keybinds.mouseClicked(mouse.button)
            onWheel: wheel => Keybinds.mouseWheel(wheel.angleDelta.y)
        }

        Rectangle {
            visible: Keybinds.mouseMode !== ""
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            z: 51
            width: mouseHint.width + 16
            height: mouseHint.height + 6
            color: Theme.highlight

            RText {
                id: mouseHint

                anchors.centerIn: parent
                text: "CLICK / SCROLL TO ASSIGN // ESC CANCEL"
                color: Theme.bg
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    onTabChanged: {
        if (Keybinds.recordingId !== "")
            Keybinds.cancelRecording();
        flick.contentY = 0;
    }

    onShowHereChanged: {
        if (showHere) {
            flick.contentY = 0;
            frame.forceActiveFocus();
        } else if (Keybinds.recordingId !== "") {
            Keybinds.cancelRecording();
        }
    }
}
