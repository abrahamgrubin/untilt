import { z } from "zod";
import { completeChat, MODELS } from "./claude.js";
import { keywordCrisisMatch } from "./crisisKeywords.js";
import { CRISIS_RESOURCES } from "./crisisResources.js";
import { CRISIS_NOTE_BLOCK } from "./prompts.js";
import type { MemoryProfile } from "../db/repositories/memoryProfile.js";

// Today-tab daily insight (PRD user stories 12–14, PRD "Proactive insight
// format": specific behavioral observation → interpretation → open coaching
// question).
//
// The behavioral numbers (days clean, urge events, meditation) live in
// SwiftData on the phone, so the app sends a small numeric snapshot. We
// deliberately accept numbers and catalogue titles only, never free text
// like journal bodies: free text would need its own crisis-screening pass
// before it could go into a prompt, and the insight doesn't need it.

const DAY_MS = 24 * 60 * 60 * 1000;

export function isPlausibleLocalDate(localDate: string, now: Date = new Date()): boolean {
  const parsed = Date.parse(`${localDate}T00:00:00Z`);
  if (Number.isNaN(parsed)) return false;
  // Reject impossible dates like 2026-02-31, which Date.parse rolls over.
  if (new Date(parsed).toISOString().slice(0, 10) !== localDate) return false;
  const todayUtc = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.abs(parsed - todayUtc) <= DAY_MS;
}

const counts = z.object({
  resisted: z.number().int().min(0).max(1000),
  slipped: z.number().int().min(0).max(1000),
});

export const insightSnapshotSchema = z.object({
  /**
   * The user's local calendar date, YYYY-MM-DD. One insight per user per date.
   * Must be within a day of the server's UTC date (real time zones span
   * UTC-12 to UTC+14), so a modified client can't mint a new model call per
   * request by sending arbitrary dates.
   */
  localDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .refine(isPlausibleLocalDate, "localDate must be within one day of today"),
  daysClean: z.number().int().min(0).max(36500),
  /** Urge Events (Mindful Gate activations) in the last 7 days. */
  urgesLast7Days: counts,
  /** Same counts for the 7 days before that, so the insight can speak to a trend. */
  urgesPrior7Days: counts,
  /**
   * Hours since the most recent Urge Event, or null if there has never been one.
   * Missing is treated as null: Swift's JSONEncoder omits nil optionals.
   */
  hoursSinceLastUrge: z.number().min(0).max(24 * 36500).nullable().default(null),
  meditationLast7Days: z.object({
    sessions: z.number().int().min(0).max(1000),
    minutes: z.number().int().min(0).max(100000),
  }),
  /** Titles of up to 3 recent meditation sessions, from the app's own catalogue. */
  recentMeditationTitles: z.array(z.string().min(1).max(80)).max(3).default([]),
  /** Days clean at the next milestone (7, 30, 60, 90, ...), if known. */
  nextMilestoneDays: z.number().int().min(1).max(36500).nullable().default(null),
});

export type InsightSnapshot = z.infer<typeof insightSnapshotSchema>;

export const insightCardSchema = z.object({
  title: z.string().min(1).max(90),
  body: z.string().min(1).max(320),
  bullets: z.array(z.string().min(1).max(140)).max(2),
  question: z.string().min(1).max(180),
});

export type InsightCard = z.infer<typeof insightCardSchema>;
export type InsightKind = "insight" | "check_in";

export const INSIGHT_MODEL = MODELS.sonnet;
const INSIGHT_MAX_TOKENS = 400;

const INSIGHT_STRUCTURE = `Mode: Daily Insight (Today tab card).

Write one short daily insight card for this user from the activity summary you are given. \
Follow this shape:
1. title: one specific observation drawn from the numbers (e.g. a resisted urge, a meditation \
streak, fewer urges than last week). Plain, warm, under 80 characters.
2. body: one to three sentences interpreting what that might mean, framed around effort and \
progress, never judgment.
3. bullets: zero to two short supporting facts from the summary. Only use numbers that appear \
in the summary; never invent events, times, apps or amounts.
4. question: one open, gentle coaching question that invites reflection.

Rules:
- If there were slips, acknowledge them without blame and emphasize that progress is not erased.
- If there is little or no activity, keep it simple and encouraging; do not guess at why.
- Never use the word "relapse". Never give financial, medical or relationship advice.
- Do not mention this summary, the app's data, or that you are an AI.

Respond with ONLY a JSON object, no code fences, exactly this shape:
{"title": string, "body": string, "bullets": string[], "question": string}`;

export function buildInsightUserMessage(snapshot: InsightSnapshot, profile: MemoryProfile): string {
  const lines = [
    `Days clean: ${snapshot.daysClean}`,
    snapshot.nextMilestoneDays !== null
      ? `Next milestone: ${snapshot.nextMilestoneDays} days (${snapshot.nextMilestoneDays - snapshot.daysClean} to go)`
      : null,
    `Urges in the last 7 days: ${snapshot.urgesLast7Days.resisted} resisted, ${snapshot.urgesLast7Days.slipped} slips`,
    `Urges in the 7 days before that: ${snapshot.urgesPrior7Days.resisted} resisted, ${snapshot.urgesPrior7Days.slipped} slips`,
    snapshot.hoursSinceLastUrge !== null
      ? `Hours since the most recent urge: ${Math.round(snapshot.hoursSinceLastUrge)}`
      : `No urges recorded yet`,
    `Meditation in the last 7 days: ${snapshot.meditationLast7Days.sessions} sessions, ${snapshot.meditationLast7Days.minutes} minutes`,
    snapshot.recentMeditationTitles.length > 0
      ? `Recent meditation sessions: ${snapshot.recentMeditationTitles.join("; ")}`
      : null,
    profile.triggers.length > 0 ? `Known triggers (from past conversations): ${profile.triggers.join("; ")}` : null,
    profile.copingStrategies.length > 0
      ? `Coping strategies that have helped: ${profile.copingStrategies.join("; ")}`
      : null,
  ];
  return `Activity summary:\n${lines.filter((l): l is string => l !== null).join("\n")}`;
}

/**
 * Parses and validates the model's card. Returns undefined (so the caller
 * shows nothing new rather than something wrong) if the output isn't the
 * expected JSON, breaks a tone rule, or contains crisis language.
 */
export function parseInsightCard(raw: string): InsightCard | undefined {
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start === -1 || end <= start) return undefined;

  let json: unknown;
  try {
    json = JSON.parse(raw.slice(start, end + 1));
  } catch {
    return undefined;
  }

  const parsed = insightCardSchema.safeParse(json);
  if (!parsed.success) return undefined;

  const card = parsed.data;
  const allText = [card.title, card.body, card.question, ...card.bullets].join(" ");
  if (/\brelaps/i.test(allText)) return undefined;
  if (keywordCrisisMatch(allText)) return undefined;
  return card;
}

export async function generateInsight(
  snapshot: InsightSnapshot,
  profile: MemoryProfile
): Promise<InsightCard | undefined> {
  const raw = await completeChat({
    model: INSIGHT_MODEL,
    system: [CRISIS_NOTE_BLOCK, { text: INSIGHT_STRUCTURE, cache: true }],
    messages: [{ role: "user", content: buildInsightUserMessage(snapshot, profile) }],
    maxTokens: INSIGHT_MAX_TOKENS,
  });
  return parseInsightCard(raw);
}

/**
 * Fixed, non-generated card shown instead of a coaching insight when a
 * crisis was detected recently. A generated "you resisted 3 urges!" card
 * would read as tone-deaf right after someone reached out in crisis, and
 * this is exactly the kind of moment the architecture keeps deterministic.
 */
export function checkInCard(): InsightCard {
  return {
    title: "Checking in on you today",
    body:
      "The last few days may have been really hard. However today is going, " +
      "you don't have to carry it alone. Support is here whenever you want it.",
    bullets: CRISIS_RESOURCES.map((r) => `${r.name}: ${r.phone}`),
    question: "What would help you feel even a little more supported today?",
  };
}
