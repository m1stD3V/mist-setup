pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onFocused: {
        const fm = Hypr.focusedMonitor;
        return !!fm && fm.name === (Hypr.monitorFor(modelData)?.name ?? "");
    }

    readonly property bool showHere: ShellState.launcherOpen && onFocused

    property string hoveredFile: ""
    readonly property int previewWidth: 280

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
    focusable: ShellState.launcherOpen

    WlrLayershell.layer: WlrLayer.Overlay

    // dim backdrop: click to dismiss
    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.launcherOpen = false
    }

    Box {
        id: frame

        anchors.centerIn: parent
        width: 660
        height: 440
        title: Launcher.packageMode ? "PACKAGE INSTALLER" : (Launcher.fileMode ? "FILE SEARCH" : "PROGRAM EXECUTOR")

        // prompt row
        Item {
            x: 10
            y: 4
            width: parent.width - 20
            height: 30

            Row {
                id: promptRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                RText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Launcher.packageMode ? "INSTALL>" : (Launcher.fileMode ? "FILE>" : "C:\\MIST>")
                    color: Theme.textHigh
                    font.pixelSize: Theme.fontMedium
                }

                TextInput {
                    id: input

                    anchors.verticalCenter: parent.verticalCenter
                    width: 480
                    color: Theme.text
                    font.family: Theme.family
                    font.pixelSize: Theme.fontMedium
                    cursorVisible: true
                    clip: true
                    onTextEdited: Launcher.query = text
                    onAccepted: Launcher.confirm()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            ShellState.launcherOpen = false;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            Launcher.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            Launcher.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            Launcher.moveSelection(1);
                            event.accepted = true;
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.cursorRectangle.x
                        width: 10
                        height: parent.cursorRectangle.height + 2
                        color: Theme.textHigh
                        visible: parent.cursorVisible && parent.activeFocus && Theme.blink && parent.text.length > 0
                    }
                }
            }
        }

        // separator line
        Rectangle {
            x: 9
            y: 42
            width: parent.width - 18
            height: 1
            color: Theme.borderHigh
        }

        // results: DOS dir listing style (clipped so rows never reach the footer)
        Row {
            x: 10
            y: 52
            width: parent.width - 20
            height: parent.height - 74
            spacing: 4

            Item {
                width: parent.width - (preview.visible ? root.previewWidth + 4 : 0)
                height: parent.height
                clip: true

                ListView {
                    id: list

                    anchors.fill: parent
                    clip: true
                    spacing: 1
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Launcher.results

                    delegate: Rectangle {
                        id: entry

                        required property var modelData
                        required property int index

                        readonly property bool selected: index === Launcher.selectedIndex

                        width: list.width
                        height: 27
                        color: selected ? Theme.inverseBg : (mouse.hovered ? Theme.surfaceHigh : "transparent")

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            spacing: 12

                            RText {
                                width: 220
                                text: entry.modelData.label.toUpperCase()
                                font.pixelSize: Theme.fontSmall + 2
                                color: entry.selected ? Theme.inverseText : (entry.modelData.kind === "pkg" && entry.modelData.installed ? Theme.textDim : Theme.text)
                                elide: Text.ElideRight
                            }

                            RText {
                                width: entry.width - 248
                                text: (entry.modelData.subtitle ?? "").toUpperCase()
                                font.pixelSize: Theme.fontSmall
                                color: entry.selected ? Theme.inverseText : Theme.textDim
                                elide: Text.ElideRight
                            }
                        }

                        HoverHandler {
                            id: mouse

                            onHoveredChanged: {
                                if (hovered)
                                    root.hoveredFile = entry.modelData.kind === "file" ? entry.modelData.path : "";
                                else if (root.hoveredFile === entry.modelData.path)
                                    root.hoveredFile = "";
                            }
                        }

                        TapHandler {
                            onTapped: {
                                Launcher.selectedIndex = entry.index;
                                Launcher.confirm();
                            }
                        }
                    }
                }

                RText {
                    visible: Launcher.results.length === 0
                    anchors.centerIn: parent
                    text: "NO RESULTS"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
            }

            FilePreviewPane {
                id: preview

                width: root.previewWidth
                height: parent.height
                visible: Launcher.fileMode && root.hoveredFile.length > 0
                path: root.hoveredFile
            }
        }

        // footer hint, pinned to the bottom of the box below the list area
        RText {
            x: 10
            y: parent.height - 16
            text: Launcher.packageMode ? "ENTER OPEN PACSEEK  ·  ESC CLOSE" : (Launcher.fileMode ? "ENTER OPEN FILE  ·  ESC CLOSE" : "UP/DOWN SELECT  ENTER RUN  ·  INSTALL <PKG> FOR PACKAGES  ·  FILE <NAME> FOR FILES  ·  ESC CLOSE")
            color: Theme.textMuted
            font.pixelSize: Theme.fontExtraSmall
        }
    }

    // focus the input whenever the launcher opens
    onShowHereChanged: {
        if (showHere) {
            input.text = Launcher.query;
            input.forceActiveFocus();
        } else {
            input.focus = false;
            hoveredFile = "";
        }
    }

    Component.onCompleted: {
        if (showHere)
            input.forceActiveFocus();
    }

    Connections {
        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen) {
                input.text = "";
                input.forceActiveFocus();
            }
        }

        target: ShellState
    }

    Connections {
        function onSelectedIndexChanged() {
            list.positionViewAtIndex(Launcher.selectedIndex, ListView.Contain);
            const item = Launcher.results[Launcher.selectedIndex];
            root.hoveredFile = item && item.kind === "file" ? item.path : "";
        }

        function onQueryChanged() {
            root.hoveredFile = "";
        }

        target: Launcher
    }
}
