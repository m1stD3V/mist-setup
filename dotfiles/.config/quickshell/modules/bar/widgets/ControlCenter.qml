pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme
import qs.components
import qs.services

// Single panel for the settings that used to each own a bar chip: network,
// bluetooth, volume, brightness, media, power and notifications. The bar
// keeps this one opener plus the things that genuinely belong on a bar
// (workspaces, window title, clock); everything else moves in here.
BarChip {
    id: root

    property var window

    bar: root.window
    active: popup.open
    accessibleName: qsTr("Control center")

    onTapped: popup.open = !popup.open

    function closePopup(): void {
        popup.open = false;
    }

    function cycleProfile(): void {
        const profiles = PowerProfiles.profiles;
        if (profiles.length === 0)
            return;
        let index = 0;
        for (let i = 0; i < profiles.length; i++) {
            if (profiles[i].name === PowerProfiles.activeProfile) {
                index = i;
                break;
            }
        }
        PowerProfiles.setProfile(profiles[(index + 1) % profiles.length].name);
    }

    Row {
        id: btnRow

        spacing: 6

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: "SYS"
            color: root.hot ? Theme.inverseText : Theme.text
            font.pixelSize: Theme.fontExtraSmall + 2
        }

        // quiet indicator so "do not disturb" is visible without opening
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.dnd
            width: 6
            height: 6
            color: root.hot ? Theme.inverseText : (Theme.blink ? Theme.textHigh : Theme.textDim)
        }
    }

    Connections {
        target: ShellState

        function onWallpaperOpenChanged(): void {
            if (ShellState.wallpaperOpen)
                root.closePopup();
        }

        function onSessionOpenChanged(): void {
            if (ShellState.sessionOpen)
                root.closePopup();
        }

        function onAppsOpenChanged(): void {
            if (ShellState.appsOpen)
                root.closePopup();
        }

        function onSettingsOpenChanged(): void {
            if (ShellState.settingsOpen)
                root.closePopup();
        }
    }

    // suspend lives here; reboot/shutdown stay behind the session overlay so
    // a stray click cannot power the machine off
    Process {
        id: suspendProc

        command: ["systemctl", "suspend"]
    }

    BarPopup {
        id: popup

        readonly property int gap: 8
        readonly property int pad: 18
        readonly property int colW: Math.floor((contentWidth - pad - gap) / 2)
        readonly property int fullW: contentWidth - pad
        readonly property int rowA: 78
        readonly property int rowB: 78
        readonly property int rowC: 94
        readonly property int rowD: 78
        readonly property int rowE: 34

        barWindow: root.window
        screenEdge: "right"
        title: "CONTROL CENTER"
        contentWidth: 460
        // height follows the rows; no hand-added chrome constant to drift
        open: false

        onOpenChanged: {
            if (open) {
                Brightness.refresh();
            } else {
                networkPanel.open = false;
                bluetoothPanel.open = false;
                volumePanel.open = false;
                notifsPanel.open = false;
            }
        }

        content: Component {
            Column {
                width: parent.width
                spacing: popup.gap

                // ---- row 1: connectivity ----
                Row {
                    width: parent.width
                    height: popup.rowA
                    spacing: popup.gap

                    CcTile {
                        width: popup.colW
                        height: popup.rowA
                        title: "NETWORK"
                        active: Network.online
                        interactive: true
                        state: !Network.available ? "N/A" : (Network.wifiOn ? "ON" : "OFF")
                        stateClickable: Network.wifiAvailable
                        onClicked: {
                            popup.open = false;
                            networkPanel.open = true;
                        }
                        onStateClicked: Network.toggleWifi()

                        Column {
                            width: parent.width
                            spacing: 7

                            RText {
                                width: parent.width
                                text: Network.online ? Network.statusText : (Network.wifiOn ? "NOT CONNECTED" : "WI-FI OFF")
                                color: Network.online ? Theme.text : Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Row {
                                spacing: 8

                                Meter {
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: Network.activeWifi?.signalStrength ?? 0
                                    segments: 12
                                    segW: 6
                                    gap: 2
                                    showPct: false
                                }

                                RText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Network.activeWifi ? Math.round(Network.activeWifi.signalStrength * 100) + "%" : "--"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontSmall
                                }
                            }
                        }
                    }

                    CcTile {
                        width: popup.colW
                        height: popup.rowA
                        title: "BLUETOOTH"
                        active: Bluetooth.powered
                        interactive: true
                        state: !Bluetooth.available ? "N/A" : (Bluetooth.powered ? "ON" : "OFF")
                        stateClickable: Bluetooth.available
                        onClicked: {
                            popup.open = false;
                            bluetoothPanel.open = true;
                        }
                        onStateClicked: Bluetooth.togglePower()

                        Column {
                            width: parent.width
                            spacing: 7

                            RText {
                                width: parent.width
                                text: {
                                    if (!Bluetooth.available)
                                        return "NO ADAPTER";
                                    if (!Bluetooth.powered)
                                        return "POWERED OFF";
                                    const n = Bluetooth.connectedCount;
                                    return n === 0 ? "NO DEVICES" : n + (n === 1 ? " DEVICE" : " DEVICES");
                                }
                                color: Bluetooth.connectedCount > 0 ? Theme.text : Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            RText {
                                width: parent.width
                                text: Bluetooth.discovering ? "SCANNING..." : "LMB FOR DEVICES"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }

                // ---- row 2: levels ----
                Row {
                    width: parent.width
                    height: popup.rowB
                    spacing: popup.gap

                    CcTile {
                        width: popup.colW
                        height: popup.rowB
                        title: "VOLUME"
                        active: Audio.muted
                        interactive: true
                        state: Audio.muted ? "MUTE" : Math.round(Audio.volume * 100) + "%"
                        stateClickable: true
                        onClicked: {
                            popup.open = false;
                            volumePanel.open = true;
                        }
                        onStateClicked: Audio.toggleMuted()

                        Column {
                            width: parent.width
                            spacing: 7

                            CcBar {
                                width: parent.width
                                value: Audio.volume
                                muted: Audio.muted
                                onSetValue: v => Audio.setVolume(v)
                            }

                            RText {
                                width: parent.width
                                text: Audio.sinkLabel(Audio.sink)
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    CcTile {
                        width: popup.colW
                        height: popup.rowB
                        title: "BRIGHTNESS"
                        state: Brightness.level < 0 ? "--" : Math.round(Brightness.level * 100) + "%"

                        Column {
                            width: parent.width
                            spacing: 7

                            CcBar {
                                width: parent.width
                                value: Math.max(0, Brightness.level)
                                onSetValue: v => Brightness.setLevel(v)
                            }

                            RText {
                                width: parent.width
                                text: Brightness.level < 0 ? "NO BACKLIGHT" : "DRAG TO SET"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }

                // ---- row 3: media ----
                CcTile {
                    width: popup.fullW
                    height: popup.rowC
                    title: "MEDIA"
                    active: Media.playing
                    state: !Media.available ? "IDLE" : (Media.playing ? "PLAYING" : "PAUSED")

                    Row {
                        width: parent.width
                        spacing: 12

                        Column {
                            width: parent.width - controls.width - 12
                            spacing: 4

                            RText {
                                width: parent.width
                                text: Media.available ? Media.title : "NO PLAYER"
                                color: Media.available ? Theme.text : Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            RText {
                                width: parent.width
                                text: Media.available ? (Media.artist.length > 0 ? Media.artist : Media.identity) : "START A PLAYER TO CONTROL IT"
                                color: Media.available ? Theme.textDim : Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Item {
                                width: parent.width
                                height: 4

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.surfaceHighest
                                }

                                Rectangle {
                                    width: parent.width * Media.progress
                                    height: parent.height
                                    color: Media.available ? Theme.accent : Theme.surfaceHighest
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: Media.available && Media.canSeek
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => Media.seek(mouse.x / width)
                                }
                            }
                        }

                        Row {
                            id: controls

                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            TextButton {
                                label: "PREV"
                                enabled: Media.available && Media.canPrev
                                opacity: enabled ? 1 : 0.4
                                onClicked: Media.previousTrack()
                            }

                            TextButton {
                                label: Media.playing ? "PAUSE" : "PLAY"
                                enabled: Media.available && Media.canToggle
                                opacity: enabled ? 1 : 0.4
                                onClicked: Media.toggle()
                            }

                            TextButton {
                                label: "NEXT"
                                enabled: Media.available && Media.canNext
                                opacity: enabled ? 1 : 0.4
                                onClicked: Media.nextTrack()
                            }
                        }
                    }
                }

                // ---- row 4: power + notifications ----
                Row {
                    width: parent.width
                    height: popup.rowD
                    spacing: popup.gap

                    CcTile {
                        width: popup.colW
                        height: popup.rowD
                        title: "POWER"
                        active: Host.batteryCharging
                        interactive: PowerProfiles.available
                        state: PowerProfiles.available ? PowerProfiles.profileLabel(PowerProfiles.activeProfile) : "N/A"
                        onClicked: root.cycleProfile()

                        Column {
                            width: parent.width
                            spacing: 7

                            Row {
                                spacing: 8

                                Meter {
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: Host.batteryPresent ? Host.batteryPct : 0
                                    segments: 12
                                    segW: 6
                                    gap: 2
                                    showPct: false
                                }

                                RText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Host.batteryPresent ? Math.round(Host.batteryPct * 100) + "%" : "AC"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontSmall
                                }
                            }

                            RText {
                                width: parent.width
                                text: {
                                    if (!Host.batteryPresent)
                                        return "ON AC POWER";
                                    if (Host.batteryCharging)
                                        return "CHARGING";
                                    const left = Host.battery?.timeToEmpty ?? 0;
                                    return left > 0 ? Host.formatUptime(left).toUpperCase() + " LEFT" : "ON BATTERY";
                                }
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    CcTile {
                        width: popup.colW
                        height: popup.rowD
                        title: "NOTIFS"
                        active: Notifs.dnd
                        interactive: true
                        state: Notifs.dnd ? "DND" : "ON"
                        stateClickable: true
                        onClicked: {
                            popup.open = false;
                            notifsPanel.open = true;
                        }
                        onStateClicked: Notifs.dnd = !Notifs.dnd

                        Column {
                            width: parent.width
                            spacing: 7

                            Row {
                                width: parent.width
                                spacing: 8

                                RText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Notifs.unread === 0 ? "NO UNREAD" : Notifs.unread + " UNREAD"
                                    color: Notifs.unread > 0 ? Theme.text : Theme.textMuted
                                    font.pixelSize: Theme.fontSmall
                                }

                                RText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    visible: Notifs.unread > 0
                                    text: "CLEAR"
                                    color: clearMouse.containsMouse ? Theme.textHigh : Theme.textDim
                                    font.pixelSize: Theme.fontExtraSmall

                                    MouseArea {
                                        id: clearMouse

                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifs.clearUnread()
                                    }
                                }
                            }

                            RText {
                                width: parent.width
                                text: Notifs.dnd ? "DO NOT DISTURB" : "LMB TO MUTE"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }

                // ---- row 5: session ----
                Row {
                    width: parent.width
                    height: popup.rowE
                    spacing: popup.gap

                    TextButton {
                        width: (popup.fullW - popup.gap * 2) / 3
                        height: popup.rowE - 4
                        label: "LOCK"
                        onClicked: {
                            popup.open = false;
                            Lock.lock();
                        }
                    }

                    TextButton {
                        width: (popup.fullW - popup.gap * 2) / 3
                        height: popup.rowE - 4
                        label: "SLEEP"
                        onClicked: {
                            popup.open = false;
                            suspendProc.running = true;
                        }
                    }

                    TextButton {
                        width: (popup.fullW - popup.gap * 2) / 3
                        height: popup.rowE - 4
                        label: "SESSION"
                        onClicked: {
                            popup.open = false;
                            ShellState.toggleSession();
                        }
                    }
                }
            }
        }

        NetworkPanel {
            id: networkPanel

            barWindow: root.window
        }

        BluetoothPanel {
            id: bluetoothPanel

            barWindow: root.window
        }

        VolumePanel {
            id: volumePanel

            barWindow: root.window
        }

        NotifsPanel {
            id: notifsPanel

            barWindow: root.window
        }
    }
}
