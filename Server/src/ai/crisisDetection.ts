import { completeChat, MODELS } from "./claude.js";
import { keywordCrisisMatch } from "./crisisKeywords.js";
import type { CompassMode } from "./prompts.js";

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
//
// This is a *rule*, not a pattern-matcher: earlier versions tried to
// enumerate example phrases to exclude, which only ever covers the exact
// wording already seen in a bug report and keeps missing new metaphorical
// phrasing (e.g. "it feels heavy, like it's weighing me down" to describe
// an urge). The rule below is meant to generalize: it asks whether the
// message states or clearly implies intent to end life / harm someone, or
// a present medical emergency — not whether the message "sounds intense."
const CLASSIFIER_SYSTEM = `You are a safety classifier for a gambling-recovery support app. \
The app's core exercise is "urge surfing": it deliberately prompts users to describe an urge \
to gamble in vivid, embodied, emotionally intense language — heaviness, pressure, being pulled, \
being consumed, wanting to escape the feeling, the urge "weighing them down" or "crushing" them. \
Intensity, distress, and dramatic metaphor are the EXPECTED, DESIRED output of that exercise. \
They are not, by themselves, evidence of anything else.

Classify a message as an ACUTE CRISIS only if it does at least one of these:
1. States or clearly implies a wish to die, not exist, or end their life ("I don't want to be \
here anymore", "I have no reason to keep going", "I want it to be over" in a life/suicide sense).
2. States or clearly implies intent to physically harm themselves or someone else.
3. Describes a present medical emergency (e.g. chest pain framed as "I think I'm having a heart \
attack", not simply feeling pressure or a racing heart as a body sensation).
4. Describes catastrophic, hopeless financial ruin from gambling in a way that reads as a person \
in danger right now, not simply worry or regret (e.g. "I lost everything and I don't see a way \
out" about their actual life circumstances).

Do NOT classify as crisis, no matter how intense the language:
- Descriptions of an urge/craving itself — heavy, crushing, overwhelming, consuming, unbearable, \
"weighing me down", pressure, a pulling or aching sensation — with no separate statement about \
wanting to die or harm anyone. This is the exercise working as designed.
- Ordinary physical sensations offered in response to a mindfulness prompt (racing heart, tight \
chest, shaky hands, knot in the stomach) with no separate statement of harm intent.
- General anxiety, frustration, shame, or self-criticism about gambling ("I hate myself for \
gambling again", "I'm so anxious right now").

If a message is genuinely ambiguous between an intense urge-surfing description and an actual \
statement about wanting to die or harm someone, bias toward true — missing a real crisis is far \
worse than a false alarm. But intensity or heaviness about the URGE ITSELF, with nothing said \
about ending life or self-harm, is not ambiguous: it is false.

Respond with EXACTLY one word: "true" or "false". Nothing else.`;

export async function checkCrisis(
  message: string,
  mode: CompassMode
): Promise<CrisisCheckResult> {
  // Layer 1: deterministic keyword match. Fast, free, easy to audit —
  // checked first so an obvious signal never waits on a network call.
  if (keywordCrisisMatch(message)) {
    return { isCrisis: true, source: "keyword" };
  }

  // Layer 2: LLM contextual pass. Either layer triggering is sufficient
  // (PRD Section 8) — this one exists specifically to catch what the
  // keyword layer would miss. The current exercise mode is passed in as
  // context so the classifier isn't judging an isolated sentence blind —
  // e.g. it knows "heavy, weighing me down" said during urge_surfing is
  // the exercise's own prompt working, not a new signal.
  const contextNote =
    mode === "urge_surfing"
      ? "[Context: this message was sent during a guided urge-surfing exercise.]\n"
      : "";

  const verdict = await completeChat({
    model: MODELS.haiku,
    system: [{ text: CLASSIFIER_SYSTEM, cache: true }],
    messages: [{ role: "user", content: `${contextNote}${message}` }],
    maxTokens: 5,
  });

  const isCrisis = verdict.trim().toLowerCase().startsWith("true");
  return { isCrisis, source: isCrisis ? "llm" : null };
}
