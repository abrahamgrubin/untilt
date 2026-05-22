import SwiftUI

// MARK: - Metric Pill View
// Pill-shaped stat card used in the home screen hero row.
// Matches the Fitbit-inspired pill design from the style guide.

struct MetricPillView: View {
    let icon: String        // SF Symbol name
    let label: String
    let value: String
    let pillColor: PillColor

    enum PillColor {
        case lavender, sage, purple

        var background: Color {
            switch self {
            case .lavender: return UntiltTheme.Color.lavender50
            case .sage:     return UntiltTheme.Color.sage50
            case .purple:   return UntiltTheme.Color.lavender50
            }
        }

        var foreground: Color {
            switch self {
            case .lavender: return UntiltTheme.Color.lavender700
            case .sage:     return UntiltTheme.Color.sage700
            case .purple:   return UntiltTheme.Color.lavender500
            }
        }

        var iconBackground: Color {
            switch self {
            case .lavender: return UntiltTheme.Color.lavender50
            case .sage:     return UntiltTheme.Color.sage50
            case .purple:   return UntiltTheme.Color.lavender100
            }
        }
    }

    var body: some View {
        HStack(spacing: UntiltTheme.Spacing.s3) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(pillColor.iconBackground)
                    .frame(width: UntiltTheme.Size.iconContainerSm,
                           height: UntiltTheme.Size.iconContainerSm)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(pillColor.foreground)
            }

            // Text
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(UntiltTheme.Font.overline)
                    .foregroundStyle(pillColor.foreground)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(pillColor.foreground)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, UntiltTheme.Spacing.s3)
        .padding(.vertical, UntiltTheme.Spacing.s3 - 2)
        .frame(minHeight: 52)
        .background(pillColor.background)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 10) {
        MetricPillView(icon: "checkmark.seal",
                       label: "Days clean",
                       value: "23",
                       pillColor: .lavender)
        MetricPillView(icon: "dollarsign.circle",
                       label: "Saved",
                       value: "$1,840",
                       pillColor: .sage)
        MetricPillView(icon: "brain.head.profile",
                       label: "Mins meditating this week",
                       value: "47 min",
                       pillColor: .purple)
    }
    .padding()
}//
//  MetricPillView.swift
//  Untilt
//
//  Created by Abraham Rubin on 5/11/26.
//

