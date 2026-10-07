import express from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { env } from "./config/env.js";
import { healthRouter } from "./routes/health.js";
import { sessionRouter } from "./routes/session.js";
import { journalRouter } from "./routes/journal.js";
import { insightRouter } from "./routes/insight.js";
import { accountRouter } from "./routes/account.js";

const app = express();

app.use(helmet());
app.use(express.json());
app.use(
  pinoHttp({
    level: env.NODE_ENV === "production" ? "info" : "debug",
    // Request logs go to Render, which account deletion can't reach, so they
    // carry no identifying data: no headers (the Authorization header is a
    // live access token), no client IP, and IDs in paths replaced with ":id".
    serializers: {
      req: (req: { method?: string; url?: string }) => ({
        method: req.method,
        url: req.url?.replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ":id"),
      }),
      res: (res: { statusCode?: number }) => ({ statusCode: res.statusCode }),
    },
    // Belt and braces in case a serializer change ever lets headers through.
    redact: ["req.headers.authorization", "req.headers.cookie", "req.remoteAddress"],
    // Crisis-detection events are logged with a distinct `event: "crisis_detected"`
    // field (see routes/session.ts) so they're easy to isolate in the host's log search
    // for auditing — see the architecture doc, Section 5.
  })
);

app.use(healthRouter);
app.use("/session", sessionRouter);
app.use("/journal", journalRouter);
app.use("/insight", insightRouter);
app.use("/account", accountRouter);

app.use((_req, res) => {
  res.status(404).json({ error: "not_found" });
});

app.listen(env.PORT, () => {
  console.log(`untilt-server listening on :${env.PORT} (${env.NODE_ENV})`);
});
