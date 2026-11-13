/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import definePlugin, { PluginNative, ReporterTestable } from "@utils/types";
import {
    CallStore,
    ChannelActions,
    ChannelStore,
    FluxDispatcher,
    GuildStore,
    IconUtils,
    IncomingCallStore,
    MediaEngineStore,
    PresenceStore,
    RelationshipStore,
    RestAPI,
    SelectedChannelStore,
    SpeakingStore,
    UserStore,
    VoiceActions,
    VoiceStateStore,
} from "@webpack/common";

const Native = VencordNative.pluginHelpers.DiscordBridge as PluginNative<typeof import("./native")>;

const DM = 1;

function isMainWindow(): boolean {
    if (typeof window === "undefined") return false;
    const path = window.location.pathname;
    return !path.startsWith("/overlay")
        && !path.startsWith("/popout")
        && !path.startsWith("/login")
        && !path.startsWith("/register");
}

let started = false;
let pushTimer: ReturnType<typeof setInterval> | undefined;
let commandTimer: ReturnType<typeof setInterval> | undefined;
let pushScheduled = false;

function displayName(user: any): string {
    if (!user) return "Unknown";
    return user.globalName || user.username || "Unknown";
}

function avatarUrl(user: any): string | null {
    if (!user) return null;
    try {
        const url = IconUtils.getUserAvatarURL(user, false, 64);
        if (!url) return null;
        return url.startsWith("http") ? url : "https://cdn.discordapp.com" + url;
    } catch {
        return null;
    }
}

function channelInfo(channel: any) {
    const myId = UserStore.getCurrentUser()?.id;
    if (!channel) return { name: "Unknown", guildName: null, type: "unknown", avatar: null };

    if (channel.guild_id) {
        const guild = GuildStore.getGuild(channel.guild_id);
        return {
            name: channel.name || "Voice",
            guildName: guild?.name ?? null,
            type: "guild",
            avatar: null,
        };
    }

    const recipientIds = (channel.recipients ?? []).filter((id: string) => id !== myId);
    if (channel.type === DM) {
        const user = UserStore.getUser(recipientIds[0]);
        return {
            name: displayName(user),
            guildName: null,
            type: "dm",
            avatar: avatarUrl(user),
        };
    }

    const names = recipientIds.slice(0, 3).map((id: string) => displayName(UserStore.getUser(id)));
    return {
        name: channel.name || names.join(", ") || "Group Call",
        guildName: null,
        type: "group",
        avatar: null,
    };
}

function buildParticipants(channelId: string) {
    const myId = UserStore.getCurrentUser()?.id;
    const states = VoiceStateStore.getVoiceStatesForChannel(channelId) ?? {};

    return Object.values(states).map((vs: any) => {
        const user = UserStore.getUser(vs.userId);
        let speaking = false;
        try {
            speaking = SpeakingStore.isSpeaking(vs.userId);
        } catch { }

        return {
            id: vs.userId,
            name: displayName(user),
            username: user?.username ?? "",
            avatar: avatarUrl(user),
            mute: !!(vs.mute || vs.selfMute),
            deaf: !!(vs.deaf || vs.selfDeaf),
            selfMute: !!vs.selfMute,
            selfDeaf: !!vs.selfDeaf,
            serverMute: !!vs.mute,
            serverDeaf: !!vs.deaf,
            speaking,
            stream: !!(vs.selfStream || vs.stream),
            video: !!vs.selfVideo,
            isSelf: vs.userId === myId,
        };
    }).sort((a, b) => {
        if (a.isSelf !== b.isSelf) return a.isSelf ? -1 : 1;
        return a.name.localeCompare(b.name);
    });
}

function activityText(userId: string): string | null {
    try {
        const activities = PresenceStore.getActivities(userId) ?? [];
        const activity = activities.find((a: any) => a.type !== 4);
        if (!activity) return null;
        if (activity.name === "Spotify") {
            return [activity.details, activity.state].filter(Boolean).join(" - ") || "Spotify";
        }
        return activity.details || activity.state || activity.name || null;
    } catch {
        return null;
    }
}

function buildFriends() {
    const ids = RelationshipStore.getFriendIDs() ?? [];
    const rank: Record<string, number> = { online: 0, idle: 1, dnd: 2 };
    const items: any[] = [];

    for (const id of ids) {
        let status = "offline";
        try {
            status = PresenceStore.getStatus(id) || "offline";
        } catch { }
        if (status === "offline") continue;

        const user = UserStore.getUser(id);
        items.push({
            id,
            name: displayName(user),
            username: user?.username ?? "",
            avatar: avatarUrl(user),
            status,
            activity: activityText(id),
        });
    }

    items.sort((a, b) => (rank[a.status] ?? 3) - (rank[b.status] ?? 3) || a.name.localeCompare(b.name));
    return { items: items.slice(0, 100), count: items.length };
}

function buildIncoming() {
    const myId = UserStore.getCurrentUser()?.id;
    if (!myId) return null;

    try {
        const calls = IncomingCallStore?.getIncomingCalls?.() ?? [];
        const first = calls[0];
        if (first) {
            const info = channelInfo(first.channel);
            const sender = UserStore.getUser(first.senderId);
            return {
                channelId: first.channel?.id,
                name: info.name,
                guildName: info.guildName,
                type: info.type,
                avatar: info.avatar || avatarUrl(sender),
                fromId: first.senderId ?? null,
                fromName: displayName(sender),
            };
        }
    } catch { }

    try {
        const calls = CallStore?.getCalls?.() ?? [];
        const call = calls.find((c: any) => (c.ringing ?? []).includes(myId));
        if (call) {
            const info = channelInfo(ChannelStore.getChannel(call.channelId));
            return {
                channelId: call.channelId,
                name: info.name,
                guildName: info.guildName,
                type: info.type,
                avatar: info.avatar,
                fromId: null,
                fromName: info.name,
            };
        }
    } catch { }

    return null;
}

function buildCall() {
    const myId = UserStore.getCurrentUser()?.id;
    let channelId: string | undefined;

    try {
        channelId = SelectedChannelStore.getVoiceChannelId();
    } catch { }

    if (!channelId && myId) {
        try {
            channelId = VoiceStateStore.getVoiceStateForUser(myId)?.channelId ?? undefined;
        } catch { }
    }

    if (!channelId) return null;
    const channel = ChannelStore.getChannel(channelId);
    if (!channel) return null;

    const info = channelInfo(channel);
    return {
        channelId,
        name: info.name,
        guildName: info.guildName,
        type: info.type,
        avatar: info.avatar,
        participants: buildParticipants(channelId),
    };
}

function buildState() {
    const me = UserStore.getCurrentUser();
    const call = buildCall();
    const incoming = buildIncoming();
    const friends = buildFriends();

    let selfMute = false;
    let selfDeaf = false;
    try {
        selfMute = !!MediaEngineStore.isSelfMute();
        selfDeaf = !!MediaEngineStore.isSelfDeaf();
    } catch { }

    if (me) {
        try {
            const vs = VoiceStateStore.getVoiceStateForUser(me.id);
            if (vs) {
                selfMute = !!vs.selfMute;
                selfDeaf = !!vs.selfDeaf;
            }
        } catch { }
    }

    return {
        type: "state",
        connected: !!me,
        user: me ? { id: me.id, name: displayName(me), avatar: avatarUrl(me) } : null,
        selfMute,
        selfDeaf,
        call,
        incoming,
        friends: friends.items,
        onlineFriends: friends.count,
        ts: Date.now(),
    };
}

function pushState() {
    if (!started) return;
    try {
        Native.pushState(JSON.stringify(buildState()));
    } catch (e) {
        console.error("[DiscordBridge] failed to push state", e);
    }
}

function schedulePush() {
    if (!started || pushScheduled) return;
    pushScheduled = true;
    setTimeout(() => {
        pushScheduled = false;
        pushState();
    }, 120);
}

async function executeCommand(cmd: string) {
    try {
        switch (cmd) {
            case "mute":
                VoiceActions.toggleSelfMute();
                break;
            case "deafen":
                VoiceActions.toggleSelfDeaf();
                break;
            case "leave":
                ChannelActions.selectVoiceChannel(null, null);
                break;
            case "accept": {
                const incoming = buildIncoming();
                if (incoming?.channelId) ChannelActions.selectVoiceChannel(incoming.channelId);
                break;
            }
            case "decline": {
                const incoming = buildIncoming();
                if (!incoming?.channelId) break;
                try {
                    const myId = UserStore.getCurrentUser()?.id;
                    await RestAPI.post({
                        url: `/channels/${incoming.channelId}/call/stop-ringing`,
                        body: { recipients: myId ? [myId] : [] },
                    });
                } catch { }
                try {
                    FluxDispatcher.dispatch({
                        type: "CALL_UPDATE",
                        channelId: incoming.channelId,
                        ringing: [],
                        ongoingRings: [],
                    });
                } catch { }
                break;
            }
            case "focus":
                await Native.focusDiscord();
                break;
        }
    } catch (e) {
        console.error("[DiscordBridge] command failed:", cmd, e);
    }
    setTimeout(pushState, 150);
}

async function pollCommands() {
    if (!started) return;
    try {
        const commands = await Native.pollCommands();
        for (const cmd of commands) await executeCommand(cmd);
    } catch { }
}

async function startBridge() {
    if (started || !isMainWindow()) return;
    try {
        await Native.start();
    } catch (e) {
        console.error("[DiscordBridge] failed to start bridge", e);
        return;
    }

    started = true;
    pushState();
    pushTimer = setInterval(pushState, 750);
    commandTimer = setInterval(pollCommands, 120);
}

function stopBridge() {
    started = false;
    if (pushTimer) clearInterval(pushTimer);
    if (commandTimer) clearInterval(commandTimer);
    pushTimer = undefined;
    commandTimer = undefined;
    try {
        Native.stop();
    } catch { }
}

export default definePlugin({
    name: "DiscordBridge",
    description: "Streams Discord voice calls and online friends to Quickshell over a local socket.",
    tags: ["Voice", "Utility"],
    authors: [{ name: "quickshell", id: 0n }],
    reporterTestable: ReporterTestable.None,
    enabledByDefault: true,

    start() {
        startBridge();
    },

    stop() {
        stopBridge();
    },

    flux: {
        VOICE_STATE_UPDATES: schedulePush,
        CALL_CREATE: schedulePush,
        CALL_UPDATE: schedulePush,
        CALL_DELETE: schedulePush,
        PRESENCE_UPDATES: schedulePush,
        RELATIONSHIP_ADD: schedulePush,
        RELATIONSHIP_REMOVE: schedulePush,
        CONNECTION_OPEN: () => {
            startBridge();
            schedulePush();
        },
        LOGOUT: schedulePush,
    },
});
