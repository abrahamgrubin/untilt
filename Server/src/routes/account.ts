import { Router } from "express";
import type { AuthedRequest } from "../middleware/auth.js";
import { requireAuth } from "../middleware/auth.js";
import { deleteCompassData, deleteUser } from "../db/repositories/users.js";
import { deleteAuthUser, isAccountDeletionConfigured } from "../auth/supabaseAdmin.js";

export const accountRouter = Router();

accountRouter.use(requireAuth);

// Permanently deletes the account (App Store Guideline 5.1.1(v)): every row
// we hold for the user, then their Supabase Auth identity.
//
// Order matters. Data goes first, in one statement (every table cascades
// from users), so a failure later can't leave content behind. If the auth
// delete then fails, the client gets a 502 and can retry: the data delete
// is a no-op the second time, and an already-deleted auth user is treated
// as success.
accountRouter.delete("/", async (req: AuthedRequest, res, next) => {
  try {
    // Checked up front so we never delete data and then fail to remove the
    // login purely because the server is misconfigured.
    if (!isAccountDeletionConfigured()) {
      req.log?.error("account deletion requested but SUPABASE_SECRET_KEY is not set");
      res.status(503).json({ error: "account_deletion_unavailable" });
      return;
    }

    await deleteUser(req.userId!);

    try {
      await deleteAuthUser(req.userId!);
    } catch (err) {
      req.log?.error({ err }, "auth user delete failed after data delete");
      res.status(502).json({ error: "auth_delete_failed" });
      return;
    }

    req.log?.info({ event: "account_deleted" }, "account deleted");
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// Deletes Compass's conversations, notes and insights when the user turns
// Compass off and chooses to delete its history (withdrawing consent).
// The account itself stays.
accountRouter.delete("/compass-data", async (req: AuthedRequest, res, next) => {
  try {
    await deleteCompassData(req.userId!);
    req.log?.info({ event: "compass_data_deleted" }, "compass data deleted");
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});
