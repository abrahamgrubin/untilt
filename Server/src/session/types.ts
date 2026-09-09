import type { CompassMode } from "../ai/prompts.js";
import type { ChatMessage } from "../ai/claude.js";

export interface CompassSession {
  id: string;
  userId: string;
  mode: CompassMode;
  history: ChatMessage[];
  turnCount: number;
  createdAt: number;
}
