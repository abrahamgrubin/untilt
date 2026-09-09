import { pool } from "../pool.js";

export interface MemoryProfile {
  triggers: string[];
  copingStrategies: string[];
  pastCrisisFlags: boolean;
  tonePreferences: string;
}

export const EMPTY_PROFILE: MemoryProfile = {
  triggers: [],
  copingStrategies: [],
  pastCrisisFlags: false,
  tonePreferences: "",
};

export async function getMemoryProfile(userId: string): Promise<MemoryProfile> {
  const { rows } = await pool.query<{ profile: MemoryProfile }>(
    `SELECT profile FROM memory_profiles WHERE user_id = $1`,
    [userId]
  );
  return rows[0]?.profile ?? EMPTY_PROFILE;
}

export async function upsertMemoryProfile(userId: string, profile: MemoryProfile): Promise<void> {
  await pool.query(
    `INSERT INTO memory_profiles (user_id, profile, updated_at) VALUES ($1, $2, now())
     ON CONFLICT (user_id) DO UPDATE SET profile = $2, updated_at = now()`,
    [userId, JSON.stringify(profile)]
  );
}
