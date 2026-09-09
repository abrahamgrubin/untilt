import { Router } from "express";
import { z } from "zod";
import type { AuthedRequest } from "../middleware/auth.js";
import { requireAuth } from "../middleware/auth.js";
import { ensureUser } from "../db/repositories/users.js";
import {
  createJournalEntry,
  deleteAllJournalEntries,
  deleteJournalEntry,
  listJournalEntries,
} from "../db/repositories/journal.js";

export const journalRouter = Router();

journalRouter.use(requireAuth);
journalRouter.use(async (req: AuthedRequest, res, next) => {
  try {
    await ensureUser(req.userId!);
    next();
  } catch (err) {
    next(err);
  }
});

const createSchema = z.object({
  content: z.string().min(1).max(20000),
  sessionId: z.string().uuid().optional(),
});

journalRouter.post("/", async (req: AuthedRequest, res, next) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });
    return;
  }
  try {
    const entry = await createJournalEntry(req.userId!, parsed.data.content, parsed.data.sessionId);
    res.status(201).json(entry);
  } catch (err) {
    next(err);
  }
});

journalRouter.get("/", async (req: AuthedRequest, res, next) => {
  try {
    const entries = await listJournalEntries(req.userId!);
    res.status(200).json({ entries });
  } catch (err) {
    next(err);
  }
});

// Full-history export (PRD 7.2/9) — same data as GET /, but the distinct
// route makes the export action explicit/auditable rather than reusing the
// list endpoint for two purposes.
journalRouter.get("/export", async (req: AuthedRequest, res, next) => {
  try {
    const entries = await listJournalEntries(req.userId!, 10_000);
    res.status(200).json({ exportedAt: new Date().toISOString(), entries });
  } catch (err) {
    next(err);
  }
});

// Permanent delete, single entry.
journalRouter.delete("/:id", async (req: AuthedRequest, res, next) => {
  try {
    const deleted = await deleteJournalEntry(req.userId!, req.params.id);
    if (!deleted) {
      res.status(404).json({ error: "entry_not_found" });
      return;
    }
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// Permanent delete, full history (PRD 7.2).
journalRouter.delete("/", async (req: AuthedRequest, res, next) => {
  try {
    await deleteAllJournalEntries(req.userId!);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});
