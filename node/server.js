const express = require("express");
const { MongoClient } = require("mongodb");
const { createClient } = require("redis");

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || "127.0.0.1";
const MONGO_URL = process.env.MONGO_URL || "mongodb://127.0.0.1:27017";

const APP_NAME = "node";
const HIT_KEYS = ["hits:total", `hits:${APP_NAME}`];
const HITS_TTL = Number(process.env.HITS_TTL) || 3 * 24 * 3600;

const mongo = new MongoClient(MONGO_URL, { serverSelectionTimeoutMS: 3000 });

// Shared Redis for the hit counter. Without the offline queue, commands fail fast
// while Redis is down instead of piling up in memory — the site keeps working
const redis = createClient({
    socket: {
        host: process.env.REDIS_HOST || "127.0.0.1",
        port: Number(process.env.REDIS_PORT) || 6379,
        connectTimeout: 500,
    },
    password: process.env.REDIS_PASSWORD || undefined,
    disableOfflineQueue: true,
});
// While Redis is down the client retries every ~0.5 s: log only the first error
let redisDown = false;
redis.on("error", (err) => {
    if (!redisDown) console.warn(`Redis: ${err.message}`);
    redisDown = true;
});
redis.on("ready", () => {
    redisDown = false;
    console.log("Redis: connected");
});
redis.connect().catch(() => {}); // the client keeps reconnecting on its own

async function countHit() {
    // MULTI ignores disableOfflineQueue: while Redis is down, skip the hit instead of queueing it
    if (!redis.isReady) return;
    try {
        // MULTI/EXEC: increment, and start the TTL only when the key is new (NX),
        // so the counter covers a fixed 3-day window and then starts again from 0
        const tx = redis.multi();
        for (const key of HIT_KEYS) {
            tx.incr(key);
            tx.expire(key, HITS_TTL, "NX");
        }
        await tx.exec();
    } catch (err) {
        console.warn(`hit counter: ${err.message}`);
    }
}

app.use((req, res, next) => {
    countHit(); // not awaited: the response does not wait for Redis
    next();
});

app.get("/", (req, res) => {
    res.send("<p>Hello from Express!</p>");
});

app.get("/api/time", (req, res) => {
    res.json({ time: new Date().toISOString() });
});

app.get("/db", async (req, res) => {
    try {
        const info = await mongo.db("admin").command({ buildInfo: 1 });
        res.send(`<p>Connected to MongoDB ${info.version}</p>`);
    } catch (err) {
        res.status(500).send(`<p>MongoDB connection failed: ${err.message}</p>`);
    }
});

app.get("/hits", async (req, res) => {
    try {
        const apps = ["php", "python", "node"];
        const values = await redis.mGet(["hits:total", ...apps.map((a) => `hits:${a}`)]);
        const counts = Object.fromEntries(
            ["total", ...apps].map((name, i) => [name, Number(values[i] || 0)])
        );
        const ttl = await redis.ttl("hits:total");
        res.json({ ...counts, ttl_seconds: ttl, served_by: APP_NAME });
    } catch (err) {
        res.status(500).json({ error: `Redis: ${err.message}` });
    }
});

app.listen(PORT, HOST, () => {
    console.log(`Listening on http://${HOST}:${PORT}/`);
});
