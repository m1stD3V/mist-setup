pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Dropdown application search for the bar's search field. Reuses the
// program executor's app index and ranking.
PanelWindow {
    id: popupRoot

    required property PanelWindow barWindow
    property bool open: false

    property string query: ""
    property var results: []
    property int selectedIndex: 0
    property string hoveredFile: ""

    readonly property bool packageMode: Launcher.isPackageMode(query)
    readonly property bool fileMode: Launcher.isFileMode(query)
    readonly property string fileQuery: Launcher.fileQueryOf(query)

    readonly property int boxWidth: fileMode ? 620 : Theme.popupWidth
    readonly property int previewWidth: 280
    readonly property int boxHeight: 340
    property real boxX: Theme.spacingSm
    property real boxY: Theme.barHeight + Theme.spacingXs

    function reposition(): void {
        const screenW = barWindow.screen?.width ?? 0;
        boxX = Math.max(Theme.spacingSm, Math.min(screenW - boxWidth - Theme.spacingSm, Theme.spacingSm));
        boxY = Theme.barHeight + Theme.spacingXs;
    }

    function refreshResults(): void {
        results = Launcher.searchResults(query);
        hoveredFile = "";
        if (selectedIndex >= results.length)
            selectedIndex = Math.max(0, results.length - 1);
    }

    function refresh(): void {
        refreshResults();
        selectedIndex = 0;
        list.positionViewAtBeginning();
        if (fileMode)
            FileSearch.search(fileQuery);
    }

    onFileModeChanged: reposition()

    function moveSelection(delta: int): void {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        const item = results[selectedIndex];
        hoveredFile = item && item.kind === "file" ? item.path : "";
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function ensureVisible(): void {
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function confirm(): void {
        const item = results[selectedIndex];
        if (!item)
            return;
        Launcher.execute(item);
        open = false;
    }

    function closePopup(): void {
        open = false;
    }

    visible: open
    screen: barWindow.screen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "transparent"
    focusable: open

    WlrLayershell.layer: WlrLayer.Overlay

    Shortcut {
        sequences: ["Escape"]

        onActivated: popupRoot.open = false
    }

    onVisibleChanged: {
        if (visible) {
            reposition();
            refresh();
            searchInput.forceActiveFocus();
        } else {
            query = "";
            results = [];
            hoveredFile = "";
            searchInput.text = "";
        }
    }

    Connections {
        function onResultsChanged() {
            popupRoot.refreshResults();
        }

        target: FileSearch
    }

    // click outside the search box dismisses the dropdown
    MouseArea {
        anchors.fill: parent

        onClicked: popupRoot.open = false
    }

    Box {
        x: popupRoot.boxX
        y: popupRoot.boxY
        width: popupRoot.boxWidth
        height: popupRoot.boxHeight
        title: popupRoot.packageMode ? "PACKAGE INSTALLER" : (popupRoot.fileMode ? "FILE SEARCH" : "SEARCH")

        Column {
            anchors.fill: parent
            spacing: 6

            Rectangle {
                width: parent.width
                height: 30
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.family
                    font.pixelSize: Theme.fontMedium
                    cursorVisible: true
                    clip: true
                    focus: popupRoot.open
                    onTextEdited: {
                        popupRoot.query = text;
                        popupRoot.hoveredFile = "";
                        popupRoot.refresh();
                    }
                    onAccepted: popupRoot.confirm()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            popupRoot.open = false;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            popupRoot.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            popupRoot.moveSelection(-1);
                            event.accepted = true;
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: parent.height - 36
                spacing: 4

                Item {
                    width: parent.width - (preview.visible ? popupRoot.previewWidth + 4 : 0)
                    height: parent.height
                    clip: true

                    ListView {
                        id: list

                        anchors.fill: parent
                        spacing: 1
                        model: popupRoot.results
                        clip: true
                        interactive: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: entry

                            required property var modelData
                            required property int index

                            width: list.width
                            height: 27
                            color: index === popupRoot.selectedIndex ? Theme.inverseBg : (mouse.hovered ? Theme.surfaceHigh : "transparent")

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                spacing: 12

                                RText {
                                    width: 180
                                    text: entry.modelData.label.toUpperCase()
                                    font.pixelSize: Theme.fontSmall + 2
                                    color: entry.index === popupRoot.selectedIndex ? Theme.inverseText : Theme.text
                                    elide: Text.ElideRight
                                }

                                RText {
                                    width: Math.max(40, entry.width - 208)
                                    text: (entry.modelData.subtitle ?? "").toUpperCase()
                                    font.pixelSize: Theme.fontSmall
                                    color: entry.index === popupRoot.selectedIndex ? Theme.inverseText : Theme.textDim
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler {
                                id: mouse

                                onHoveredChanged: {
                                    if (hovered)
                                        popupRoot.hoveredFile = entry.modelData.kind === "file" ? entry.modelData.path : "";
                                    else if (popupRoot.hoveredFile === entry.modelData.path)
                                        popupRoot.hoveredFile = "";
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    popupRoot.selectedIndex = entry.index;
                                    popupRoot.ensureVisible();
                                    popupRoot.confirm();
                                }
                            }
                        }
                    }

                    RText {
                        visible: popupRoot.results.length === 0
                        anchors.centerIn: parent
                        text: "NO RESULTS"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                    }
                }

                FilePreviewPane {
                    id: preview

                    width: popupRoot.previewWidth
                    height: parent.height
                    visible: popupRoot.fileMode && popupRoot.hoveredFile.length > 0
                    path: popupRoot.hoveredFile
                }
            }
        }
    }
}
