const express = require("express");
const { MongoClient } = require("mongodb");

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || "127.0.0.1";
const MONGO_URL = process.env.MONGO_URL || "mongodb://127.0.0.1:27017";

const mongo = new MongoClient(MONGO_URL, { serverSelectionTimeoutMS: 3000 });

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

app.listen(PORT, HOST, () => {
    console.log(`Listening on http://${HOST}:${PORT}/`);
});
