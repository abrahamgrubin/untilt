# Untilt — Project Context for Claude

Untilt is an iOS app that helps people quit gambling. It combines behavioral tracking, mindfulness tools, an AI recovery coach ("Compass"), and a "Mindful Gate" that intercepts gambling-app launches via an iOS Shortcut.

Product terms (Slip, Soft Streak, Urge Event, Days Clean, etc.) are defined in the domain glossary:

@CONTEXT.md

## Repo Layout

- `Untilt/` — iOS app source (SwiftUI). `Untilt.xcodeproj` uses folder-synced groups, so new files under `Untilt/` join the target automatically.
- `Server/` — Node/TypeScript backend for Compass (Express, Postgres, SQS worker). Persona prompts, mode config and crisis detection live in `Server/src/ai/`.
- `Infra/` — Terraform for AWS (VPC, ALB, ECS/Fargate, RDS, SQS, Cognito, ECR, GitHub OIDC). `terraform.tfvars` is local config; never print or commit secrets from it.
- `Logic/` — `UntiltLogic` Swift package (pure, testable logic + `UntiltLogicTests`); run with `swift test` from `Logic/`.
- `docs/` — architecture doc and ADRs (`docs/adr/`).
- `.claude/` — project skills (`.claude/skills/`) and subagents (`.claude/agents/`).

## Architecture

- **Pure SwiftUI + SwiftData** — no UIKit wrappers, no Combine (use async/await instead)
- **Persistence**: SwiftData with CloudKit sync (`cloudKitDatabase: .automatic`)
- **Auth**: Cognito Hosted UI via `ASWebAuthenticationSession` + PKCE (see `AuthService`)
- **Backend**: REST API at `api.pinenoodle.com` behind an ALB, authenticated with Cognito access tokens (see `BackendService`)
- **AI chat**: `CompassConversation` (in `CompassService.swift`) talks to the backend, which calls Claude and runs crisis detection server-side (see `docs/adr/0003-backend-migration.md`). The app no longer calls the Claude API directly.
- **Singletons**: Services use the `static let shared` pattern (`AuthService.shared`, `BackendService.shared`, `NotificationRouter.shared`). Exception: `CompassConversation` is one instance per chat presentation, not a singleton, because it holds a session ID.

## Project Structure

```
Untilt/
├── Models/
│   ├── Data/               # SwiftData @Model classes
│   │   ├── UserProfile.swift
│   │   ├── UrgeEvent.swift
│   │   ├── JournalEntry.swift
│   │   ├── MeditationCompletion.swift
│   │   └── MilestoneRecord.swift
│   └── MeditationSession.swift   # Static meditation catalogue
├── Services/
│   ├── AuthService.swift          # Cognito PKCE auth
│   ├── BackendService.swift       # REST + SSE streaming to backend
│   ├── CompassService.swift       # CompassConversation: chat state via backend (SSE)
│   └── NotificationRouter.swift   # Local notification deep-link routing
├── Theme/
│   └── UntiltTheme.swift          # Design tokens (colors, fonts, spacing, radii)
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── GateSetupView.swift
│   │   └── SignInView.swift
│   ├── HomeView.swift             # "Today" tab — daily insight, quick actions
│   ├── CompassChatView.swift      # AI coach chat (reactive mode)
│   ├── BoxBreathingView.swift     # Guided box breathing exercise
│   ├── MindfulGateView.swift      # Gambling-app intercept screen
│   ├── JournalView.swift          # Journal entries list + compose
│   ├── MeditationsTabView.swift   # Meditation catalogue
│   ├── ProgressTabView.swift      # Stats & milestones
│   ├── ResourcesView.swift        # Crisis resources & links
│   ├── RootView.swift             # 5-tab shell (Today, Meditations, Journal, Progress, Resources)
│   ├── ContentView.swift          # Onboarding gate → RootView
│   └── ...                        # Supporting views (InsightCard, RecoveryRing, MetricPill, etc.)
├── UntiltApp.swift                # @main — ModelContainer, deep-link routing, notification delegate
└── Assets.xcassets
```

## Key Conventions

### Code Style
- **4-space indentation**
- PascalCase for types, camelCase for properties/methods
- `@State private var` for SwiftUI state, `let` for constants
- Avoid Combine — use `async`/`await` instead
- Avoid force-unwrapping; leverage Swift's type system

### Design System (`UntiltTheme`)
Always use design tokens from `UntiltTheme` instead of raw values:
- **Colors**: `UntiltTheme.Color.lavender700`, `.slate`, `.warmWhite`, `.muted`, `.border`, etc.
- **Fonts**: `UntiltTheme.Font.heading1`, `.body`, `.bodySmall`, `.caption`, `.micro`, etc.
- **Spacing**: `UntiltTheme.Spacing.s1` (4pt) through `.s10` (40pt) — 8pt base grid
- **Radii**: `UntiltTheme.Radius.sm` (8), `.md` (12), `.lg` (16), `.xl` (20), `.xxl` (24)
- **Sizes**: `UntiltTheme.Size.buttonHeight` (52), `.navBarHeight` (68), etc.

### Navigation
- `RootView` uses a custom `ZStack`-based tab bar (not `TabView`)
- Modal screens (Compass chat, box breathing, gate) use `.fullScreenCover`
- The Mindful Gate is triggered via `untilt://gate` deep link from iOS Shortcuts

### Data Models (SwiftData)
- `UserProfile` — sobriety start date, weekly spend, gated apps, gate config status
- `UrgeEvent` — timestamp + completed (true = resisted, false = slip)
- `JournalEntry` — body, mode (urge_linked / check_in / free_write), optional linked UrgeEvent
- `MeditationCompletion` — session ID/title, duration, timestamp
- `MilestoneRecord` — recovery milestones

### Compass (AI Coach)
- System prompt defines persona: calm, warm, non-clinical, never says "relapse"
- Responses are 2–4 sentences unless the user asks for more
- When Compass mentions "box breathing" / "breathing exercise" etc., the chat view detects it client-side and shows an inline button to launch `BoxBreathingView`
- Crisis resources (1-800-522-4700, text 988) are surfaced when the user signals acute distress

### Notifications
- `NotificationRouter` is the `UNUserNotificationCenterDelegate`, registered at app launch
- Tapping a notification with `deepLink: "compass"` opens Compass with the notification body as `slipContext`

## Sensitive Files
- `APIKeys.swift` — contains the Claude API key (beta only, not committed)
- `AuthService.swift` — Cognito client ID is a public OAuth client identifier (not a secret)
- Keychain storage for tokens is in `AuthService.swift` (`KeychainStore` private enum)
