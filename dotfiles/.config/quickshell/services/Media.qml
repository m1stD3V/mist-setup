pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Now-playing state from MPRIS. One player is followed at a time: the one
// picked in the popup, else whichever is playing, else the first available.
// Position is interpolated locally between D-Bus updates so the bar's
// progress does not jump.
Singleton {
    id: root

    readonly property var players: Mpris.players?.values ?? []

    // uniqueId of the player explicitly chosen in the popup
    property string preferredId: ""
    // bumped by the ticker and by D-Bus signals to re-evaluate position
    property int tick: 0
    property double syncTime: Date.now()

    readonly property var player: {
        const list = players;
        if (!list || list.length === 0)
            return null;
        for (const p of list) {
            if (p.uniqueId === preferredId)
                return p;
        }
        for (const p of list) {
            if (p.isPlaying)
                return p;
        }
        return list[0];
    }

    readonly property bool available: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string identity: player?.identity ?? ""
    readonly property string title: {
        const t = player?.trackTitle ?? "";
        return t.length > 0 ? t : identity;
    }
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property real length: player?.length ?? 0

    readonly property real position: {
        const _t = tick;
        const p = player;
        if (!p)
            return 0;
        const base = Math.max(0, p.position ?? 0);
        if (!p.isPlaying)
            return length > 0 ? Math.min(base, length) : base;
        const pos = base + Math.max(0, (Date.now() - syncTime) / 1000);
        return length > 0 ? Math.min(pos, length) : pos;
    }

    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    readonly property bool canNext: player?.canGoNext ?? false
    readonly property bool canPrev: player?.canGoPrevious ?? false
    readonly property bool canToggle: player?.canTogglePlaying ?? true
    readonly property bool canSeek: player?.canSeek ?? false

    function resync(): void {
        syncTime = Date.now();
        tick++;
    }

    function select(p: var): void {
        if (!p)
            return;
        preferredId = p.uniqueId;
        resync();
    }

    function toggle(): void {
        if (player?.canTogglePlaying ?? false)
            player.togglePlaying();
        resync();
    }

    function nextTrack(): void {
        if (player?.canGoNext ?? false)
            player.next();
        resync();
    }

    function previousTrack(): void {
        if (player?.canGoPrevious ?? false)
            player.previous();
        resync();
    }

    function seek(fraction: real): void {
        if (!player || !(player.canSeek ?? false) || length <= 0)
            return;
        player.position = Math.max(0, Math.min(1, fraction)) * length;
        resync();
    }

    function fmt(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds || 0));
        const m = Math.floor(total / 60);
        const h = Math.floor(m / 60);
        const two = n => ("0" + n).slice(-2);
        if (h > 0)
            return h + ":" + two(m % 60) + ":" + two(total % 60);
        return m + ":" + two(total % 60);
    }

    onPlayerChanged: resync()

    Timer {
        interval: 1000
        repeat: true
        running: root.playing

        onTriggered: root.tick++
    }

    Connections {
        target: root.player

        function onPositionChanged(): void {
            root.resync();
        }

        function onLengthChanged(): void {
            root.resync();
        }

        function onTrackTitleChanged(): void {
            root.resync();
        }

        function onPlaybackStateChanged(): void {
            root.resync();
        }
    }
}
