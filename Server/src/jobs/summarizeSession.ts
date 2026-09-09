import { completeChat, MODELS } from "../ai/claude.js";
import { getSession } from "../db/repositories/sessions.js";
import { getMemoryProfile, upsertMemoryProfile, type MemoryProfile } from "../db/repositories/memoryProfile.js";

const SUMMARIZER_SYSTEM = `You update a compact JSON memory profile for a gambling-recovery \
coaching app, based on one conversation. You will be given the user's EXISTING profile and the \
NEW conversation. Merge — don't just overwrite. Keep it short: a few triggers, a few coping \
strategies, at most.

Respond with ONLY valid JSON matching exactly this shape, nothing else:
{"triggers": string[], "copingStrategies": string[], "pastCrisisFlags": boolean, "tonePreferences": string}`;

/**
 * Runs after a session ends (PRD 13.3): summarizes the conversation with a
 * cheap model call and merges it into the user's memory profile. Deliberately
 * off the live request path — see jobs/queue.ts for how this gets invoked
 * asynchronously.
 */
export async function summarizeSessionAndUpdateProfile(sessionId: string, userId: string): Promise<void> {
  const session = await getSession(sessionId, userId);
  if (!session || session.history.length === 0) return;

  const existingProfile = await getMemoryProfile(userId);
  const transcript = session.history.map((m) => `${m.role}: ${m.content}`).join("\n");

  const raw = await completeChat({
    model: MODELS.haiku,
    system: [{ text: SUMMARIZER_SYSTEM, cache: false }],
    messages: [
      {
        role: "user",
        content: `EXISTING PROFILE:\n${JSON.stringify(existingProfile)}\n\nNEW CONVERSATION (mode: ${session.mode}):\n${transcript}`,
      },
    ],
    maxTokens: 300,
  });

  try {
    const updated = JSON.parse(raw) as MemoryProfile;
    await upsertMemoryProfile(userId, updated);
  } catch (err) {
    // Don't let a malformed model response corrupt the profile — log and
    // skip this update rather than throwing, since this runs off the
    // request path with no one waiting on the result.
    console.error("summarizeSessionAndUpdateProfile: failed to parse model output", err, raw);
  }
}
