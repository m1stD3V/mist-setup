import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.services

// Layer-shell background surface: renders the selected wallpaper directly.
// Supports still images, animated GIFs, and looping video wallpapers.
PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: Theme.bg
    focusable: false

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"

    Image {
        anchors.fill: parent
        visible: !Wallpapers.animated && !Wallpapers.video
        source: Wallpapers.animated || Wallpapers.video ? "" : Wallpapers.currentUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
    }

    AnimatedImage {
        anchors.fill: parent
        visible: Wallpapers.animated
        source: Wallpapers.animated ? Wallpapers.currentUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
        playing: visible
    }

    Loader {
        anchors.fill: parent
        active: Wallpapers.video
        sourceComponent: Component {
            Video {
                anchors.fill: parent
                source: Wallpapers.currentUrl
                fillMode: VideoOutput.PreserveAspectCrop
                autoPlay: true
                loops: MediaPlayer.Infinite
                muted: true
                volume: 0
            }
        }
    }
}
