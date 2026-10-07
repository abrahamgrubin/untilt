import SwiftUI

// MARK: - Compass Consent
// App Store Guideline 5.1.2(i): before any personal data goes to a
// third-party AI, say what is sent and to whom, and get permission. Compass
// chats and the Today-tab insight both go to Anthropic's Claude via the
// Untilt server, so neither runs until the user agrees here. They can turn
// it off again in Settings.
enum CompassConsent {
    static let storageKey = "compass_ai_consent_v1"
}

/// Explains what Compass sends to Anthropic and asks for permission.
/// Shown in place of the chat until the user agrees.
struct CompassConsentView: View {
    var onAgree: () -> Void
    var onDecline: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s5) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(UntiltTheme.Color.lavender700)
                    .frame(maxWidth: .infinity)
                    .padding(.top, UntiltTheme.Spacing.s8)

                Text("Before you talk with Compass")
                    .font(UntiltTheme.Font.heading2)
                    .foregroundStyle(UntiltTheme.Color.slate)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s4) {
                    point(
                        icon: "sparkles",
                        title: "Compass is an AI coach",
                        text: "Replies are written by Claude, an AI model made by Anthropic."
                    )
                    point(
                        icon: "arrow.up.message",
                        title: "What gets sent",
                        text: "Your messages to Compass; short notes Compass keeps about past chats, like your triggers, what helps, and whether a chat involved a crisis; and, for your daily insight, activity like days clean, urge counts and recent meditation sessions. These go to Anthropic through Untilt's server to write replies, check each message for signs of crisis, and keep Compass's notes up to date. Conversations and notes are stored on Untilt's servers (Supabase and Render) until you delete them."
                    )
                    point(
                        icon: "lock",
                        title: "What doesn't",
                        text: "Untilt doesn't send your email address to Anthropic. Under its commercial terms, Anthropic doesn't use these conversations to train its models and keeps them only for a limited time."
                    )
                    point(
                        icon: "cross.case",
                        title: "Not a substitute for care",
                        text: "Compass isn't a therapist or medical service. If you're in crisis, reach a person now:"
                    )
                    crisisLinks
                }

                Link("Read the Privacy Policy", destination: AppConfig.privacyPolicyURL)
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.lavender700)
                    .frame(maxWidth: .infinity)

                Text("You can turn Compass off anytime in Settings.")
                    .font(UntiltTheme.Font.caption)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                VStack(spacing: UntiltTheme.Spacing.s3) {
                    Button(action: onAgree) {
                        Text("I agree, turn on Compass")
                            .font(UntiltTheme.Font.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: UntiltTheme.Size.buttonHeight)
                            .background(UntiltTheme.Color.lavender700)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
                    }
                    Button(action: onDecline) {
                        Text("Not now")
                            .font(UntiltTheme.Font.bodySmall)
                            .foregroundStyle(UntiltTheme.Color.lavender700)
                    }
                }
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Spacing.s8)
        }
        .background(UntiltTheme.Color.warmWhite)
    }

    /// Tappable, so someone in distress can reach help from this screen
    /// without agreeing to anything (the slip notification can land here).
    private var crisisLinks: some View {
        VStack(spacing: UntiltTheme.Spacing.s2) {
            crisisLink("Call 1-800-522-4700", icon: "phone", url: "tel:18005224700")
            crisisLink("Text 988", icon: "message", url: "sms:988")
        }
        .padding(.leading, UntiltTheme.Size.iconLg + UntiltTheme.Spacing.s3)
    }

    private func crisisLink(_ label: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(label, systemImage: icon)
                .font(UntiltTheme.Font.bodySmall.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, UntiltTheme.Spacing.s3)
                .frame(height: 44)
                .foregroundStyle(UntiltTheme.Color.slate)
                .background(UntiltTheme.Color.warningBg)
                .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: UntiltTheme.Radius.md)
                        .stroke(UntiltTheme.Color.warningBorder, lineWidth: 0.5)
                )
        }
    }

    private func point(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: UntiltTheme.Spacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.lavender700)
                .frame(width: UntiltTheme.Size.iconLg)
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1) {
                Text(title)
                    .font(UntiltTheme.Font.heading3)
                    .foregroundStyle(UntiltTheme.Color.slate)
                Text(text)
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    CompassConsentView(onAgree: {}, onDecline: {})
}
