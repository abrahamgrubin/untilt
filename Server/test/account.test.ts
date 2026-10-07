import { describe, expect, it, vi, beforeEach, afterAll, beforeAll } from "vitest";
import express from "express";
import type { AddressInfo } from "node:net";
import type { Server } from "node:http";

// --- Mocks: no network, no database, no auth provider ---------------------

const USER_ID = "00000000-0000-0000-0000-000000000002";

vi.mock("../src/middleware/auth.js", () => ({
  requireAuth: (req: any, _res: any, next: any) => {
    req.userId = USER_ID;
    req.log = { info: vi.fn(), warn: vi.fn(), error: vi.fn() };
    next();
  },
}));

const deleteUser = vi.fn(async () => {});
const deleteCompassData = vi.fn(async () => {});
vi.mock("../src/db/repositories/users.js", () => ({
  deleteUser: (...a: unknown[]) => deleteUser(...(a as [])),
  deleteCompassData: (...a: unknown[]) => deleteCompassData(...(a as [])),
}));

let configured = true;
const deleteAuthUser = vi.fn(async () => {});
vi.mock("../src/auth/supabaseAdmin.js", () => ({
  isAccountDeletionConfigured: () => configured,
  deleteAuthUser: (...a: unknown[]) => deleteAuthUser(...(a as [])),
}));

const { accountRouter } = await import("../src/routes/account.js");

let server: Server;
let base: string;

beforeAll(async () => {
  const app = express();
  app.use("/account", accountRouter);
  server = app.listen(0);
  await new Promise((r) => server.once("listening", r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

afterAll(() => server.close());

beforeEach(() => {
  configured = true;
  deleteUser.mockReset().mockResolvedValue(undefined);
  deleteAuthUser.mockReset().mockResolvedValue(undefined);
});

const del = () => fetch(`${base}/account`, { method: "DELETE" });

describe("DELETE /account", () => {
  it("deletes data, then the auth user, and returns 204", async () => {
    const res = await del();
    expect(res.status).toBe(204);
    expect(deleteUser).toHaveBeenCalledWith(USER_ID);
    expect(deleteAuthUser).toHaveBeenCalledWith(USER_ID);
    expect(deleteUser.mock.invocationCallOrder[0]).toBeLessThan(deleteAuthUser.mock.invocationCallOrder[0]);
  });

  it("refuses with 503 and deletes nothing when the secret key isn't configured", async () => {
    configured = false;
    const res = await del();
    expect(res.status).toBe(503);
    expect(deleteUser).not.toHaveBeenCalled();
    expect(deleteAuthUser).not.toHaveBeenCalled();
  });

  it("returns 502 when the auth delete fails, so the client can retry", async () => {
    deleteAuthUser.mockRejectedValueOnce(new Error("supabase down"));
    const res = await del();
    expect(res.status).toBe(502);
    expect(deleteUser).toHaveBeenCalled();
  });

  it("doesn't touch the auth user if the data delete fails", async () => {
    deleteUser.mockRejectedValueOnce(new Error("db down"));
    const res = await del();
    expect(res.status).toBe(500);
    expect(deleteAuthUser).not.toHaveBeenCalled();
  });
});

describe("DELETE /account/compass-data", () => {
  it("deletes Compass data but not the account", async () => {
    const res = await fetch(`${base}/account/compass-data`, { method: "DELETE" });
    expect(res.status).toBe(204);
    expect(deleteCompassData).toHaveBeenCalledWith(USER_ID);
    expect(deleteUser).not.toHaveBeenCalled();
    expect(deleteAuthUser).not.toHaveBeenCalled();
  });
});
