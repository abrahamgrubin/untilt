import SwiftUI

// MARK: - Resources View
// Static content: crisis lines → therapy finder → educational reads

struct ResourcesView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s6) {
                crisisSection
                therapySection
//                educationSection
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.top, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Size.navBarHeight + UntiltTheme.Spacing.s4)
        }
        .background(UntiltTheme.Color.warmWhite)
        .navigationTitle("Resources")
    }

    // MARK: Crisis Lines
    private var crisisSection: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {
            sectionHeader("CRISIS SUPPORT", systemImage: "exclamationmark.triangle")

            CrisisLineCard(
                name: "National Problem Gambling Helpline",
                detail: "Call or text — 24/7 confidential support",
                actionLabel: "1-800-522-4700",
                actionURL: URL(string: "tel:18005224700")!
            )
            CrisisLineCard(
                name: "988 Suicide & Crisis Lifeline",
                detail: "Text or call 988 for immediate support",
                actionLabel: "Text 988",
                actionURL: URL(string: "sms:988")!
            )
            CrisisLineCard(
                name: "Crisis Text Line",
                detail: "Text HOME to 741741 — free, 24/7",
                actionLabel: "Text HOME to 741741",
                actionURL: URL(string: "sms:741741&body=HOME")!
            )
        }
    }

    // MARK: Therapy Finder
    private var therapySection: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {
            sectionHeader("FIND A THERAPIST", systemImage: "person.2")

            ResourceLinkCard(
                title: "National Council on Problem Gambling",
                description: "Directory of certified gambling counsellors across the US",
                url: URL(string: "https://ipggc.org/directory/")!
            )
            ResourceLinkCard(
                title: "Gamblers Anonymous",
                description: "Find a local GA meeting or online group",
                url: URL(string: "https://www.gamblersanonymous.org/")!
            )
            ResourceLinkCard(
                title: "Psychology Today — Therapist Finder",
                description: "Search licensed therapists specialising in gambling addiction",
                url: URL(string: "https://www.psychologytoday.com/us/therapists/gambling")!
            )
        }
    }

    // MARK: Educational Reads
    private var educationSection: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {
            sectionHeader("UNDERSTANDING ADDICTION", systemImage: "book.pages")

            ResourceLinkCard(
                title: "How Gambling Affects the Brain",
                description: "Why gambling activates the same dopamine pathways as substances",
                url: URL(string: "https://www.ncpgambling.org/help-treatment/understanding-gambling-disorder/")!
            )
            ResourceLinkCard(
                title: "Cognitive Defusion — A CBT Technique",
                description: "How to create distance from urge-driving thoughts",
                url: URL(string: "https://positivepsychology.com/cognitive-defusion-techniques/")!
            )
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: UntiltTheme.Spacing.s2) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.lavender500)
            Text(title)
                .font(UntiltTheme.Font.overline)
                .foregroundStyle(UntiltTheme.Color.muted)
                .kerning(0.8)
        }
    }
}

// MARK: - Crisis Line Card
private struct CrisisLineCard: View {
    let name: String
    let detail: String
    let actionLabel: String
    let actionURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s2) {
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.slate)
            Text(detail)
                .font(UntiltTheme.Font.bodySmall)
                .foregroundStyle(UntiltTheme.Color.muted)
                .lineSpacing(3)
            Link(actionLabel, destination: actionURL)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UntiltTheme.Color.lavender700)
        }
        .padding(UntiltTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UntiltTheme.Color.warningBg)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                .stroke(UntiltTheme.Color.warningBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Resource Link Card
private struct ResourceLinkCard: View {
    let title: String
    let description: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(alignment: .center, spacing: UntiltTheme.Spacing.s3) {
                VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1 + 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(UntiltTheme.Color.slate)
                        .multilineTextAlignment(.leading)
                    Text(description)
                        .font(UntiltTheme.Font.bodySmall)
                        .foregroundStyle(UntiltTheme.Color.muted)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.lavender500)
            }
            .padding(UntiltTheme.Spacing.s4)
            .background(UntiltTheme.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                    .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ResourcesView()
        .padding(.bottom, UntiltTheme.Size.navBarHeight)
}
