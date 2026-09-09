import { env } from "../config/env.js";

/**
 * Embeddings for pgvector-based journal retrieval (PRD 13.3). Anthropic
 * doesn't offer an embeddings API, so this uses Voyage AI — Anthropic's
 * own recommended embeddings partner. Not called out in the original
 * architecture doc; flagging it here as the concrete choice.
 *
 * Model: voyage-3-lite (1024 dimensions — must match the `journal_entries.
 * embedding` column in the migration; changing models means a migration).
 */
export async function embed(text: string): Promise<number[]> {
  const response = await fetch("https://api.voyageai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.VOYAGE_API_KEY}`,
    },
    body: JSON.stringify({
      input: text,
      model: "voyage-3-lite",
      input_type: "document",
    }),
  });

  if (!response.ok) {
    throw new Error(`Voyage embeddings request failed: ${response.status}`);
  }

  const data = (await response.json()) as { data: { embedding: number[] }[] };
  return data.data[0].embedding;
}
