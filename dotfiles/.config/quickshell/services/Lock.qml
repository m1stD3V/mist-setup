pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// Session lock state, PAM authentication, idle timeout and logind sleep
// monitoring. The actual lock surfaces live in modules/lock/LockScreen.qml;
// this service is the single source of truth shared by every screen.
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"

    property bool locked: false
    // true while pam is checking a password
    property bool authenticating: false
    // last authentication error, empty when there is none
    property string error: ""
    // set while logind reports the machine is going to sleep
    property bool sleeping: false

    readonly property bool sleepWatcherActive: logindWatch.running

    property string pendingPassword: ""

    function lock(): void {
        if (root.locked)
            return;
        ShellState.closeAll();
        root.resetAuth();
        root.error = "";
        root.locked = true;
    }

    function unlock(): void {
        if (!root.locked)
            return;
        root.locked = false;
        root.resetAuth();
    }

    function authenticate(password: string): bool {
        if (!root.locked || root.authenticating)
            return false;
        root.error = "";
        root.pendingPassword = password;
        root.authenticating = true;
        if (!pam.start()) {
            root.pendingPassword = "";
            root.authenticating = false;
            root.error = "AUTH SERVICE UNAVAILABLE";
            return false;
        }
        return true;
    }

    function resetAuth(): void {
        if (pam.active)
            pam.abort();
        root.pendingPassword = "";
        root.authenticating = false;
        root.error = "";
    }

    function handleLogindLine(line: string): void {
        const text = line.trim();

        const sleep = text.match(/PrepareForSleep \((true|false),?\)/);
        if (sleep) {
            root.sleeping = sleep[1] === "true";
            if (Settings.lockOnSleep)
                root.lock();
            return;
        }

        // loginctl lock-session (also used by hypridle and similar tools)
        if (/\.Lock \(\)$/.test(text))
            root.lock();
    }

    PamContext {
        id: pam

        config: "login"
        user: root.user

        onResponseRequiredChanged: {
            if (responseRequired && root.pendingPassword.length > 0) {
                const password = root.pendingPassword;
                root.pendingPassword = "";
                pam.respond(password);
            }
        }

        onCompleted: result => {
            root.authenticating = false;
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                root.unlock();
            } else if (result === PamResult.MaxTries) {
                root.error = "TOO MANY ATTEMPTS";
            } else if (result === PamResult.Error) {
                root.error = "AUTHENTICATION ERROR";
            } else {
                root.error = "INCORRECT PASSWORD";
            }
        }

        onError: error => {
            root.authenticating = false;
            root.pendingPassword = "";
            root.error = "AUTH SERVICE ERROR";
        }
    }

    // ext-idle-notify-v1 timer. Inhibitors from video players and the like are
    // respected, matching normal desktop idle behavior.
    IdleMonitor {
        enabled: Settings.loaded && Settings.lockEnabled && Settings.lockTimeout > 0 && !root.locked
        timeout: Math.max(1, Settings.lockTimeout) * 60
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle && !root.locked)
                root.lock();
        }
    }

    // logind reports PrepareForSleep right before suspend and again on resume.
    // Locking on both edges means a fast lid close still leaves the session
    // locked when the display comes back.
    Process {
        id: logindWatch

        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        running: true

        stdout: SplitParser {
            onRead: line => root.handleLogindLine(line)
        }

        onExited: logindRestart.restart()
    }

    Timer {
        id: logindRestart

        interval: 5000
        onTriggered: logindWatch.running = true
    }

    // If PAM/the compositor takes the lock away unexpectedly, do not leave the
    // shell believing it is still locked.
    function syncFromCompositor(live: bool): void {
        if (!live && root.locked) {
            root.locked = false;
            root.resetAuth();
        }
    }
}
