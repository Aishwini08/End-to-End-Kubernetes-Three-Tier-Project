const tasks = require("./routes/tasks");
const connection = require("./db");
const cors = require("cors");
const express = require("express");
const client = require("prom-client");
const app = express();
const mongoose = require('mongoose');

connection();

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
    name: "http_request_duration_seconds",
    help: "HTTP request duration in seconds",
    labelNames: ["method", "route", "status_code"],
    buckets: [0.05, 0.1, 0.3, 0.5, 1, 2, 5],
});

const httpRequestsTotal = new client.Counter({
    name: "http_requests_total",
    help: "Total number of HTTP requests",
    labelNames: ["method", "route", "status_code"],
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);

app.use(express.json());
app.use(cors());

app.use((req, res, next) => {
    const endTimer = httpRequestDuration.startTimer();

    res.on("finish", () => {
        const route = req.route?.path || req.baseUrl || req.path || "unknown";
        const labels = {
            method: req.method,
            route,
            status_code: String(res.statusCode),
        };

        httpRequestsTotal.inc(labels);
        endTimer(labels);
    });

    next();
});

// Health check endpoints

// Basic health check to see if the server is running
app.get('/healthz', (req, res) => {
    res.status(200).send('Healthy');
});

let lastReadyState = null;  
// Readiness check to see if the server is ready to serve requests
app.get('/ready', (req, res) => {
    // Here you can add logic to check database connection or other dependencies
    const isDbConnected = mongoose.connection.readyState === 1;
    if (isDbConnected !== lastReadyState) {
        console.log(`Database readyState: ${mongoose.connection.readyState}`);
        lastReadyState = isDbConnected;
    }
    
    if (isDbConnected) {
        res.status(200).send('Ready');
    } else {
        res.status(503).send('Not Ready');
    }
});

// Startup check to ensure the server has started correctly
app.get('/started', (req, res) => {
    // Assuming the server has started correctly if this endpoint is reachable
    res.status(200).send('Started');
});

app.get("/metrics", async (req, res) => {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
});

app.use("/api/tasks", tasks);

const port = process.env.PORT || 5000;
app.listen(port, () => console.log(`Listening on port ${port}...`));
