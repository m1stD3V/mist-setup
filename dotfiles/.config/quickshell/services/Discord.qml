pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Local bridge to Discord (via the DiscordBridge Equicord/Vencord plugin).
// The plugin opens a unix socket and streams newline-delimited JSON state.
Singleton {
    id: root

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-discord.sock"
    readonly property string ringSound: Quickshell.shellPath("assets/ring.wav")

    // the Discord desktop app itself, independent of the bridge: lets the bar
    // module start, focus or kill it even when no call is active
    readonly property string appBinary: "/usr/bin/discord"
    property bool appRunning: false

    // bridge state
    readonly property bool bridgeUp: sock.connected
    property bool ready: false
    property var user: null
    property bool selfMute: false
    property bool selfDeaf: false
    property var call: null
    property var incoming: null
    property var friends: []
    property int onlineFriends: 0
    property double lastUpdate: 0

    readonly property bool inCall: call !== null
    readonly property bool ringing: incoming !== null
    readonly property int callCount: call && call.participants ? call.participants.length : 0

    signal stateReceived

    function handleLine(line: string): void {
        const t = line.trim();
        if (t.length === 0)
            return;
        let msg;
        try {
            msg = JSON.parse(t);
        } catch (e) {
            return;
        }
        if (msg.type !== "state")
            return;
        ready = !!msg.connected;
        user = msg.user ?? null;
        selfMute = !!msg.selfMute;
        selfDeaf = !!msg.selfDeaf;
        call = msg.call ?? null;
        incoming = msg.incoming ?? null;
        friends = msg.friends ?? [];
        onlineFriends = msg.onlineFriends ?? friends.length;
        lastUpdate = Date.now();
        stateReceived();
    }

    function send(cmd: string): void {
        if (sock.connected)
            sock.write(JSON.stringify({
                "cmd": cmd
            }) + "\n");
    }

    function toggleMute(): void {
        send("mute");
    }

    function toggleDeafen(): void {
        send("deafen");
    }

    function leaveCall(): void {
        send("leave");
    }

    function acceptCall(): void {
        send("accept");
    }

    function declineCall(): void {
        send("decline");
    }

    function focusDiscord(): void {
        const win = Hypr.findToplevelByClass("DISCORD");
        if (win) {
            if (Hypr.isMinimized(win))
                Hypr.restoreWindow(win);
            else
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:${Hypr.addressOf(win)}" })` : `focuswindow address:${Hypr.addressOf(win)}`);
        }
        send("focus");
    }

    // polled so the module knows whether the app is there to focus or to start
    function refreshAppRunning(): void {
        if (!appCheck.running)
            appCheck.running = true;
    }

    function launchApp(): void {
        // route through Hyprland like the auto-repair script does, so window
        // rules place the new window; there is nothing to do while killing
        if (killProc.running)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.exec_cmd("${appBinary}")` : `exec ${appBinary}`);
        appRunning = true;
        appCheckTimer.restart();
    }

    // SIGTERM, then SIGKILL whatever is left: the whole Electron tree, not
    // just the main process
    function killApp(): void {
        if (killProc.running)
            return;
        killProc.running = true;
    }

    Process {
        id: appCheck

        command: ["pgrep", "-x", "Discord"]

        onExited: (code, status) => {
            if (!killProc.running)
                root.appRunning = code === 0;
        }
    }

    Timer {
        id: appCheckTimer

        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!killProc.running)
                root.refreshAppRunning();
        }
    }

    Process {
        id: killProc

        command: ["sh", "-c", "pkill -x Discord; sleep 2; pkill -9 -x Discord >/dev/null 2>&1; exit 0"]

        onExited: (code, status) => {
            root.appRunning = false;
            // the bridge dies with the app; clear its state right away instead
            // of waiting for the socket to drop
            root.ready = false;
            root.call = null;
            root.incoming = null;
            root.friends = [];
            root.onlineFriends = 0;
        }
    }

    Socket {
        id: sock

        path: root.socketPath
        connected: true
        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleLine(data)
        }
    }

    // the bridge may come up after the shell (or Discord may restart), so
    // keep retrying until a connection sticks
    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            if (!sock.connected) {
                sock.connected = false;
                sock.connected = true;
            }
        }
    }

    // ringtone loop while an incoming call is pending
    Timer {
        interval: 2600
        running: root.ringing
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (root.ringing)
                Quickshell.execDetached(["paplay", root.ringSound]);
        }
    }

    IpcHandler {
        target: "discord"

        function mute(): void {
            root.toggleMute();
        }

        function deafen(): void {
            root.toggleDeafen();
        }

        function leave(): void {
            root.leaveCall();
        }

        function accept(): void {
            root.acceptCall();
        }

        function decline(): void {
            root.declineCall();
        }

        function focus(): void {
            root.focusDiscord();
        }

        function open(): void {
            if (root.appRunning)
                root.focusDiscord();
            else
                root.launchApp();
        }

        function kill(): void {
            root.killApp();
        }
    }
}
