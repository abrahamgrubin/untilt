import { env } from "../config/env.js";

/**
 * Deletes a user from Supabase Auth, so they can no longer sign in and their
 * email/identity is gone from the auth schema. Needs the project's secret
 * key (SUPABASE_SECRET_KEY). Callers should check
 * isAccountDeletionConfigured() before deleting any data.
 *
 * An already-deleted user (404) counts as success, so a retry after a
 * partial failure completes cleanly.
 */
export async function deleteAuthUser(userId: string): Promise<void> {
  const key = env.SUPABASE_SECRET_KEY;
  if (!key) throw new Error("SUPABASE_SECRET_KEY is not set");

  const headers: Record<string, string> = { apikey: key };
  // New `sb_secret_…` keys go on `apikey` only; a legacy service_role key
  // is a JWT and also needs the Authorization header.
  if (key.startsWith("eyJ")) headers.Authorization = `Bearer ${key}`;

  const base = env.SUPABASE_URL.replace(/\/$/, "");
  const response = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers,
    // Returns a retryable 502 to the app rather than hanging past its timeout.
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok && response.status !== 404) {
    throw new Error(`Supabase admin delete failed: ${response.status}`);
  }
}

export function isAccountDeletionConfigured(): boolean {
  return Boolean(env.SUPABASE_SECRET_KEY);
}
