const express = require("express");
const os = require("os");

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.static("public"));

app.get("/api/info", (req, res) => {
  res.json({
    version: "v1",
    pod: os.hostname(),
    uid: process.getuid(),
    message: process.env.APP_MESSAGE || "not set",
    secretPresent: Boolean(process.env.APP_SECRET),
  });
});

app.get("/healthz", (req, res) => res.json({ status: "ok" }));

app.listen(PORT, "0.0.0.0", () => console.log(`Listening on ${PORT}`));
