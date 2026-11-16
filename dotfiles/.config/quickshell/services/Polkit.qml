pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// Registers the shell as the session's polkit agent, so privileged requests
// (pkexec, package and disk helpers, anything talking to
// org.freedesktop.PolicyKit1) get a MIST password dialog instead of failing
// with "no authentication agent found". The dialog itself lives in
// modules/polkit/PolkitPrompt.qml; this singleton owns the auth flow only.
Singleton {
    id: root

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && agent.flow !== null

    readonly property string message: flow?.message ?? ""
    readonly property string actionId: flow?.actionId ?? ""
    readonly property string prompt: flow?.inputPrompt ?? ""
    readonly property string detail: flow?.supplementaryMessage ?? ""
    readonly property bool detailIsError: flow?.supplementaryIsError ?? false
    readonly property bool failed: flow?.failed ?? false

    function submit(value: string): void {
        if (agent.flow && agent.flow.isResponseRequired)
            agent.flow.submit(value);
    }

    function cancel(): void {
        if (agent.flow)
            agent.flow.cancelAuthenticationRequest();
    }

    PolkitAgent {
        id: agent

        // unique within the session; a second agent on the same path would
        // make the bus refuse the registration
        path: "/org/mist/PolkitAgent"
    }
}
