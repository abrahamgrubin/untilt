import SwiftUI

// MARK: - Recovery Ring View
// Three concentric rings representing:
//   Outer  — Program progress (days into 90-day program)
//   Middle — Weekly meditation completion
//   Inner  — Savings goal progress

struct RecoveryRingView: View {
    let dayNumber: Int
    let programLength: Int
    let meditationProgress: Double   // 0.0 – 1.0
    let savingsProgress: Double      // 0.0 – 1.0

    private var programProgress: Double {
        min(Double(dayNumber) / Double(programLength), 1.0)
    }

    var body: some View {
        ZStack {
            // Outer ring — program progress (lavender500)
            RingShape(progress: programProgress,
                      ringRadius: 60,
                      lineWidth: 12,
                      trackColor: UntiltTheme.Color.lavender50,
                      fillColor: UntiltTheme.Color.lavender500)

            // Middle ring — meditation (sage500)
            RingShape(progress: meditationProgress,
                      ringRadius: 44,
                      lineWidth: 10,
                      trackColor: UntiltTheme.Color.sage50,
                      fillColor: UntiltTheme.Color.sage500)

            // Inner ring — savings (lavender700)
            RingShape(progress: savingsProgress,
                      ringRadius: 28,
                      lineWidth: 9,
                      trackColor: UntiltTheme.Color.lavender100,
                      fillColor: UntiltTheme.Color.lavender700)
//
//            // Centre label
//            VStack(spacing: 2) {
//                Text("Day")
//                    .font(UntiltTheme.Font.overline)
//                    .foregroundStyle(UntiltTheme.Color.muted)
//                Text("\(dayNumber)")
//                    .font(.system(size: 28, weight: .medium))
//                    .foregroundStyle(UntiltTheme.Color.slate)
//                Text("of \(programLength)")
//                    .font(UntiltTheme.Font.overline)
//                    .foregroundStyle(UntiltTheme.Color.lavender500)
//            }
        }
        .frame(width: 148, height: 148)
    }
}

// MARK: - Ring Shape
private struct RingShape: View {
    let progress: Double
    let ringRadius: CGFloat
    let lineWidth: CGFloat
    let trackColor: Color
    let fillColor: Color

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            // Fill
            Circle()
                .trim(from: 0, to: progress)
                .stroke(fillColor,
                        style: StrokeStyle(lineWidth: lineWidth,
                                           lineCap: .round))
                .frame(width: ringRadius * 2, height: ringRadius * 2)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
    }
}

#Preview {
    RecoveryRingView(
        dayNumber: 23,
        programLength: 90,
        meditationProgress: 0.65,
        savingsProgress: 0.46
    )
    .padding()
}//
//  RecoveryRingView.swift
//  Untilt
//
//  Created by Abraham Rubin on 5/11/26.
//

