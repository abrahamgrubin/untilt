import express from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { env } from "./config/env.js";
import { healthRouter } from "./routes/health.js";
import { sessionRouter } from "./routes/session.js";
import { journalRouter } from "./routes/journal.js";
import { insightRouter } from "./routes/insight.js";

const app = express();

app.use(helmet());
app.use(express.json());
app.use(
  pinoHttp({
    level: env.NODE_ENV === "production" ? "info" : "debug",
    // Crisis-detection events are logged with a distinct `event: "crisis_detected"`
    // field (see routes/session.ts) so they're easy to isolate in CloudWatch
    // Logs Insights for auditing — see the architecture doc, Section 5.
  })
);

app.use(healthRouter);
app.use("/session", sessionRouter);
app.use("/journal", journalRouter);
app.use("/insight", insightRouter);

app.use((_req, res) => {
  res.status(404).json({ error: "not_found" });
});

app.listen(env.PORT, () => {
  console.log(`untilt-server listening on :${env.PORT} (${env.NODE_ENV})`);
});
