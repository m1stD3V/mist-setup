import QtQuick
import qs.Theme
import qs.services
import qs.components

// Hover preview pane for file-search results. Shows a thumbnail for
// images and text/metadata for other file types.
Rectangle {
    id: root

    property string path: ""

    readonly property var preview: FilePreview.preview
    readonly property bool loading: FilePreview.loading

    color: Theme.surface
    border.width: 1
    border.color: Theme.border
    clip: true

    onPathChanged: {
        if (path.length > 0)
            FilePreview.show(path);
        else
            FilePreview.clear();
    }

    Component.onCompleted: {
        if (path.length > 0)
            FilePreview.show(path);
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RText {
            width: parent.width
            text: (root.preview?.name ?? "PREVIEW").toUpperCase()
            color: Theme.textHigh
            font.pixelSize: Theme.fontSmall + 2
            elide: Text.ElideRight
        }

        RText {
            width: parent.width
            text: root.loading ? "LOADING..." : (root.preview?.type ?? "")
            color: Theme.textMuted
            font.pixelSize: Theme.fontExtraSmall
            elide: Text.ElideRight
        }

        RText {
            width: parent.width
            text: (root.preview?.sizeHuman ?? "") + "  " + (root.preview?.modified ?? "")
            color: Theme.textDim
            font.pixelSize: Theme.fontExtraSmall
            elide: Text.ElideRight
        }

        Image {
            visible: root.preview && (root.preview.mime ?? "").startsWith("image/")
            width: parent.width
            height: parent.height - 80
            source: visible ? "file://" + root.preview.path : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
        }

        RText {
            visible: root.preview && (root.preview.text ?? "").length > 0 && !(root.preview.mime ?? "").startsWith("image/")
            width: parent.width
            height: parent.height - 80
            text: root.preview?.text ?? ""
            color: Theme.text
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WrapAnywhere
            clip: true
        }

        RText {
            visible: root.preview && root.preview.kind === "dir"
            width: parent.width
            height: parent.height - 80
            text: (root.preview?.entries ?? []).join("\n")
            color: Theme.text
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WrapAnywhere
            clip: true
        }

        RText {
            visible: root.preview && (root.preview.metadata ?? "").length > 0
            width: parent.width
            height: parent.height - 80
            text: root.preview?.metadata ?? ""
            color: Theme.text
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WrapAnywhere
            clip: true
        }

        RText {
            visible: root.preview && (root.preview.error ?? "").length > 0
            width: parent.width
            text: root.preview?.error ?? ""
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WrapAnywhere
        }
    }
}
