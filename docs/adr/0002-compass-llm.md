# ADR 0002 — Claude API for Compass

## Status
Accepted

## Context
Compass needs to interpret behavioral data (urge events, journal entries, streak), generate daily proactive insights, and hold empathetic coaching conversations with users in emotional distress. Fitbit's AI coach (Google Gemini) was the reference design, but its model choice reflects Google ownership, not a best-in-class selection.

## Decision
Use the **Claude API (Anthropic)** to power Compass.

Both modes use structured LLM prompts:
- *Proactive*: a prompt injecting the user's recent history generates the daily insight card.
- *Reactive*: a persistent conversation thread with Compass persona system prompt and user history context block.

## Consequences
- Claude's conversational tone is well-suited to sensitive recovery contexts (shame, relapse, urge distress).
- The Fitbit-style pattern (specific observation → interpretation → open coaching question) is implemented as a prompt design pattern, not a model feature — portable to any model if needed.
- API key must be protected; acceptable to ship with the app for MVP, but should be moved to a server-side proxy before public release.
- Costs scale with usage — context window size per request (user history injection) is the main cost driver.
