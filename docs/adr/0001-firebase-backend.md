# ADR 0001 — SwiftData + CloudKit for Persistence and Auth

## Status
Accepted

## Context
Untilt requires cloud-persisted user data (Urge Events, Journal Entries, streak, meditation history). Multiple OAuth providers were considered for easy onboarding, but the added complexity of a custom backend outweighs the benefit. Apple ID covers the majority of the iOS user base and Sign in with Apple is a first-class onboarding experience.

## Decision
Use **SwiftData + CloudKit**:
- **Sign in with Apple** for authentication (Apple ID, no form required)
- **SwiftData** as the local data layer
- **CloudKit** for automatic cloud sync and backup via Apple's native integration

Compass AI calls go directly from the app to the LLM API (see ADR 0002). No custom backend required.

## Consequences
- Zero backend infrastructure to build or maintain.
- Data survives reinstalls and syncs across the user's Apple devices automatically.
- Auth is a single "Sign in with Apple" button — minimal onboarding friction.
- Users without an iCloud account lose cloud sync (edge case on iOS).
- Google Sign-In is not supported; accepted trade-off.
- LLM API key must be managed carefully — either shipped with the app (acceptable for MVP, not for production) or proxied through a lightweight server function later.
