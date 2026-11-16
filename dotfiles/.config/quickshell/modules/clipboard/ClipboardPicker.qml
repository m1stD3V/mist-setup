pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Clipboard history picker: a centred overlay over the focused monitor,
// backed by cliphist. Text entries and images share one list; the selected
// entry is previewed on the right and Enter puts it back on the clipboard.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onFocused: {
        const fm = Hypr.focusedMonitor;
        return !!fm && fm.name === (Hypr.monitorFor(modelData)?.name ?? "");
    }

    readonly property bool showHere: ShellState.clipboardOpen && onFocused

    property string search: ""
    property int selectedIndex: 0

    readonly property int previewWidth: 236

    readonly property var filtered: {
        const q = search.trim().toLowerCase();
        if (q.length === 0)
            return Clipboard.entries;
        return Clipboard.entries.filter(e => e.preview.toLowerCase().includes(q));
    }

    readonly property var selectedEntry: {
        if (filtered.length === 0)
            return null;
        return filtered[Math.max(0, Math.min(root.selectedIndex, filtered.length - 1))];
    }

    readonly property int frameWidth: 680
    readonly property int frameHeight: 460

    // shrink only if the frame cannot fit this screen at full size
    readonly property real frameScale: Theme.fitScale(modelData.width, modelData.height, root.frameWidth, root.frameHeight)

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
    focusable: ShellState.clipboardOpen

    WlrLayershell.layer: WlrLayer.Overlay

    // dim backdrop: click to dismiss
    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.clipboardOpen = false
    }

    function close(): void {
        ShellState.clipboardOpen = false;
    }

    function copySelected(): void {
        if (!selectedEntry)
            return;
        Clipboard.copy(selectedEntry);
        close();
    }

    function removeSelected(): void {
        if (!selectedEntry)
            return;
        Clipboard.remove(selectedEntry);
        if (selectedIndex >= filtered.length - 1)
            selectedIndex = Math.max(0, filtered.length - 2);
    }

    function moveSelection(delta: int): void {
        if (filtered.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(filtered.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    onSearchChanged: {
        if (selectedIndex >= filtered.length)
            selectedIndex = Math.max(0, filtered.length - 1);
    }

    onSelectedEntryChanged: {
        if (showHere)
            Clipboard.previewImage(selectedEntry);
    }

    Box {
        id: frame

        anchors.centerIn: parent
        width: root.frameWidth
        height: root.frameHeight
        scale: root.frameScale
        title: "CLIPBOARD HISTORY"

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
                    text: "CLIP>"
                    color: Theme.textHigh
                    font.pixelSize: Theme.fontMedium
                }

                TextInput {
                    id: input

                    anchors.verticalCenter: parent.verticalCenter
                    width: 500
                    color: Theme.text
                    font.family: Theme.family
                    font.pixelSize: Theme.fontMedium
                    cursorVisible: true
                    clip: true
                    onTextEdited: root.search = text
                    onAccepted: root.copySelected()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.close();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            if (event.modifiers & Qt.ControlModifier)
                                Clipboard.wipe();
                            else
                                root.removeSelected();
                            event.accepted = true;
                        }
                    }

                    RText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.cursorRectangle.x
                        width: 10
                        height: parent.cursorRectangle.height + 2
                        color: Theme.textHigh
                        visible: parent.cursorVisible && parent.activeFocus && Theme.blink
                    }
                }
            }
        }

        Rectangle {
            x: 9
            y: 42
            width: parent.width - 18
            height: 1
            color: Theme.borderHigh
        }

        Row {
            x: 10
            y: 52
            width: parent.width - 20
            height: parent.height - 74
            spacing: 6

            Item {
                width: parent.width - root.previewWidth - parent.spacing
                height: parent.height
                clip: true

                ListView {
                    id: list

                    anchors.fill: parent
                    clip: true
                    spacing: 1
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filtered

                    delegate: Rectangle {
                        id: entry

                        required property var modelData
                        required property int index

                        readonly property bool selected: index === root.selectedIndex

                        width: list.width
                        height: 27
                        color: selected ? Theme.highlight : (mouse.hovered ? Theme.surfaceHigh : "transparent")

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            spacing: 10

                            RText {
                                width: 26
                                text: ("00" + entry.modelData.id).slice(-3)
                                color: entry.selected ? Theme.inverseText : Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall + 2
                            }

                            RText {
                                width: entry.width - 52
                                text: entry.modelData.image ? "IMG  " + entry.modelData.preview.toUpperCase() : entry.modelData.preview.replace(/\s+/g, " ")
                                color: entry.selected ? Theme.inverseText : (entry.modelData.image ? Theme.accent : Theme.text)
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }
                        }

                        HoverHandler {
                            id: mouse
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: event => {
                                root.selectedIndex = entry.index;
                                if (event.button === Qt.RightButton)
                                    root.removeSelected();
                                else
                                    root.copySelected();
                            }
                        }
                    }
                }

                RText {
                    visible: root.filtered.length === 0
                    anchors.centerIn: parent
                    text: Clipboard.entries.length === 0 ? "CLIPBOARD HISTORY IS EMPTY" : "NO MATCHES"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
            }

            Rectangle {
                width: root.previewWidth
                height: parent.height
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    RText {
                        text: !root.selectedEntry ? "PREVIEW" : (root.selectedEntry.image ? "IMAGE PREVIEW" : "TEXT PREVIEW")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontExtraSmall
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    // images
                    Item {
                        width: parent.width
                        height: parent.height - 28
                        visible: root.selectedEntry?.image ?? false
                        clip: true

                        Image {
                            id: imagePreview

                            anchors.fill: parent
                            anchors.margins: 2
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectFit
                            source: root.showHere && Clipboard.imagePreviewPath.length > 0 ? "file://" + Clipboard.imagePreviewPath : ""
                        }

                        RText {
                            anchors.centerIn: parent
                            visible: imagePreview.status !== Image.Ready
                            text: "DECODING…"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                        }
                    }

                    // text
                    Flickable {
                        width: parent.width
                        height: parent.height - 28
                        visible: !(root.selectedEntry?.image ?? false)
                        clip: true
                        contentWidth: width
                        contentHeight: textPreview.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        RText {
                            id: textPreview

                            width: parent.width
                            text: root.selectedEntry?.preview ?? ""
                            color: Theme.textDim
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        RText {
            x: 10
            y: parent.height - 16
            text: "UP/DOWN SELECT · ENTER COPY · DEL REMOVE · CTRL+DEL CLEAR ALL · ESC CLOSE"
            color: Theme.textMuted
            font.pixelSize: Theme.fontExtraSmall
        }
    }

    onShowHereChanged: {
        if (showHere) {
            root.search = "";
            root.selectedIndex = 0;
            input.text = "";
            Clipboard.refresh();
            Clipboard.previewImage(selectedEntry);
            input.forceActiveFocus();
        } else {
            input.focus = false;
            Clipboard.previewImage(null);
        }
    }

    Connections {
        target: Clipboard

        function onEntriesChanged(): void {
            if (!root.showHere)
                return;
            root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.filtered.length - 1));
            Clipboard.previewImage(root.selectedEntry);
        }
    }
}
