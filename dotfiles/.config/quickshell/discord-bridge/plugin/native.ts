/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { BrowserWindow } from "electron";
import { existsSync, unlinkSync } from "fs";
import { createServer, Server, Socket } from "net";
import { tmpdir } from "os";
import { join } from "path";

const SOCKET_PATH = join(process.env.XDG_RUNTIME_DIR || tmpdir(), "quickshell-discord.sock");

let server: Server | null = null;
let lastState = "";
let commands: string[] = [];
let clients = new Set<Socket>();

function broadcast(line: string) {
    for (const client of clients) {
        try {
            client.write(line);
        } catch { }
    }
}

function startServer(): string {
    if (server) return SOCKET_PATH;

    try {
        if (existsSync(SOCKET_PATH)) unlinkSync(SOCKET_PATH);
    } catch { }

    server = createServer(socket => {
        clients.add(socket);
        socket.setEncoding("utf8");

        if (lastState) socket.write(lastState);

        let buffer = "";
        socket.on("data", (chunk: Buffer | string) => {
            buffer += chunk.toString();
            let idx: number;
            while ((idx = buffer.indexOf("\n")) !== -1) {
                const line = buffer.slice(0, idx).trim();
                buffer = buffer.slice(idx + 1);
                if (!line) continue;
                try {
                    const msg = JSON.parse(line);
                    if (typeof msg.cmd === "string") {
                        commands.push(msg.cmd);
                        if (commands.length > 32) commands.shift();
                    }
                } catch { }
            }
        });

        const drop = () => clients.delete(socket);
        socket.on("close", drop);
        socket.on("error", drop);
    });

    server.on("error", err => console.error("[DiscordBridge] socket server error:", err));
    server.listen(SOCKET_PATH);
    return SOCKET_PATH;
}

function stopServer() {
    if (!server) return;

    for (const client of clients) {
        try {
            client.destroy();
        } catch { }
    }
    clients.clear();

    try {
        server.close();
    } catch { }
    server = null;

    try {
        if (existsSync(SOCKET_PATH)) unlinkSync(SOCKET_PATH);
    } catch { }
}

export function start(_: unknown) {
    return startServer();
}

export function stop(_: unknown) {
    stopServer();
}

export function pushState(_: unknown, json: string) {
    if (typeof json !== "string" || json.length === 0) return;
    lastState = json.endsWith("\n") ? json : json + "\n";
    broadcast(lastState);
}

export function pollCommands(_: unknown): string[] {
    const out = commands;
    commands = [];
    return out;
}

export function focusDiscord(_: unknown) {
    try {
        const win = BrowserWindow.getAllWindows().find(w => !w.isDestroyed());
        if (!win) return;
        if (win.isMinimized()) win.restore();
        win.show();
        win.focus();
    } catch { }
}
