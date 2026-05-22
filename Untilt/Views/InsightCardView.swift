import SwiftUI

// MARK: - Insight Card View
// Daily personalised recovery insight. Sits below the hero row.
// Mirrors the Fitbit coaching card layout.

struct InsightCardView: View {
    let time: String
    let title: String
    let bodyText: String
    let bulletPoints: [String]
    let closingQuestion: String
    var onSupportTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Time stamp row
            HStack(spacing: UntiltTheme.Spacing.s1 + 2) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.lavender500)
                Text(time)
                    .font(UntiltTheme.Font.caption)
                    .foregroundStyle(UntiltTheme.Color.lavender500)
            }
            .padding(.bottom, UntiltTheme.Spacing.s2)

            // Title
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.slate)
                .lineSpacing(3)
                .padding(.bottom, UntiltTheme.Spacing.s3 - 2)

            // Body
            Text(bodyText)
                .font(UntiltTheme.Font.bodySmall)
                .foregroundStyle(UntiltTheme.Color.muted)
                .lineSpacing(4)
                .padding(.bottom, UntiltTheme.Spacing.s3 - 2)

            // Bullet points
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1 + 2) {
                ForEach(bulletPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: UntiltTheme.Spacing.s2) {
                        Circle()
                            .fill(UntiltTheme.Color.lavender500)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(point)
                            .font(UntiltTheme.Font.bodySmall)
                            .foregroundStyle(UntiltTheme.Color.slate)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(.bottom, UntiltTheme.Spacing.s3 - 2)

            // Divider
            Divider()
                .overlay(UntiltTheme.Color.border)
                .padding(.bottom, UntiltTheme.Spacing.s3 - 2)

            // Closing question
            Text(closingQuestion)
                .font(UntiltTheme.Font.bodySmall)
                .foregroundStyle(UntiltTheme.Color.muted)
                .italic()
                .lineSpacing(3)
        }
        .padding(UntiltTheme.Spacing.s4 + 2)
        .background(UntiltTheme.Color.white)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl)
                .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    InsightCardView(
        time: "Today's insight · 9:00 AM",
        title: "You resisted an urge during last night's game",
        bodyText: "You opened DraftKings at 8:43 PM but completed your meditation session and returned to the home screen — a significant shift from three weeks ago.",
        bulletPoints: [
            "Your longest urge-free streak this week was 51 hours.",
            "You have meditated every day this week — your most consistent week yet."
        ],
        closingQuestion: "Are you noticing a difference in how you feel on days when you meditate?"
    )
    .padding()
}//
//  InsightCardView.swift
//  Untilt
//
//  Created by Abraham Rubin on 5/11/26.
//

