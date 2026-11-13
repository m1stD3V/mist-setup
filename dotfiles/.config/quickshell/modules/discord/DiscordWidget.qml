pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Bar button + popup for the Discord bridge: active call with
// participants/controls, and the online friends list.
Rectangle {
    id: root

    property PanelWindow window
    property string mode: "call"

    // only occupy bar space while the Discord bridge is connected
    visible: Discord.bridgeUp

    onVisibleChanged: {
        if (!visible)
            popup.open = false;
    }

    function closePopup(): void {
        popup.open = false;
    }

    function openPopup(): void {
        mode = Discord.inCall || Discord.ringing ? "call" : "friends";
        popup.open = true;
    }

    implicitWidth: labelRow.implicitWidth + 10
    implicitHeight: Theme.barHeight - 10
    color: hover.hovered || popup.open ? Theme.inverseBg : "transparent"
    border.width: 1
    border.color: hover.hovered || popup.open ? Theme.inverseBg : Theme.borderHigh

    HoverHandler {
        id: hover
    }

    Row {
        id: labelRow

        anchors.centerIn: parent
        spacing: 6

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: "DSC"
            color: hover.hovered || popup.open ? Theme.inverseText : Theme.text
            font.pixelSize: Theme.fontExtraSmall + 2
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Discord.ringing || Discord.inCall || (Discord.bridgeUp && Discord.ready && Discord.onlineFriends > 0)
            implicitWidth: badgeText.implicitWidth + 6
            implicitHeight: badgeText.implicitHeight + 2
            color: {
                if (Discord.ringing)
                    return Theme.blink ? Theme.textHigh : Theme.textMuted;
                if (hover.hovered || popup.open)
                    return Theme.inverseText;
                if (Discord.inCall)
                    return Theme.accent;
                return Theme.surfaceHighest;
            }

            RText {
                id: badgeText

                anchors.centerIn: parent
                text: {
                    if (Discord.ringing)
                        return "RING";
                    if (Discord.inCall)
                        return String(Discord.callCount);
                    if (Discord.bridgeUp && Discord.ready)
                        return String(Discord.onlineFriends);
                    return "--";
                }
                color: {
                    if (Discord.ringing)
                        return Theme.bg;
                    if (hover.hovered || popup.open)
                        return Theme.bg;
                    return Theme.inverseText;
                }
                font.pixelSize: Theme.fontExtraSmall
            }
        }
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: {
            if (!popup.open)
                root.openPopup();
            else
                popup.open = false;
        }
    }

    BarPopup {
        id: popup

        barWindow: root.window
        screenEdge: "right"
        title: "DISCORD"
        contentWidth: Theme.popupWidth
        contentHeight: 400
        open: false

        content: Component {
            Item {
                anchors.fill: parent

                Column {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    Item {
                        width: parent.width
                        height: 24

                        Row {
                            id: tabRow

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            DiscordButton {
                                label: "CALL"
                                active: root.mode === "call"
                                onClicked: root.mode = "call"
                            }

                            DiscordButton {
                                label: "FRIENDS"
                                active: root.mode === "friends"
                                onClicked: root.mode = "friends"
                            }
                        }

                        RText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!Discord.bridgeUp)
                                    return "BRIDGE OFF";
                                if (!Discord.ready)
                                    return "LOG IN";
                                if (Discord.inCall)
                                    return "IN CALL";
                                return "READY";
                            }
                            color: Discord.bridgeUp && Discord.ready ? Theme.textDim : Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.borderHigh
                    }

                    Flickable {
                        id: flick

                        width: parent.width
                        height: parent.height - 24 - 1 - 2 * Theme.spacingSm
                        contentWidth: width
                        contentHeight: body.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick

                        Column {
                            id: body

                            width: flick.width
                            spacing: 2

                            // ---------- call tab ----------
                            Column {
                                width: parent.width
                                spacing: 2
                                visible: root.mode === "call"

                                Item {
                                    width: parent.width
                                    height: Discord.ringing ? 44 : 0
                                    visible: Discord.ringing

                                    DiscordAvatar {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        size: 32
                                        source: Discord.incoming?.avatar ?? ""
                                        name: Discord.incoming?.fromName ?? ""
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 40
                                        anchors.right: incomingButtons.left
                                        anchors.rightMargin: 8
                                        spacing: 0

                                        RText {
                                            width: parent.width
                                            text: (Discord.incoming?.fromName ?? "UNKNOWN").toUpperCase()
                                            color: Theme.textHigh
                                            font.pixelSize: Theme.fontExtraSmall + 2
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        RText {
                                            width: parent.width
                                            text: "INCOMING CALL"
                                            color: Theme.blink ? Theme.textHigh : Theme.textDim
                                            font.pixelSize: Theme.fontExtraSmall
                                        }
                                    }

                                    Row {
                                        id: incomingButtons

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        DiscordButton {
                                            label: "OK"
                                            onClicked: Discord.acceptCall()
                                        }

                                        DiscordButton {
                                            label: "NO"
                                            danger: true
                                            onClicked: Discord.declineCall()
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: Discord.inCall ? 34 : 0
                                    visible: Discord.inCall

                                    Column {
                                        anchors.left: parent.left
                                        anchors.right: callFlags.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0

                                        RText {
                                            width: parent.width
                                            text: (Discord.call?.name ?? "").toUpperCase()
                                            color: Theme.textHigh
                                            font.pixelSize: Theme.fontSmall
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        RText {
                                            width: parent.width
                                            visible: (Discord.call?.guildName ?? "").length > 0
                                            text: (Discord.call?.guildName ?? "").toUpperCase()
                                            color: Theme.textDim
                                            font.pixelSize: Theme.fontExtraSmall
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    Row {
                                        id: callFlags

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Rectangle {
                                            visible: Discord.selfMute
                                            implicitWidth: flagMute.implicitWidth + 6
                                            implicitHeight: flagMute.implicitHeight + 2
                                            color: Theme.textHigh

                                            RText {
                                                id: flagMute

                                                anchors.centerIn: parent
                                                text: "MUTE"
                                                color: Theme.bg
                                                font.pixelSize: Theme.fontExtraSmall
                                            }
                                        }

                                        Rectangle {
                                            visible: Discord.selfDeaf
                                            implicitWidth: flagDeaf.implicitWidth + 6
                                            implicitHeight: flagDeaf.implicitHeight + 2
                                            color: Theme.textHigh

                                            RText {
                                                id: flagDeaf

                                                anchors.centerIn: parent
                                                text: "DEAF"
                                                color: Theme.bg
                                                font.pixelSize: Theme.fontExtraSmall
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: Discord.inCall ? 1 : 0
                                    visible: Discord.inCall
                                    color: Theme.borderHigh
                                }

                                Repeater {
                                    model: Discord.inCall ? (Discord.call?.participants ?? []) : []

                                    delegate: Item {
                                        id: participantRow

                                        required property var modelData

                                        width: parent.width
                                        height: 30

                                        Rectangle {
                                            anchors.fill: parent
                                            color: participantHover.hovered ? Theme.surfaceHigh : "transparent"
                                        }

                                        HoverHandler {
                                            id: participantHover
                                        }

                                        DiscordAvatar {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            size: 22
                                            source: participantRow.modelData.avatar ?? ""
                                            name: participantRow.modelData.name
                                            dim: !!(participantRow.modelData.mute || participantRow.modelData.deaf)
                                        }

                                        RText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 30
                                            anchors.right: participantFlags.left
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (participantRow.modelData.name + (participantRow.modelData.isSelf ? " (YOU)" : "")).toUpperCase()
                                            color: participantRow.modelData.isSelf ? Theme.textHigh : Theme.text
                                            font.pixelSize: Theme.fontExtraSmall + 2
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Row {
                                            id: participantFlags

                                            anchors.right: speakDot.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Rectangle {
                                                visible: !!participantRow.modelData.mute
                                                width: 12
                                                height: 12
                                                color: Theme.surfaceHighest

                                                RText {
                                                    anchors.centerIn: parent
                                                    text: "M"
                                                    color: Theme.textHigh
                                                    font.pixelSize: Theme.fontExtraSmall
                                                }
                                            }

                                            Rectangle {
                                                visible: !!participantRow.modelData.deaf
                                                width: 12
                                                height: 12
                                                color: Theme.surfaceHighest

                                                RText {
                                                    anchors.centerIn: parent
                                                    text: "D"
                                                    color: Theme.textHigh
                                                    font.pixelSize: Theme.fontExtraSmall
                                                }
                                            }

                                            Rectangle {
                                                visible: !!participantRow.modelData.stream
                                                width: 12
                                                height: 12
                                                color: Theme.surfaceHighest

                                                RText {
                                                    anchors.centerIn: parent
                                                    text: "S"
                                                    color: Theme.textHigh
                                                    font.pixelSize: Theme.fontExtraSmall
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: speakDot

                                            anchors.right: parent.right
                                            anchors.rightMargin: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 6
                                            height: 6
                                            color: Theme.accent
                                            visible: !!participantRow.modelData.speaking
                                            opacity: Theme.blink ? 1.0 : 0.35
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: Discord.inCall ? 30 : 0
                                    visible: Discord.inCall

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        DiscordButton {
                                            label: Discord.selfMute ? "UNMUTE" : "MUTE"
                                            active: Discord.selfMute
                                            onClicked: Discord.toggleMute()
                                        }

                                        DiscordButton {
                                            label: Discord.selfDeaf ? "UNDEAF" : "DEAFEN"
                                            active: Discord.selfDeaf
                                            onClicked: Discord.toggleDeafen()
                                        }

                                        DiscordButton {
                                            label: "LEAVE"
                                            danger: true
                                            onClicked: Discord.leaveCall()
                                        }
                                    }

                                    DiscordButton {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: "OPEN"
                                        onClicked: Discord.focusDiscord()
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: !Discord.inCall && !Discord.ringing ? 80 : 0
                                    visible: !Discord.inCall && !Discord.ringing

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        RText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Discord.bridgeUp ? "NOT IN A CALL" : "DISCORD BRIDGE OFFLINE"
                                            color: Discord.bridgeUp ? Theme.textDim : (Theme.blink ? Theme.textHigh : Theme.textMuted)
                                            font.pixelSize: Theme.fontSmall
                                        }

                                        RText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Discord.bridgeUp ? "JOIN A VOICE CHANNEL IN DISCORD" : "ENABLE THE DISCORDBRIDGE PLUGIN"
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fontExtraSmall
                                        }
                                    }
                                }
                            }

                            // ---------- friends tab ----------
                            Column {
                                width: parent.width
                                spacing: 2
                                visible: root.mode === "friends"

                                Item {
                                    width: parent.width
                                    height: 22

                                    RText {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "ONLINE FRIENDS"
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontExtraSmall
                                    }

                                    RText {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(Discord.onlineFriends)
                                        color: Theme.textHigh
                                        font.pixelSize: Theme.fontExtraSmall
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Theme.borderHigh
                                }

                                Repeater {
                                    model: Discord.friends

                                    delegate: Item {
                                        id: friendRow

                                        required property var modelData

                                        width: parent.width
                                        height: 30

                                        Rectangle {
                                            anchors.fill: parent
                                            color: friendHover.hovered ? Theme.surfaceHigh : "transparent"
                                        }

                                        HoverHandler {
                                            id: friendHover
                                        }

                                        DiscordAvatar {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            size: 22
                                            source: friendRow.modelData.avatar ?? ""
                                            name: friendRow.modelData.name
                                            dim: friendRow.modelData.status === "idle" || friendRow.modelData.status === "dnd"
                                        }

                                        Column {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 30
                                            anchors.right: statusDot.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 0

                                            RText {
                                                width: parent.width
                                                text: (friendRow.modelData.name ?? "").toUpperCase()
                                                color: friendRow.modelData.status === "dnd" ? Theme.textDim : Theme.text
                                                font.pixelSize: Theme.fontExtraSmall + 2
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            RText {
                                                width: parent.width
                                                visible: (friendRow.modelData.activity ?? "").length > 0
                                                text: friendRow.modelData.activity ?? ""
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontExtraSmall
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }

                                        Rectangle {
                                            id: statusDot

                                            anchors.right: parent.right
                                            anchors.rightMargin: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 6
                                            height: 6
                                            color: {
                                                switch (friendRow.modelData.status) {
                                                case "online":
                                                    return Theme.accent;
                                                case "idle":
                                                    return Theme.textDim;
                                                case "dnd":
                                                    return Theme.textHigh;
                                                default:
                                                    return Theme.textMuted;
                                                }
                                            }
                                            opacity: friendRow.modelData.status === "dnd" && Theme.blink ? 0.35 : 1.0
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: Discord.friends.length === 0 ? 80 : 0
                                    visible: Discord.friends.length === 0

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        RText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: !Discord.bridgeUp ? "DISCORD BRIDGE OFFLINE" : (!Discord.ready ? "NOT LOGGED IN" : "NO ONE ONLINE")
                                            color: Theme.textDim
                                            font.pixelSize: Theme.fontSmall
                                        }

                                        RText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: Discord.bridgeUp && Discord.ready
                                            text: "GO TOUCH SOME GRASS"
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fontExtraSmall
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
