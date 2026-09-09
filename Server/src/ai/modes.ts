import { MODELS } from "./claude.js";
import type { CompassMode } from "./prompts.js";

export interface ModeConfig {
  model: string;
  maxTokens: number;
  turnCap: number | null; // null = no soft cap (urge surfing / journaling are naturally bounded)
}

export const MODE_CONFIG: Record<CompassMode, ModeConfig> = {
  // Sonnet: needs empathetic reliability + conversational pacing quality (PRD 13.1).
  urge_surfing: { model: MODELS.sonnet, maxTokens: 400, turnCap: null },
  journaling: { model: MODELS.sonnet, maxTokens: 400, turnCap: null },

  // Haiku + soft turn cap: the primary cost lever for the least naturally
  // bounded mode (PRD 7.3, 13.1). Target 15–20 turns; we use 18 as the midpoint.
  listening: { model: MODELS.haiku, maxTokens: 400, turnCap: 18 },
};
