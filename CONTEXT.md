# Untilt — Domain Glossary

## Core Concept

Untilt is an iOS mindfulness app for people trying to quit gambling. It uses mindfulness techniques to interrupt urges at the moment they arise and supports long-term recovery through journaling, meditation, gamification, and an AI coaching persona.

---

## Glossary

**Compass**
The AI coaching persona embedded in Untilt. Has read access to the user's full history (urge events, journal entries, meditation completions, streak data). Operates in two modes:
- *Proactive*: surfaces a daily insight card on the home screen, referencing specific behavioral data and ending with an open coaching question.
- *Reactive*: responds in a chat interface when the user taps "Ask Compass"; talks users through urges, prompts journal entries, and provides crisis resources.

**Days Clean**
The count of days the user has not gambled. Displayed as the primary metric on the home screen.

**Journal Entry**
A user-authored record tied to their emotional and behavioral state. Three trigger types, in priority order:
1. *Urge-linked* (primary): created immediately after an Urge Event; Compass prompts with questions referencing the specific event.
2. *Daily check-in* (secondary): a scheduled prompt (morning or evening) where Compass asks 2–3 questions.
3. *Free-write* (tertiary): user-initiated via the Journal tab.
When opening the Journal tab, the user chooses between two modes: **Free-form** (blank canvas) or **Compass-prompted** (Compass leads with questions). A urge-linked Journal Entry holds an optional reference to the Urge Event that triggered it.

**Milestone**
A celebratory achievement earned for reaching key recovery markers — e.g., 7, 30, 90 days clean; completing a meditation streak; consistent journaling. Does not reset on a Slip.

**Mindful Gate**
An iOS Shortcuts-powered breathing interstitial that activates when the user attempts to open a gambling app. The primary acquisition hook for Untilt. Completes with a 2-minute box breathing exercise, then routes the user to the Untilt home screen or back to the original app. Setup is mandatory during onboarding — the user is walked through Shortcut installation step-by-step and must gate at least one gambling app before reaching the home screen.

**Recovery Journey**
An open-ended commitment to not gambling. There is no fixed duration or graduation point. Progress is tracked by Days Clean indefinitely. Milestones (7, 30, 60, 90 days, 6 months, 1 year, 2 years…) are celebrated as markers, not endpoints. The recovery ring's outer arc tracks progress toward the user's next milestone, not a fixed program length.

**Session (Meditation)**
A guided mindfulness exercise from the Untilt catalogue. Delivered as real audio/video content. Categorised by type (Quick Reset, Grounding, CBT-based, Focus, Deep Work, Recovery) and duration. Compass may surface 2–3 contextually relevant sessions for the user to choose from (e.g. "Would you like a 2, 5, or 10 minute reset?") rather than generating custom content.

**Slip**
A day on which the user abandoned the Mindful Gate (triggered it but did not complete the breathing exercise). Recorded automatically. Marked on the Soft Streak rather than resetting it. Triggers a Compass check-in.

**Soft Streak**
The Days Clean counter, modified to mark a Slip day rather than reset to zero. Preserves cumulative progress to reduce shame and all-or-nothing thinking.

**Savings Estimate**
A motivational metric showing how much money the user has saved by not gambling. Calculated automatically as `weeksClean × weeklySpend`, where `weeklySpend` is declared once during onboarding ("How much did you typically spend gambling per week?"). Optionally tracked toward a user-defined savings goal. Displayed in the hero row and recovery ring.

**Urge**
A felt impulse to gamble. Manifests technically as a Mindful Gate activation.

**Urge Event**
A recorded instance of the Mindful Gate being triggered. The primary data event in Untilt's behavioral model. Linked to Journal Entries and Compass insights.

---

**Resources Tab**
A curated static library with three sections, in order: (1) Crisis lines — 1-800-522-4700, text 988, always visible at top; (2) Therapy finder — links to licensed gambling counsellor directories (e.g. NCPG); (3) Educational reads — articles on gambling addiction, CBT techniques, how urges work. Content is static, maintained in-app. Compass can deep-link into this tab when a user is in distress.

**Progress Tab**
Displays the user's full recovery history as a visual story. Four sections in order: (1) Streak calendar — GitHub-contribution-graph style, each day coloured clean/slip/no-data; (2) Milestones earned — badges for days clean and consistency markers; (3) Savings growth sparkline — cumulative money saved over time; (4) Urge frequency trend — how often the Mindful Gate has fired over time, showing reduction.

**Onboarding Flow**
The mandatory sequence a new user completes before reaching the home screen. Five steps: (1) Welcome screen; (2) Sign in via Amazon Cognito (Hosted UI + PKCE); (3) Sobriety start date — "When did you last gamble?" — seeds Days Clean accurately; (4) Weekly spend declaration — seeds the Savings Estimate; (5) Mindful Gate setup — step-by-step Shortcuts installation with suggested gambling apps (DraftKings, FanDuel, etc.) to gate. User must gate at least one app before proceeding.

**Navigation**
Five tabs: Today, Meditations, Journal, Progress, Resources. Compass is not a tab — it is accessible from Today (proactive insight card + "Ask Compass" button) and from inside the Journal tab (as the Compass-prompted entry mode).

---

## Open Questions

