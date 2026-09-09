import Anthropic from "@anthropic-ai/sdk";
import { env } from "../config/env.js";

export const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });

// PRD Section 13.1: Sonnet for urge surfing / journaling (empathetic
// reliability, not frontier reasoning); Haiku for listening (cost lever,
// paired with session bounding) and for the crisis-screening classifier.
export const MODELS = {
  sonnet: "claude-sonnet-4-5",
  haiku: "claude-haiku-4-5-20251001",
} as const;

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

/**
 * A system prompt as an ordered list of blocks. The first block should be
 * the large, static, mode-independent block (persona, tone, crisis
 * protocol reference, urge-surfing structure if applicable) marked cached
 * — PRD 13.3: reused on every call, cuts cost ~90% after the first hit
 * and reduces latency, which matters most for urge surfing.
 */
export interface SystemBlock {
  text: string;
  cache: boolean;
}

function toAnthropicSystem(blocks: SystemBlock[]): Anthropic.Messages.TextBlockParam[] {
  return blocks.map((block) => ({
    type: "text",
    text: block.text,
    ...(block.cache ? { cache_control: { type: "ephemeral" as const } } : {}),
  }));
}

/**
 * Streams a Claude response, invoking `onToken` for each text delta.
 * Returns the full assembled text once the stream completes, so callers
 * can persist it after streaming finishes.
 */
export async function streamChat(params: {
  model: string;
  system: SystemBlock[];
  messages: ChatMessage[];
  maxTokens: number;
  onToken: (token: string) => void;
}): Promise<string> {
  const stream = anthropic.messages.stream({
    model: params.model,
    max_tokens: params.maxTokens,
    system: toAnthropicSystem(params.system),
    messages: params.messages,
  });

  stream.on("text", (token) => params.onToken(token));

  const finalMessage = await stream.finalMessage();
  const textBlock = finalMessage.content.find((block) => block.type === "text");
  return textBlock?.type === "text" ? textBlock.text : "";
}

/**
 * Single non-streaming call, used for the crisis classifier and the
 * async memory-profile summarization job (step 3) — short, structured
 * outputs where streaming has no UX benefit.
 */
export async function completeChat(params: {
  model: string;
  system: SystemBlock[];
  messages: ChatMessage[];
  maxTokens: number;
}): Promise<string> {
  const message = await anthropic.messages.create({
    model: params.model,
    max_tokens: params.maxTokens,
    system: toAnthropicSystem(params.system),
    messages: params.messages,
  });
  const textBlock = message.content.find((block) => block.type === "text");
  return textBlock?.type === "text" ? textBlock.text : "";
}
