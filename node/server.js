const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
    res.send("<p>Hello from Express!</p>");
});

app.get("/api/time", (req, res) => {
    res.json({ time: new Date().toISOString() });
});

app.listen(PORT, "127.0.0.1", () => {
    console.log(`Listening on http://127.0.0.1:${PORT}/`);
});