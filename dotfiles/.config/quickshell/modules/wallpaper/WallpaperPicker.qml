pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Wallpaper switcher: centered grid of previews from the wallpaper
// directory. Click a card or press Enter to apply it to the shell background.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool showHere: ShellState.wallpaperOpen && Hypr.focusedMonitor?.name === Hypr.monitorFor(modelData)?.name

    readonly property int frameWidth: 820
    readonly property int frameHeight: 600

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
    focusable: showHere
    implicitWidth: root.frameWidth
    implicitHeight: root.frameHeight

    WlrLayershell.layer: WlrLayer.Overlay

    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.wallpaperOpen = false
    }

    Box {
        id: frame

        anchors.centerIn: parent
        width: root.frameWidth
        height: root.frameHeight
        // transformOrigin defaults to Item.Center, so the scaled frame stays centered
        scale: root.frameScale
        title: "WALLPAPERS"
        focus: root.showHere

        Keys.onPressed: event => {
            const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
            if (event.key === Qt.Key_Escape) {
                ShellState.wallpaperOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                grid.currentIndex = Math.max(0, grid.currentIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                grid.currentIndex = Math.min(folderModel.count - 1, grid.currentIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                grid.currentIndex = Math.max(0, grid.currentIndex - cols);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                grid.currentIndex = Math.min(folderModel.count - 1, grid.currentIndex + cols);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const item = grid.itemAtIndex(grid.currentIndex);
                Wallpapers.apply(item?.fileUrl ?? "");
                ShellState.wallpaperOpen = false;
                event.accepted = true;
            }
        }

        FolderListModel {
            id: folderModel

            folder: "file://" + Wallpapers.wallpaperDir
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v", "*.avi", "*.ogv"]
            showDirs: false
            sortField: FolderListModel.Name
        }

        GridView {
            id: grid

            anchors.fill: parent
            model: folderModel
            // spread the cells across the available width so no clipped
            // half-column is left at the right edge
            cellWidth: Math.floor(grid.width / Math.max(1, Math.floor(grid.width / 190)))
            cellHeight: 160
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Component.onCompleted: syncToCurrent()

            function syncToCurrent(): void {
                if (folderModel.count === 0)
                    return;
                let idx = 0;
                for (let i = 0; i < folderModel.count; i++) {
                    if (Wallpapers.current.endsWith(folderModel.get(i, "fileName") ?? "\u0000")) {
                        idx = i;
                        break;
                    }
                }
                grid.currentIndex = idx;
            }

            Connections {
                function onStatusChanged() {
                    grid.syncToCurrent();
                }

                target: folderModel
            }

            Connections {
                function onCurrentChanged() {
                    grid.syncToCurrent();
                }

                target: Wallpapers
            }

            delegate: Item {
                id: card

                required property string fileName
                required property string fileUrl
                required property int index

                readonly property bool isSelected: index === grid.currentIndex
                readonly property bool isActive: Wallpapers.current.endsWith(fileName)
                readonly property bool isVideo: Wallpapers.isVideoFile(fileName)

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    x: 5
                    y: 5
                    width: parent.width - 10
                    height: parent.height - 10
                    color: card.isSelected ? Theme.surfaceHigh : Theme.surface
                    border.width: 1
                    border.color: card.isSelected ? Theme.textHigh : Theme.border

                    Image {
                        id: thumb

                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: parent.height - 44
                        source: card.isVideo ? "" : card.fileUrl
                        sourceSize.width: 360
                        sourceSize.height: 240
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: !card.isVideo && thumb.status === Image.Ready
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 10
                        height: 10
                        color: Theme.textHigh
                        visible: card.isActive
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        color: Theme.borderHigh
                        visible: !card.isVideo && thumb.status !== Image.Ready
                    }

                    RText {
                        anchors.centerIn: parent
                        visible: card.isVideo
                        text: "VIDEO"
                        color: card.isSelected ? Theme.textHigh : Theme.textDim
                        font.pixelSize: Theme.fontSmall
                    }

                    RText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: parent.width - 12
                        text: card.fileName
                        font.pixelSize: Theme.fontExtraSmall + 2
                        color: card.isSelected ? Theme.textHigh : Theme.textDim
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        grid.currentIndex = card.index;
                        Wallpapers.apply(card.fileUrl);
                        ShellState.wallpaperOpen = false;
                    }
                }
            }
        }

        RText {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 4
            text: "ARROWS NAVIGATE  ENTER APPLY  ESC CLOSE"
            color: Theme.textMuted
            font.pixelSize: Theme.fontExtraSmall
        }
    }
}
