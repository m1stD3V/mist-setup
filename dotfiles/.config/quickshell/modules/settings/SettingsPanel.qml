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

    // frame is designed for a 1920x1080 logical desktop; shrink proportionally
    // on smaller screens so the window always fits
    readonly property real frameScale: Math.min(1, Math.min(modelData.width / 1920, modelData.height / 1080))

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
        case "system":
            return "sections/SystemSection.qml";
        case "about":
            return "sections/AboutSection.qml";
        default:
            return "sections/BarSection.qml";
        }
    }

    function close(): void {
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
        width: 860
        height: 580
        // transformOrigin defaults to Item.Center, so the scaled frame stays centered
        scale: root.frameScale
        title: "SETTINGS"
        focus: root.showHere

        Keys.onPressed: event => {
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
                Layout.preferredWidth: 150
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
                        font.pixelSize: Theme.fontExtraSmall
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
                    font.pixelSize: Theme.fontExtraSmall
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
    }

    onTabChanged: flick.contentY = 0

    onShowHereChanged: {
        if (showHere) {
            flick.contentY = 0;
            frame.forceActiveFocus();
        }
    }
}
