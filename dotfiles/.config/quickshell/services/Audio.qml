pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property list<PwNode> sinks: []
    readonly property list<PwNode> streams: []

    // aggregate volume: loudest active output device, so the widget
    // reflects every active sink rather than only the default one
    readonly property real volume: {
        let v = 0;
        for (const n of sinks) {
            const nv = n?.audio?.volume ?? 0;
            if (nv > v)
                v = nv;
        }
        return v;
    }

    readonly property bool muted: sink?.audio?.muted ?? false

    // apply the same volume to every active output device
    function setVolume(newVolume: real): void {
        const v = Math.max(0, Math.min(1, newVolume));
        for (const n of sinks) {
            if (n?.ready && n?.audio) {
                n.audio.muted = false;
                n.audio.volume = v;
            }
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || 0.05));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || 0.05));
    }

    function toggleMuted(): void {
        const target = !muted;
        for (const n of sinks) {
            if (n?.ready && n?.audio)
                n.audio.muted = target;
        }
    }

    function setNodeVolume(node: PwNode, newVolume: real): void {
        if (node?.ready && node?.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1, newVolume));
        }
    }

    function setSinkVolume(node: PwNode, newVolume: real): void {
        setNodeVolume(node, newVolume);
    }

    function setStreamVolume(node: PwNode, newVolume: real): void {
        setNodeVolume(node, newVolume);
    }

    function toggleNodeMuted(node: PwNode): void {
        if (node?.ready && node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    function toggleSinkMuted(node: PwNode): void {
        toggleNodeMuted(node);
    }

    function sinkLabel(node: PwNode): string {
        const d = (node?.description ?? node?.name ?? "").toUpperCase();
        if (d.includes("HDMI") || d.includes("DISPLAYPORT"))
            return "HDMI";
        if (d.includes("SCARLETT"))
            return "SCARLETT";
        if (d.includes("BUILT-IN") || d.includes("BUILTIN"))
            return "BUILTIN";
        return (d.split(" ")[0] ?? "").slice(0, 8) || "OUT";
    }

    function streamLabel(node: PwNode): string {
        const props = node?.properties ?? {};
        const d = (props["application.name"] || props["node.description"] || node?.description || node?.name || "APP").toUpperCase();
        return d.slice(0, 10);
    }

    function refreshNodes(): void {
        const newSinks = [];
        const newStreams = [];

        for (const node of Pipewire.nodes.values) {
            if (!node.audio)
                continue;
            if (node.isSink && !node.isStream) {
                // real output device; sink monitors are stream-like
                // and never land here
                newSinks.push(node);
            } else if (node.isStream && node.isSink) {
                // app output streams appear as virtual sinks; skip
                // sink monitors once their properties are known
                const cls = node.properties?.["media.class"] ?? "";
                if (cls !== "Audio/Sink")
                    newStreams.push(node);
            }
        }

        root.sinks = newSinks;
        root.streams = newStreams;
    }

    // properties populate asynchronously after tracking starts, so
    // re-classify periodically until everything is settled
    Timer {
        interval: 3000
        running: true
        repeat: true

        onTriggered: root.refreshNodes()
    }

    Component.onCompleted: refreshNodes()

    Connections {
        function onValuesChanged(): void {
            root.refreshNodes();
        }

        target: Pipewire.nodes
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.streams].filter(n => n)
    }

    IpcHandler {
        function increment(): void {
            root.incrementVolume();
        }

        function decrement(): void {
            root.decrementVolume();
        }

        function mute(): void {
            root.toggleMuted();
        }

        target: "audio"
    }
}
