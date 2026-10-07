import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";

const env = { SUPABASE_URL: "https://proj.supabase.co/", SUPABASE_SECRET_KEY: "sb_secret_test" as string | undefined };
vi.mock("../src/config/env.js", () => ({ env }));

const { deleteAuthUser, isAccountDeletionConfigured } = await import("../src/auth/supabaseAdmin.js");

const fetchMock = vi.fn();
beforeEach(() => {
  env.SUPABASE_SECRET_KEY = "sb_secret_test";
  fetchMock.mockReset().mockResolvedValue(new Response(null, { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);
});
afterEach(() => vi.unstubAllGlobals());

describe("deleteAuthUser", () => {
  it("calls the admin endpoint with the secret key on apikey only", async () => {
    await deleteAuthUser("abc");
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe("https://proj.supabase.co/auth/v1/admin/users/abc");
    expect(init.method).toBe("DELETE");
    expect(init.headers).toEqual({ apikey: "sb_secret_test" });
  });

  it("also sends Authorization for a legacy service_role JWT", async () => {
    env.SUPABASE_SECRET_KEY = "eyJlegacy";
    await deleteAuthUser("abc");
    expect(fetchMock.mock.calls[0][1].headers).toEqual({ apikey: "eyJlegacy", Authorization: "Bearer eyJlegacy" });
  });

  it("treats an already-deleted user (404) as success", async () => {
    fetchMock.mockResolvedValue(new Response(null, { status: 404 }));
    await expect(deleteAuthUser("abc")).resolves.toBeUndefined();
  });

  it("throws on other failures so the route can return 502", async () => {
    fetchMock.mockResolvedValue(new Response(null, { status: 500 }));
    await expect(deleteAuthUser("abc")).rejects.toThrow("500");
  });

  it("reports whether deletion is configured", () => {
    expect(isAccountDeletionConfigured()).toBe(true);
    env.SUPABASE_SECRET_KEY = undefined;
    expect(isAccountDeletionConfigured()).toBe(false);
  });
});
