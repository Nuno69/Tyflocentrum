#!/usr/bin/env node
/* eslint-disable no-console */

const http = require("node:http");
const { setTimeout: delay } = require("node:timers/promises");
const { mkdir, readFile, rename, writeFile } = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");

const PORT = parseInt(process.env.PORT || "9070", 10);
const DATA_DIR = process.env.DATA_DIR || "/var/lib/tyflocentrum-push";
const STATE_PATH = process.env.STATE_PATH || path.join(DATA_DIR, "state.json");
const POLL_INTERVAL_SECONDS = parseInt(process.env.POLL_INTERVAL_SECONDS || "300", 10);
const POLL_PER_PAGE = parseInt(process.env.POLL_PER_PAGE || "20", 10);
const TOKEN_TTL_DAYS = parseInt(process.env.TOKEN_TTL_DAYS || "60", 10);
const MAX_TOKENS = parseInt(process.env.MAX_TOKENS || "50000", 10);

const WEBHOOK_SECRET = (process.env.WEBHOOK_SECRET || "").trim();

const TYFLOPODCAST_WP = process.env.TYFLOPODCAST_WP || "https://tyflopodcast.net/wp-json/wp/v2/posts";
const TYFLOSWIAT_WP = process.env.TYFLOSWIAT_WP || "https://tyfloswiat.pl/wp-json/wp/v2/posts";

const APP_NAME = "tyflocentrum-push";
const APP_VERSION = "0.1.0";

function nowIso() {
	return new Date().toISOString();
}

function sha256Hex(input) {
	return crypto.createHash("sha256").update(input).digest("hex");
}

function jsonResponse(res, statusCode, body) {
	const payload = Buffer.from(JSON.stringify(body));
	res.writeHead(statusCode, {
		"Content-Type": "application/json; charset=utf-8",
		"Cache-Control": "no-store",
		"Content-Length": String(payload.byteLength),
	});
	res.end(payload);
}

function textResponse(res, statusCode, body) {
	const payload = Buffer.from(body);
	res.writeHead(statusCode, {
		"Content-Type": "text/plain; charset=utf-8",
		"Cache-Control": "no-store",
		"Content-Length": String(payload.byteLength),
	});
	res.end(payload);
}

function getBearerToken(req) {
	const header = req.headers["authorization"];
	if (!header || typeof header !== "string") return null;
	const match = header.match(/^Bearer\s+(.+)$/i);
	return match ? match[1] : null;
}

async function readJsonBody(req, maxBytes = 1024 * 1024) {
	if (req.method !== "POST" && req.method !== "PUT" && req.method !== "PATCH") {
		return null;
	}
	let bytes = 0;
	const chunks = [];
	for await (const chunk of req) {
		bytes += chunk.length;
		if (bytes > maxBytes) {
			throw new Error("Body too large");
		}
		chunks.push(chunk);
	}
	if (chunks.length === 0) return null;
	const raw = Buffer.concat(chunks).toString("utf8");
	if (!raw.trim()) return null;
	return JSON.parse(raw);
}

async function ensureDataDir() {
	await mkdir(DATA_DIR, { recursive: true, mode: 0o750 });
}

function defaultState() {
	return {
		schemaVersion: 1,
		createdAt: nowIso(),
		updatedAt: nowIso(),
		tokens: {},
		sent: {
			tyflopodcast: [],
			tyfloswiat: [],
			live: [],
			schedule: [],
		},
	};
}

async function loadState() {
	try {
		const raw = await readFile(STATE_PATH, "utf8");
		const parsed = JSON.parse(raw);
		if (!parsed || typeof parsed !== "object") return defaultState();
		return { ...defaultState(), ...parsed };
	} catch {
		return defaultState();
	}
}

async function saveState(state) {
	state.updatedAt = nowIso();
	const tmp = `${STATE_PATH}.tmp`;
	await writeFile(tmp, JSON.stringify(state, null, 2) + "\n", { mode: 0o640 });
	await rename(tmp, STATE_PATH);
}

function normalizePrefs(prefs) {
	const p = prefs && typeof prefs === "object" ? prefs : {};
	return {
		podcast: Boolean(p.podcast ?? true),
		article: Boolean(p.article ?? true),
		live: Boolean(p.live ?? true),
		schedule: Boolean(p.schedule ?? true),
	};
}

function isValidToken(token) {
	if (typeof token !== "string") return false;
	const trimmed = token.trim();
	if (trimmed.length < 16 || trimmed.length > 256) return false;
	// Accept hex (common), but don't require it strictly.
	return true;
}

function boundedUnshift(list, item, max = 500) {
	const next = [item, ...list.filter((x) => x !== item)];
	return next.slice(0, max);
}

function parseDateOrNull(value) {
	if (!value || typeof value !== "string") return null;
	const parsed = new Date(value);
	return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function pruneTokens(state) {
	if (!state.tokens || typeof state.tokens !== "object") return;

	const now = Date.now();
	const ttlDays = Number.isFinite(TOKEN_TTL_DAYS) ? TOKEN_TTL_DAYS : 0;
	const ttlMs = ttlDays > 0 ? ttlDays * 24 * 60 * 60 * 1000 : 0;

	let removed = 0;
	const entries = Object.entries(state.tokens);

	if (ttlMs > 0) {
		const cutoff = now - ttlMs;
		for (const [token, entry] of entries) {
			const lastSeenAt =
				parseDateOrNull(entry && entry.lastSeenAt) ??
				parseDateOrNull(entry && entry.updatedAt) ??
				parseDateOrNull(entry && entry.createdAt);
			if (!lastSeenAt) continue;
			if (lastSeenAt.getTime() < cutoff) {
				delete state.tokens[token];
				removed += 1;
			}
		}
	}

	if (Number.isFinite(MAX_TOKENS) && MAX_TOKENS > 0) {
		const remaining = Object.entries(state.tokens);
		if (remaining.length > MAX_TOKENS) {
			const sortedByLastSeenOldestFirst = remaining
				.map(([token, entry]) => {
					const lastSeenAt =
						parseDateOrNull(entry && entry.lastSeenAt) ??
						parseDateOrNull(entry && entry.updatedAt) ??
						parseDateOrNull(entry && entry.createdAt) ??
						new Date(0);
					return { token, lastSeenAtMs: lastSeenAt.getTime() };
				})
				.sort((a, b) => a.lastSeenAtMs - b.lastSeenAtMs);

			const toRemove = sortedByLastSeenOldestFirst.slice(0, remaining.length - MAX_TOKENS);
			for (const item of toRemove) {
				delete state.tokens[item.token];
				removed += 1;
			}
		}
	}

	if (removed > 0) {
		console.log(`[prune] removedTokens=${removed} ttlDays=${TOKEN_TTL_DAYS} maxTokens=${MAX_TOKENS}`);
	}
}

async function fetchLatestPosts(feedUrl, perPage) {
	const url = new URL(feedUrl);
	url.searchParams.set("context", "embed");
	url.searchParams.set("per_page", String(perPage));
	url.searchParams.set("_fields", "id,date,link,title");
	const res = await fetch(url.toString(), { headers: { Accept: "application/json" } });
	if (!res.ok) throw new Error(`WP fetch failed: ${res.status}`);
	return res.json();
}

async function sendNotificationToSubscribers({ category, payload, state }) {
	const tokens = Object.entries(state.tokens);
	const now = nowIso();
	let matched = 0;

	for (const [token, entry] of tokens) {
		const prefs = normalizePrefs(entry.prefs);
		if (!prefs[category]) continue;
		matched += 1;

		// APNs delivery is not enabled yet. We log so we can validate fan-out and payloads.
		console.log(`[push] (${category}) -> token=${sha256Hex(token).slice(0, 10)} payload=${JSON.stringify(payload)}`);

		state.tokens[token] = { ...entry, lastNotifiedAt: now };
	}

	console.log(`[push] category=${category} matchedTokens=${matched}`);
}

async function pollWordPressAndNotify(state) {
	const [podcasts, articles] = await Promise.all([
		fetchLatestPosts(TYFLOPODCAST_WP, POLL_PER_PAGE),
		fetchLatestPosts(TYFLOSWIAT_WP, POLL_PER_PAGE),
	]);

	const sentPodcastIds = new Set(state.sent.tyflopodcast || []);
	const sentArticleIds = new Set(state.sent.tyfloswiat || []);

	for (const post of podcasts) {
		if (!post || typeof post.id !== "number") continue;
		if (sentPodcastIds.has(post.id)) continue;
		const title = (post.title && post.title.rendered) || "Nowy odcinek";
		await sendNotificationToSubscribers({
			category: "podcast",
			payload: { kind: "podcast", id: post.id, title, url: post.link, publishedAt: post.date },
			state,
		});
		state.sent.tyflopodcast = boundedUnshift(state.sent.tyflopodcast || [], post.id);
	}

	for (const post of articles) {
		if (!post || typeof post.id !== "number") continue;
		if (sentArticleIds.has(post.id)) continue;
		const title = (post.title && post.title.rendered) || "Nowy artykuł";
		await sendNotificationToSubscribers({
			category: "article",
			payload: { kind: "article", id: post.id, title, url: post.link, publishedAt: post.date },
			state,
		});
		state.sent.tyfloswiat = boundedUnshift(state.sent.tyfloswiat || [], post.id);
	}
}

async function startPollLoop() {
	await ensureDataDir();
	let state = await loadState();

	while (true) {
		try {
			state = await loadState();
			await pollWordPressAndNotify(state);
			pruneTokens(state);
			await saveState(state);
		} catch (err) {
			console.error(`[poll] error: ${err && err.message ? err.message : String(err)}`);
		}
		await delay(POLL_INTERVAL_SECONDS * 1000);
	}
}

function routeNotFound(res) {
	jsonResponse(res, 404, { ok: false, error: "Not found" });
}

async function handleRequest(req, res) {
	const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

	if (req.method === "GET" && url.pathname === "/health") {
		return jsonResponse(res, 200, { ok: true, name: APP_NAME, version: APP_VERSION, time: nowIso() });
	}

	if (req.method === "POST" && url.pathname === "/api/v1/register") {
		let body;
		try {
			body = await readJsonBody(req);
		} catch {
			return jsonResponse(res, 413, { ok: false, error: "Body too large" });
		}
		const token = body && body.token;
		if (!isValidToken(token)) return jsonResponse(res, 400, { ok: false, error: "Invalid token" });

		const env = typeof body.env === "string" ? body.env : "unknown";
		const prefs = normalizePrefs(body.prefs);

		const state = await loadState();
		const existing = state.tokens[token] || {};
		state.tokens[token] = {
			...existing,
			token,
			env,
			prefs,
			createdAt: existing.createdAt || nowIso(),
			updatedAt: nowIso(),
			lastSeenAt: nowIso(),
		};
		pruneTokens(state);
		await saveState(state);
		return jsonResponse(res, 200, { ok: true });
	}

	if (req.method === "POST" && url.pathname === "/api/v1/update") {
		let body;
		try {
			body = await readJsonBody(req);
		} catch {
			return jsonResponse(res, 413, { ok: false, error: "Body too large" });
		}
		const token = body && body.token;
		if (!isValidToken(token)) return jsonResponse(res, 400, { ok: false, error: "Invalid token" });

		const prefs = normalizePrefs(body.prefs);
		const state = await loadState();
		if (!state.tokens[token]) return jsonResponse(res, 404, { ok: false, error: "Unknown token" });
		state.tokens[token] = { ...state.tokens[token], prefs, updatedAt: nowIso(), lastSeenAt: nowIso() };
		pruneTokens(state);
		await saveState(state);
		return jsonResponse(res, 200, { ok: true });
	}

	if (req.method === "POST" && url.pathname === "/api/v1/unregister") {
		let body;
		try {
			body = await readJsonBody(req);
		} catch {
			return jsonResponse(res, 413, { ok: false, error: "Body too large" });
		}
		const token = body && body.token;
		if (!isValidToken(token)) return jsonResponse(res, 400, { ok: false, error: "Invalid token" });

		const state = await loadState();
		delete state.tokens[token];
		pruneTokens(state);
		await saveState(state);
		return jsonResponse(res, 200, { ok: true });
	}

	if (req.method === "POST" && url.pathname.startsWith("/api/v1/events/")) {
		const token = getBearerToken(req);
		if (!WEBHOOK_SECRET || token !== WEBHOOK_SECRET) {
			return textResponse(res, 403, "Forbidden");
		}
		let body;
		try {
			body = await readJsonBody(req);
		} catch {
			return jsonResponse(res, 413, { ok: false, error: "Body too large" });
		}

		const state = await loadState();
		const event = url.pathname.replace("/api/v1/events/", "");

		if (event === "live-start") {
			await sendNotificationToSubscribers({
				category: "live",
				payload: { kind: "live", title: body && body.title ? String(body.title) : "Audycja na żywo", startedAt: body && body.startedAt },
				state,
			});
			state.sent.live = boundedUnshift(state.sent.live || [], nowIso());
			await saveState(state);
			return jsonResponse(res, 200, { ok: true });
		}
		if (event === "live-end") {
			// Optional: no push on end, but keep endpoint for symmetry.
			state.sent.live = boundedUnshift(state.sent.live || [], nowIso());
			await saveState(state);
			return jsonResponse(res, 200, { ok: true });
		}
		if (event === "schedule-updated") {
			await sendNotificationToSubscribers({
				category: "schedule",
				payload: { kind: "schedule", title: "Zaktualizowano ramówkę", updatedAt: body && body.updatedAt },
				state,
			});
			state.sent.schedule = boundedUnshift(state.sent.schedule || [], nowIso());
			await saveState(state);
			return jsonResponse(res, 200, { ok: true });
		}

		return routeNotFound(res);
	}

	return routeNotFound(res);
}

async function main() {
	await ensureDataDir();

	const server = http.createServer((req, res) => {
		handleRequest(req, res).catch((err) => {
			console.error(`[http] error: ${err && err.message ? err.message : String(err)}`);
			jsonResponse(res, 500, { ok: false, error: "Internal error" });
		});
	});

	server.listen(PORT, "127.0.0.1", () => {
		console.log(`${APP_NAME} listening on 127.0.0.1:${PORT}`);
		console.log(`state: ${STATE_PATH}`);
	});

	startPollLoop().catch((err) => {
		console.error(`[poll] fatal: ${err && err.message ? err.message : String(err)}`);
		process.exit(1);
	});
}

main().catch((err) => {
	console.error(`[main] fatal: ${err && err.message ? err.message : String(err)}`);
	process.exit(1);
});
