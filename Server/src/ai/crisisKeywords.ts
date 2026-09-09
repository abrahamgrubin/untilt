/**
 * Deterministic crisis-keyword layer (PRD Section 8).
 *
 * ⚠️ NOT CLINICALLY REVIEWED. This list is a starting-point draft only —
 * the PRD requires a clinical/expert advisor to review and sign off on
 * this exact list before launch (PRD Section 11). Keep this file small,
 * flat, and easy to hand to a reviewer — that's the point of a separate
 * deterministic layer: it should be trivial to audit and test in
 * isolation from the LLM-based pass in crisisDetection.ts.
 *
 * Tuning bias: false positives (over-triggering) are an accepted tradeoff
 * against false negatives (missing a real crisis) — PRD Section 8.
 *
 * Each pattern is matched case-insensitively against the raw user message.
 * Keep patterns broad/simple; the LLM pass (crisisDetection.ts) exists to
 * catch what these miss, not the other way around.
 */
export const CRISIS_KEYWORD_PATTERNS: RegExp[] = [
  // Suicidal ideation / self-harm
  /\bkill(ing)?\s+myself\b/i,
  /\bsuicid(e|al)\b/i,
  /\bend(ing)?\s+(it all|my life)\b/i,
  /\bdon'?t\s+want\s+to\s+(be here|live|exist)\s+anymore\b/i,
  /\bwant\s+to\s+die\b/i,
  /\bbetter\s+off\s+(dead|without me)\b/i,
  /\bhurt(ing)?\s+myself\b/i,
  /\bself[\s-]?harm\b/i,
  /\bcan'?t\s+go\s+on\b/i,
  /\bno\s+reason\s+to\s+live\b/i,

  // Severe financial distress tied to gambling
  /\blost\s+everything\b/i,
  /\bno\s+way\s+out\b/i,
  /\bcan'?t\s+pay\s+(my\s+)?(rent|mortgage|bills)\b/i,
  /\bgoing\s+to\s+lose\s+(my\s+)?(house|home|family)\b/i,
];

export function keywordCrisisMatch(message: string): boolean {
  return CRISIS_KEYWORD_PATTERNS.some((pattern) => pattern.test(message));
}
