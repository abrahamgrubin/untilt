import { completeChat, MODELS } from "./claude.js";
import { keywordCrisisMatch } from "./crisisKeywords.js";

export type CrisisSource = "keyword" | "llm" | null;

export interface CrisisCheckResult {
  isCrisis: boolean;
  source: CrisisSource;
}

// Independent, low-cost contextual pass (PRD 13.1) — catches implicit/
// contextual signals the keyword layer misses (e.g. "I don't think I can
// do this anymore" with no single matching keyword). Kept as its own tiny
// prompt, deliberately decoupled from the main conversation's system
// prompt/history, so a signal can never get lost in a compressed context
// (PRD 13.3).
const CLASSIFIER_SYSTEM = `You are a safety classifier for a gambling-recovery support app. \
Given a single user message, decide whether it signals an acute crisis: \
suicidal ideation, self-harm, or severe financial distress that suggests the \
person may be in danger right now (e.g. "I lost everything and don't see a way out").

Bias toward saying yes when uncertain — missing a real crisis is far worse than \
a false alarm. Respond with EXACTLY one word: "true" or "false". Nothing else.`;

export async function checkCrisis(message: string): Promise<CrisisCheckResult> {
  // Layer 1: deterministic keyword match. Fast, free, easy to audit —
  // checked first so an obvious signal never waits on a network call.
  if (keywordCrisisMatch(message)) {
    return { isCrisis: true, source: "keyword" };
  }

  // Layer 2: LLM contextual pass. Either layer triggering is sufficient
  // (PRD Section 8) — this one exists specifically to catch what the
  // keyword layer would miss.
  const verdict = await completeChat({
    model: MODELS.haiku,
    system: [{ text: CLASSIFIER_SYSTEM, cache: true }],
    messages: [{ role: "user", content: message }],
    maxTokens: 5,
  });

  const isCrisis = verdict.trim().toLowerCase().startsWith("true");
  return { isCrisis, source: isCrisis ? "llm" : null };
}
