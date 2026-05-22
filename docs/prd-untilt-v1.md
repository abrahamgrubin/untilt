# PRD — Untilt v1 (Beta)

## Problem Statement

People trying to quit gambling face a critical gap: the moment of highest relapse risk — when they reach for a gambling app — has no friction. Existing recovery apps are passive companions the user must remember to open. They don't intervene at the moment an urge fires. Users also lack a way to make sense of their behavioral patterns over time, or to access emotional support at the exact moment they need it.

## Solution

Untilt is an iOS mindfulness app that intercepts gambling urges at the moment they arise via an iOS Shortcuts-powered breathing interstitial (the Mindful Gate), then supports long-term recovery through journaling, guided meditation, gamification, and an AI coaching persona (Compass) powered by the Claude API.

The Mindful Gate is the acquisition hook: when the user tries to open a gambling app, they are routed through a 2-minute box breathing exercise before they can proceed. Completing it is an Urge Event (a win). Abandoning it marks a Slip. All behavioral data feeds Compass, which surfaces daily personalized insights and is available for real-time coaching conversations.

## User Stories

### Onboarding
1. As a new user, I want to sign in with Apple in one tap, so that I can start the app without filling out a form.
2. As a new user, I want to declare when I last gambled, so that my Days Clean count starts accurately.
3. As a new user, I want to declare my average weekly gambling spend, so that the app can automatically calculate money I've saved.
4. As a new user, I want to be walked through the Mindful Gate setup step-by-step, so that I don't need prior knowledge of iOS Shortcuts.
5. As a new user, I want to select which gambling apps to gate (with suggestions like DraftKings, FanDuel), so that the gate is active for the apps I actually use.
6. As a new user, I want the gate setup to be mandatory before I reach the home screen, so that the core feature is guaranteed to be working.

### Mindful Gate
7. As a user attempting to open a gambling app, I want to be automatically routed through a breathing exercise, so that I have a moment of pause before acting on an urge.
8. As a user completing the breathing exercise, I want to be routed to the Untilt home screen, so that I have support available immediately after resisting an urge.
9. As a user who abandons the breathing exercise, I want the app to record this as a Slip automatically, so that my history is honest without requiring self-reporting.
10. As a user who abandons the gate, I want Compass to follow up with a check-in, so that I have support even after a difficult moment.
11. As a user, I want each gate activation to be recorded as an Urge Event, so that I can see my urge patterns over time in the Progress tab.

### Compass — Proactive
12. As a user opening the Today tab, I want to see a daily insight card from Compass, so that I receive personalized coaching without having to ask for it.
13. As a user, I want Compass's insight to reference specific events from my recent history (urge events, meditation completions, journal entries), so that the insight feels relevant rather than generic.
14. As a user, I want the insight card to end with an open coaching question, so that I'm prompted to reflect rather than just consume information.

### Compass — Reactive
15. As a user mid-urge, I want to open a chat with Compass from the Today tab, so that I can talk through what I'm feeling in real time.
16. As a user, I want Compass to know my streak, recent urge events, and recent journal entries when I start a conversation, so that I don't have to explain my situation from scratch.
17. As a user in distress, I want Compass to offer me a curated choice of 2–3 meditation sessions (e.g. 2 min, 5 min, 10 min), so that I get immediate practical help.
18. As a user in crisis, I want Compass to surface crisis resources (hotlines, text lines) within the chat, so that I can get urgent help without leaving the app.

### Journal
19. As a user who just completed a Mindful Gate activation, I want Compass to immediately prompt me to journal about what I was feeling, so that I can process the urge while it's fresh.
20. As a user, I want the urge-linked journal prompt to reference the specific gate event, so that Compass's questions are contextually relevant.
21. As a user who wants to reflect on their day, I want to receive a daily check-in prompt (morning or evening) with 2–3 questions from Compass, so that I build a consistent journaling habit.
22. As a user who wants to write freely, I want to open the Journal tab and choose Free-form mode, so that I have a blank canvas without Compass's structure.
23. As a user who wants guidance, I want to choose Compass-prompted mode in the Journal tab, so that Compass leads me through questions when I don't know where to start.
24. As a user, I want to see a list of my past journal entries, so that I can reflect on my journey over time.

### Meditation
25. As a user, I want to browse a catalogue of guided meditation sessions categorised by type and duration, so that I can find something appropriate for my current state.
26. As a user, I want to filter sessions by duration (under 5 min, 5–10 min, 10–20 min, 20+ min), so that I can find something that fits my available time.
27. As a user, I want to play a guided audio/video session inside the app, so that I can complete a meditation without switching apps.
28. As a user, I want completed sessions to be recorded, so that my meditation history contributes to my Progress and Compass insights.
29. As a user talking to Compass, I want it to suggest 2–3 relevant sessions by duration rather than a generic recommendation, so that I make the choice that's right for me.

### Progress
30. As a user, I want to see a streak calendar showing each day as clean, slip, or no data, so that I can see my full journey at a glance.
31. As a user, I want to see the milestones I've earned (7 days, 30 days, 60 days, 90 days, 6 months, 1 year, etc.), so that I feel recognised for my progress.
32. As a user, I want to see a savings sparkline showing my cumulative money saved over time, so that I'm motivated by the growing financial benefit.
33. As a user, I want to see an urge frequency trend, so that I can see whether my urges are becoming less frequent over time.
34. As a user who has a Slip, I want my streak to mark the day rather than reset to zero, so that I'm not punished in a way that makes me want to give up.
35. As a user who reaches a milestone, I want to receive a celebratory milestone moment in the app, so that key achievements feel meaningful.

### Resources
36. As a user, I want to see crisis helplines (1-800-GAMBLER, 988) at the top of the Resources tab, so that urgent help is always one tap away.
37. As a user, I want links to find a licensed gambling counsellor or therapist, so that I can get professional support if I need it.
38. As a user, I want access to a curated set of educational articles about gambling addiction, urges, and CBT techniques, so that I can understand what I'm going through.

### General
39. As a user, I want my data to sync across my Apple devices via CloudKit, so that I don't lose my history if I switch devices.
40. As a user, I want to sign back in and restore my full history, so that reinstalling the app doesn't erase my progress.

---

## Implementation Decisions

### Data Layer
- **SwiftData + CloudKit** for persistence and sync. Authentication via Sign in with Apple.
- Core entities: `UserProfile` (sobriety start date, weekly spend, savings goal), `UrgeEvent` (timestamp, completed: Bool), `JournalEntry` (body, mode: urgeLinked/checkIn/freeWrite, optional UrgeEvent reference), `MeditationCompletion` (session ID, timestamp), `Milestone` (type, earnedDate).

### Deep Logic Modules (pure, no UI dependency)
- **StreakCalculator** — inputs: sobriety start date, array of UrgeEvents. Outputs: daysClean, slipDays, currentStreak, nextMilestone, progressToNextMilestone (0.0–1.0). The recovery ring's outer arc uses progressToNextMilestone, not a fixed 90-day denominator.
- **SavingsCalculator** — inputs: weeklySpend, sobriety start date. Outputs: totalSaved, optionally progress toward a user-defined savings goal.
- **CompassContextBuilder** — inputs: UserProfile, last N UrgeEvents, last N JournalEntries, recent MeditationCompletions. Output: a structured context string injected as the user-history block in every Claude API system prompt.
- **MilestoneEvaluator** — inputs: current daysClean, array of already-earned Milestones. Output: array of newly unlocked Milestones. Milestone thresholds: 7, 30, 60, 90 days, 6 months, 1 year, 2 years (extensible).

### Compass (Claude API)
- All Compass calls go through a `CompassService` that: (1) runs `CompassContextBuilder` to assemble user history, (2) prepends the Compass persona system prompt, (3) calls the Claude API, (4) returns the response.
- Two call sites: proactive (daily insight card, called on Today tab load) and reactive (chat messages).
- API key shipped with the app for beta; proxied via a server function before public launch.
- Proactive insight format: specific behavioral observation → interpretation → open coaching question (Fitbit-style pattern).

### Mindful Gate
- BoxBreathingView receives a completion callback and an abandonment callback.
- Completion → records UrgeEvent(completed: true), routes to home screen.
- Abandonment → records UrgeEvent(completed: false) = Slip, triggers Compass check-in notification.
- Shortcut passes return URL via `UserDefaults["returnAppURL"]`; cleared after use.

### Navigation
- Five tabs: Today, Meditations, Journal, Progress, Resources.
- Compass is not a tab — accessible from Today (insight card + "Ask Compass" button) and from inside the Journal tab (Compass-prompted mode).

### Onboarding
- Mandatory 5-step sequence before home screen: Welcome → Sign in with Apple → Sobriety date → Weekly spend → Mindful Gate setup.
- Gate setup includes step-by-step Shortcuts installation with a list of suggested gambling apps.
- User must gate at least one app before proceeding to home.

### Gamification
- Soft Streak: Days Clean counter marks slip days rather than resetting.
- Milestones: celebratory in-app moments at key thresholds. Not tied to Slip — milestones are permanent once earned.
- No points or XP system.

### Meditation Content
- Real audio/video files, created by the developer for beta.
- Hosted externally (e.g. S3/CDN); streamed in-app via AVPlayer or similar.
- Compass surfaces 2–3 curated options by duration — it does not generate custom content.

### Savings Estimate
- Calculated as `weeksClean × weeklySpend` from the declared onboarding value.
- Displayed in the hero row and as a sparkline in Progress.
- Optional: user sets a savings goal; savings ring tracks progress toward it.

---

## Testing Decisions

### What makes a good test
Tests should verify external behavior — given these inputs, what is the output — not implementation details. Do not test private methods or internal state. Tests should remain valid even if the internal algorithm changes, as long as the observable output is correct.

### Modules to test
All four deep logic modules will have unit tests:

- **StreakCalculatorTests** — test daysClean computation, slip day marking, streak continuity, next milestone selection, progress-to-next-milestone calculation. Edge cases: no urge events, all slips, single-day history, milestone boundary days.
- **SavingsCalculatorTests** — test savings amount for various weeklySpend values and sobriety durations. Edge cases: zero spend, fractional weeks, sobriety start = today.
- **CompassContextBuilderTests** — test that the output string contains the expected data points from the inputs, is well-formed, and handles empty histories gracefully (new user with no events).
- **MilestoneEvaluatorTests** — test that correct milestones are returned for each threshold, that already-earned milestones are not re-returned, and that multiple milestones earned simultaneously are all returned.

No prior test art exists in the codebase — these will be the first tests. Use Swift Testing (`@Test`, `#expect`) over XCTest where available (Xcode 16+).

---

## Out of Scope

- Paywall, subscription, or in-app purchase infrastructure (deferred until after beta)
- Google Sign-In or other OAuth providers (Apple ID only for beta)
- Server-side Compass proxy (API key ships with app for beta)
- Professional clinical review of meditation content (deferred to pre-public-launch)
- Android or web versions
- Social features (sharing streaks, community support)
- Integration with gambling platforms or financial accounts

---

## Further Notes

- The app targets people actively trying to quit gambling, not acute crisis users or long-term maintenance users in stable recovery.
- The Mindful Gate is the differentiating feature and the primary acquisition hook — it should be the first thing highlighted in any marketing or App Store description.
- Compass's tone must handle shame and distress sensitively. The Claude system prompt should explicitly instruct non-judgmental, trauma-informed language.
- The 90-day counter visible in the current prototype code is placeholder data. The Recovery Journey is open-ended; the outer recovery ring tracks progress toward the *next milestone*, not a fixed 90-day goal.
- All domain terminology is defined in `CONTEXT.md`. Architecture decisions are recorded in `docs/adr/`.
