---
name: new-swiftui-view
description: Scaffold a new SwiftUI view or reusable component in the Untilt iOS app using UntiltTheme design tokens and the project's file conventions. Use when adding a screen, card, pill, sheet or other view under Untilt/Views/.
---

# New SwiftUI view for Untilt

Follow these steps to add a view that looks and reads like the rest of the app.

## 1. Pick the location

- Screens and shared components go in `Untilt/Views/`.
- Onboarding steps go in `Untilt/Views/Onboarding/`.
- One view per file, and the file name matches the type (`StreakBadgeView.swift` → `struct StreakBadgeView`).
- The Xcode project uses folder-synced groups, so a new file under `Untilt/` joins the app target automatically. Don't edit `project.pbxproj`.

Before writing anything, check whether an existing component already does the job, for example `MetricPillView`, `InsightCardView`, `RecoveryRingView` or `MeditationVideoShelfView`. Extend an existing view rather than duplicating it.

## 2. Match the file skeleton

```swift
import SwiftUI

// MARK: - Streak Badge View
// One or two lines on what this view is and where it appears.

struct StreakBadgeView: View {
    let title: String
    let days: Int
    var onTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s2) {
            Text(title)
                .font(UntiltTheme.Font.caption)
                .foregroundStyle(UntiltTheme.Color.muted)
            Text("\(days) days")
                .font(UntiltTheme.Font.heading2)
                .foregroundStyle(UntiltTheme.Color.slate)
        }
        .padding(UntiltTheme.Spacing.s4)
        .background(UntiltTheme.Color.white)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl)
                .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    StreakBadgeView(title: "Current streak", days: 23)
        .padding()
}
```

- Use 4-space indentation.
- Inputs are `let` properties. Callbacks are closures with a default of `{}`, as in `InsightCardView.onSupportTap`.
- Local UI state is `@State private var`.
- Every view gets a `#Preview` with realistic recovery-themed sample data. Keep sample copy warm and non-judgmental, and never use the word "relapse".

## 3. Use design tokens, not raw values

Everything comes from `Untilt/Theme/UntiltTheme.swift`:

| Need | Use |
|---|---|
| Colors | `UntiltTheme.Color.*`, e.g. `slate` (primary text), `muted` (secondary text), `lavender500/700`, `sage500/700`, `border`, `warmWhite` (screen background), `white` (card background) |
| Fonts | `UntiltTheme.Font.*`: `display`, `heading1–3`, `body`, `bodySmall`, `caption`, `overline`, `micro` |
| Spacing | `UntiltTheme.Spacing.s1` (4) … `s10` (40), on an 8pt grid |
| Corner radius | `UntiltTheme.Radius.sm/md/lg/xl/xxl/full`. Cards use `.xl` |
| Sizes | `UntiltTheme.Size.buttonHeight`, `iconContainerSm`, `navBarHeight`, etc. |

Don't write `Color(hex:)`, `.font(.system(size:))`, bare padding numbers or corner radii in new code. If a token you need doesn't exist, add it to `UntiltTheme` with a short comment. Don't inline the value.

## 4. Behavior rules

- Pure SwiftUI, no UIKit wrappers. (`SafariView` is the one existing exception.)
- Use async/await via `.task { }` for async work. Don't add new Combine publishers or subscribers.
- Don't force-unwrap.
- Present modals (chat, breathing, gate) with `.fullScreenCover`, matching `RootView`.
- Read SwiftData with `@Query` and write with `@Environment(\.modelContext)`. Don't create a new `ModelContainer`.
- If the view shows crisis resources, use 1-800-522-4700 and text 988, and match `ResourcesView`.

## 5. Check before finishing

- The file compiles in isolation (no references to types that don't exist).
- No raw color, font, spacing or radius values: `grep -nE 'Color\(hex|\.system\(size|padding\([0-9]|cornerRadius: [0-9]' <file>` should return nothing.
- The preview renders with the sample data.
