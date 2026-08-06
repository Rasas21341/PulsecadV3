const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3000;
const ROOT = __dirname;
const ERLC_BASE = "https://api.erlc.gg";
const SUPABASE_URL = process.env.SUPABASE_URL || "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";

function supabaseRequest(method, supabasePath, body) {
    return new Promise((resolve, reject) => {
        const url = new URL(supabasePath, SUPABASE_URL + "/rest/v1/");
        const payload = body ? JSON.stringify(body) : null;
        const options = {
            method: method,
            hostname: url.hostname,
            path: url.pathname + url.search,
            headers: {
                "apikey": SUPABASE_SERVICE_ROLE_KEY,
                "Authorization": "Bearer " + SUPABASE_SERVICE_ROLE_KEY,
                "Content-Type": "application/json"
            }
        };
        if (payload) options.headers["Content-Length"] = Buffer.byteLength(payload);
        const req = https.request(options, (res) => {
            let data = "";
            res.on("data", (c) => { data += c; });
            res.on("end", () => {
                try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
                catch (e) { resolve({ status: res.statusCode, body: data }); }
            });
        });
        req.on("error", reject);
        if (payload) req.write(payload);
        req.end();
    });
}

const MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".ico": "image/x-icon"
};

function readBody(req) {
    return new Promise((resolve) => {
        let body = "";
        req.on("data", (chunk) => { body += chunk; });
        req.on("end", () => {
            try { resolve(body ? JSON.parse(body) : {}); }
            catch (e) { resolve({}); }
        });
    });
}

function discordRequest(path, token, method, bodyObj) {
    return new Promise((resolve, reject) => {
        const payload = bodyObj ? JSON.stringify(bodyObj) : null;
        const options = {
            method: method || "GET",
            hostname: "discord.com",
            path: "/api/v10" + path,
            headers: {
                "Authorization": "Bot " + token,
                "Content-Type": "application/json"
            }
        };
        if (payload) options.headers["Content-Length"] = Buffer.byteLength(payload);
        const req = https.request(options, (res) => {
            let data = "";
            res.on("data", (c) => { data += c; });
            res.on("end", () => {
                let json = null;
                try { json = JSON.parse(data); } catch (e) { json = data; }
                resolve({ status: res.statusCode, body: json });
            });
        });
        req.on("error", reject);
        if (payload) req.write(payload);
        req.end();
    });
}

async function handleDiscordApi(route, req, res) {
    const send = (status, obj) => {
        res.setHeader("Access-Control-Allow-Origin", "*");
        res.setHeader("Content-Type", "application/json");
        res.writeHead(status);
        res.end(JSON.stringify(obj));
    };
    try {
        const payload = req.method === "POST" ? await readBody(req) : {};
        const token = payload.token || "";
        if (!token) return send(400, { error: "Bot token is required" });

        if (route === "guilds") {
            const r = await discordRequest("/users/@me/guilds", token);
            if (r.status !== 200) return send(r.status, { error: "Discord error", detail: r.body });
            const guilds = Array.isArray(r.body) ? r.body.map((g) => ({ id: g.id, name: g.name, icon: g.icon ? "https://cdn.discordapp.com/icons/" + g.id + "/" + g.icon + ".png" : "" })) : [];
            return send(200, { guilds });
        }

        if (route === "channels") {
            const guildId = payload.guildId || "";
            if (!guildId) return send(400, { error: "guildId is required" });
            const r = await discordRequest("/guilds/" + guildId + "/channels", token);
            if (r.status !== 200) return send(r.status, { error: "Discord error", detail: r.body });
            const channels = Array.isArray(r.body)
                ? r.body
                    .filter((c) => c.type === 0 || c.type === 5 || c.type === 4)
                    .map((c) => ({ id: c.id, name: c.name, type: c.type, parent: c.parent_id || null }))
                : [];
            return send(200, { channels });
        }

        if (route === "create-webhook") {
            const channelId = payload.channelId || "";
            if (!channelId) return send(400, { error: "channelId is required" });
            const r = await discordRequest("/channels/" + channelId + "/webhooks", token, "POST", { name: "PulseCAD" });
            if (r.status < 200 || r.status >= 300) return send(r.status, { error: "Discord error", detail: r.body });
            const wh = r.body;
            const url = wh && wh.url ? wh.url : ("https://discord.com/api/webhooks/" + wh.id + "/" + wh.token);
            return send(200, { webhook: url });
        }

        return send(404, { error: "Unknown discord route: " + route });
    } catch (err) {
        send(500, { error: "Server error: " + err.message });
    }
}

const server = http.createServer(async (req, res) => {
    if (req.method === "OPTIONS") {
        res.setHeader("Access-Control-Allow-Origin", "*");
        res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        res.setHeader("Access-Control-Allow-Headers", "server-key, content-type, accept");
        res.writeHead(204);
        res.end();
        return;
    }

     if (req.url.startsWith("/api/erlc/")) {
         const rest = req.url.slice("/api/erlc/".length);
         const target = ERLC_BASE + "/" + rest;
         const headers = {};
         ["server-key", "content-type", "accept"].forEach((h) => {
             if (req.headers[h]) headers[h] = req.headers[h];
         });
         const options = { method: req.method, headers };
         console.log(`[proxy] ${req.method} /api/erlc/${rest} -> ${target}`);
         const proxyReq = https.request(target, options, (proxyRes) => {
             const proxyResHeaders = { ...proxyRes.headers };
             delete proxyResHeaders["cross-origin-resource-policy"];
             delete proxyResHeaders["cross-origin-opener-policy"];
             delete proxyResHeaders["cross-origin-embedder-policy"];
             proxyResHeaders["access-control-allow-origin"] = "*";
             res.writeHead(proxyRes.statusCode, proxyResHeaders);
             proxyRes.pipe(res);
         });
         proxyReq.on("error", (err) => {
             console.error(`[proxy] error for /api/erlc/${rest}:`, err.message);
             res.writeHead(502, { "Content-Type": "application/json" });
             res.end(JSON.stringify({ error: "Proxy failed: " + err.message }));
         });
         req.pipe(proxyReq);
         return;
     }

    if (req.url.startsWith("/api/discord-webhook")) {
        if (req.method !== "POST") {
            res.writeHead(405, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Method not allowed" }));
            return;
        }
        try {
            const payload = await readBody(req);
            const webhook = payload.webhook || "";
            if (!/^https:\/\/discord(app)?\.com\/api\/webhooks\//.test(webhook)) {
                res.writeHead(400, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ error: "Invalid webhook URL" }));
                return;
            }
            const message = {
                content: payload.content || "PulseCAD notification",
                username: payload.username || "PulseCAD",
                avatar_url: payload.avatar_url || ""
            };
            const body = JSON.stringify(message);
            const u = new URL(webhook);
            const options = {
                method: "POST",
                hostname: u.hostname,
                path: u.pathname + u.search,
                headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) }
            };
            const wreq = https.request(options, (wres) => {
                let data = "";
                wres.on("data", (c) => { data += c; });
                wres.on("end", () => {
                    res.setHeader("Access-Control-Allow-Origin", "*");
                    res.writeHead(wres.statusCode, { "Content-Type": "application/json" });
                    res.end(data);
                });
            });
            wreq.on("error", (err) => {
                res.writeHead(502, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ error: "Discord request failed: " + err.message }));
            });
            wreq.write(body);
            wreq.end();
        } catch (err) {
            res.writeHead(500, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Server error: " + err.message }));
        }
        return;
    }

    if (req.url.startsWith("/api/discord-")) {
        const rest = req.url.slice("/api/discord-".length).split("?")[0];
        await handleDiscordApi(rest, req, res);
        return;
    }

    if (req.url.startsWith("/api/kick") || req.url.startsWith("/api/ban")) {
        if (req.method !== "POST") {
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Content-Type", "application/json");
            res.writeHead(405);
            res.end(JSON.stringify({ error: "Method not allowed" }));
            return;
        }
        try {
            const payload = await readBody(req);
            const communityId = payload.communityId || "";
            const userId = payload.userId || "";
            const action = payload.action || "";

            if (!communityId || !userId || !action) {
                res.setHeader("Access-Control-Allow-Origin", "*");
                res.setHeader("Content-Type", "application/json");
                res.writeHead(400);
                res.end(JSON.stringify({ error: "communityId, userId, and action are required" }));
                return;
            }

            if (!SUPABASE_SERVICE_ROLE_KEY) {
                res.setHeader("Access-Control-Allow-Origin", "*");
                res.setHeader("Content-Type", "application/json");
                res.writeHead(500);
                res.end(JSON.stringify({ error: "Server not configured" }));
                return;
            }

            let result;
            if (req.url.startsWith("/api/kick")) {
                result = await supabaseRequest("DELETE", `user_communities?user_id=eq.${userId}&community_id=eq.${communityId}`);
            } else if (req.url.startsWith("/api/ban")) {
                result = await supabaseRequest("PATCH", `user_communities?user_id=eq.${userId}&community_id=eq.${communityId}`, { banned: true });
            }

            if (result.status < 200 || result.status >= 300) {
                res.setHeader("Access-Control-Allow-Origin", "*");
                res.setHeader("Content-Type", "application/json");
                res.writeHead(result.status);
                res.end(JSON.stringify({ error: "Supabase error", detail: result.body }));
                return;
            }

            const webhook = payload.webhook || "";
            const username = payload.username || "PulseCAD";
            if (webhook && /^https:\/\/discord(app)?\.com\/api\/webhooks\//.test(webhook)) {
                const actionText = action === "kick" ? "kicked" : "banned";
                const content = `**A user** was **${actionText}** from the community.`;
                const endpoints = ["/api/discord-webhook", "https://www.pulsecad.xyz/api/discord-webhook"];
                for (const ep of endpoints) {
                    try {
                        await fetch(ep, {
                            method: "POST",
                            headers: { "Content-Type": "application/json" },
                            body: JSON.stringify({ webhook, content, username })
                        });
                        break;
                    } catch (e) {}
                }
            }

            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Content-Type", "application/json");
            res.writeHead(200);
            res.end(JSON.stringify({ ok: true }));
        } catch (err) {
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Content-Type", "application/json");
            res.writeHead(500);
            res.end(JSON.stringify({ error: "Server error: " + err.message }));
        }
        return;
    }

    let urlPath = decodeURIComponent(req.url.split("?")[0]);
    if (urlPath === "/") urlPath = "/index.html";
    if (urlPath.startsWith("/community/")) urlPath = "/community.html";
    if (urlPath === "/suggestionmake") urlPath = "/suggestionmake.html";
    const filePath = path.join(ROOT, urlPath);
    if (!filePath.startsWith(ROOT)) {
        res.writeHead(403);
        res.end("Forbidden");
        return;
    }
    fs.readFile(filePath, (err, data) => {
        if (err) {
            res.writeHead(404, { "Content-Type": "text/plain" });
            res.end("Not found");
            return;
        }
        const ext = path.extname(filePath).toLowerCase();
        res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream" });
        res.end(data);
    });
});

server.listen(PORT, () => {
    console.log("PulseCAD dev server running at http://localhost:" + PORT);
});