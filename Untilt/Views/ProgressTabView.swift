import SwiftUI
import SwiftData
import Charts

// MARK: - Day status for streak calendar
private enum DayStatus {
    case beforeStart    // neutral — before sobriety start
    case cleanQuiet     // light lavender — no urge events, quietly clean
    case cleanResisted  // full lavender — resisted at least one urge
    case slip           // warning — had a slip
}

// MARK: - Chart data models
private struct SavingsPoint: Identifiable {
    let id = UUID()
    let week: Int
    let amount: Double
}

private struct UrgeBarDatum: Identifiable {
    let id = UUID()
    let weekLabel: String
    let count: Int
    let type: String    // "Resisted" or "Slipped"
}

// MARK: - Milestone helpers (scoped to Progress tab)
private extension MilestoneTypeRaw {
    var daysRequired: Int {
        switch self {
        case .day7:   return 7
        case .day30:  return 30
        case .day60:  return 60
        case .day90:  return 90
        case .month6: return 180
        case .year1:  return 365
        case .year2:  return 730
        }
    }

    var badgeIcon: String {
        switch self {
        case .day7:   return "leaf.fill"
        case .day30:  return "star.fill"
        case .day60:  return "bolt.fill"
        case .day90:  return "sparkles"
        case .month6: return "medal.fill"
        case .year1:  return "trophy.fill"
        case .year2:  return "crown.fill"
        }
    }
}

private let orderedMilestones: [MilestoneTypeRaw] = [
    .day7, .day30, .day60, .day90, .month6, .year1, .year2
]

// MARK: - Progress Tab
struct ProgressTabView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \UrgeEvent.timestamp) private var urgeEvents: [UrgeEvent]
    @Query(sort: \MilestoneRecord.earnedDate) private var earnedMilestones: [MilestoneRecord]

    private var profile: UserProfile? { profiles.first }

    private var dayNumber: Int {
        guard let profile else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day],
            from: cal.startOfDay(for: profile.sobrietyStartDate),
            to: cal.startOfDay(for: Date())).day ?? 0
    }

    private var earnedTypes: Set<MilestoneTypeRaw> {
        Set(earnedMilestones.map(\.type))
    }

    private var nextMilestone: MilestoneTypeRaw? {
        orderedMilestones.first { !earnedTypes.contains($0) }
    }

    // MARK: Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                pageHeader
                    .padding(.horizontal, UntiltTheme.Spacing.s5)
                    .padding(.top, UntiltTheme.Spacing.s5)
                    .padding(.bottom, UntiltTheme.Spacing.s4)

                VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s4) {
                    streakCalendarCard
                    milestonesCard
                    if (profile?.weeklySpend ?? 0) > 0 { savingsCard }
                    urgeFrequencyCard
                }
                .padding(.horizontal, UntiltTheme.Spacing.s5)
                .padding(.bottom, UntiltTheme.Size.navBarHeight + UntiltTheme.Spacing.s4)
            }
        }
        .background(UntiltTheme.Color.warmWhite)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Page Header
    private var pageHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Progress")
                    .font(UntiltTheme.Font.heading1)
                    .foregroundStyle(UntiltTheme.Color.slate)
                Text("Day \(dayNumber) of your journey")
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.muted)
            }
            Spacer()
        }
    }

    // MARK: - Streak Calendar Card
    private var streakCalendarCard: some View {
        ProgressCard(title: "Streak Calendar", subtitle: "Last 10 weeks") {
            streakGrid
                .padding(.top, UntiltTheme.Spacing.s1)
            streakLegend
        }
    }

    private var streakGrid: some View {
        let days = computeDayData()
        // Group into 10 week-columns of 7 days each
        let weeks = stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0 ..< min($0 + 7, days.count)])
        }

        return HStack(alignment: .top, spacing: 0) {
            // Day-of-week label column
            VStack(alignment: .trailing, spacing: 3) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { lbl in
                    Text(lbl)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(UntiltTheme.Color.muted)
                        .frame(width: 12, height: 24)
                }
            }
            .padding(.trailing, 5)

            // Week columns
            HStack(alignment: .top, spacing: 3) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 3) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            DayCell(
                                status: day.status,
                                isToday: Calendar.current.isDateInToday(day.date)
                            )
                        }
                        // Pad short last week
                        if week.count < 7 {
                            ForEach(0 ..< (7 - week.count), id: \.self) { _ in
                                Color.clear.frame(width: 24, height: 24)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakLegend: some View {
        HStack(spacing: UntiltTheme.Spacing.s3) {
            Spacer()
            legendDot(UntiltTheme.Color.warmGray, "Before")
            legendDot(UntiltTheme.Color.lavender100, "Clean")
            legendDot(UntiltTheme.Color.lavender700, "Resisted")
            legendDot(UntiltTheme.Color.warning.opacity(0.75), "Slip")
        }
        .padding(.top, UntiltTheme.Spacing.s2)
    }

    @ViewBuilder
    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(UntiltTheme.Font.micro)
                .foregroundStyle(UntiltTheme.Color.muted)
        }
    }

    // MARK: - Milestones Card
    private var milestonesCard: some View {
        ProgressCard(
            title: "Milestones",
            subtitle: "\(earnedMilestones.count) of \(orderedMilestones.count) earned"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UntiltTheme.Spacing.s3) {
                    ForEach(orderedMilestones, id: \.rawValue) { milestone in
                        MilestoneBadgeView(
                            milestone: milestone,
                            isEarned: earnedTypes.contains(milestone),
                            isNext: milestone == nextMilestone,
                            dayNumber: dayNumber
                        )
                    }
                }
                .padding(.vertical, UntiltTheme.Spacing.s1)
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Savings Sparkline Card
    private var savingsCard: some View {
        let data = computeSavingsData()
        let totalSaved = data.last?.amount ?? 0

        return ProgressCard(title: "Savings Estimate", subtitle: "Based on your weekly spend") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "$%.0f", totalSaved))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(UntiltTheme.Color.sage700)
                Text("saved so far")
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .padding(.bottom, 2)
            }

            Chart(data) { pt in
                AreaMark(
                    x: .value("Week", pt.week),
                    y: .value("Saved", pt.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [UntiltTheme.Color.sage500.opacity(0.25), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Week", pt.week),
                    y: .value("Saved", pt.amount)
                )
                .foregroundStyle(UntiltTheme.Color.sage700)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 80)
            .padding(.top, UntiltTheme.Spacing.s1)

            Text("Week 0 → Week \(max(0, dayNumber / 7))")
                .font(UntiltTheme.Font.micro)
                .foregroundStyle(UntiltTheme.Color.muted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Urge Frequency Card
    private var urgeFrequencyCard: some View {
        ProgressCard(title: "Urge History", subtitle: "Last 8 weeks — stacked by outcome") {
            if urgeEvents.isEmpty {
                Text("No urge events logged yet.\nThey'll appear here as you use the gate.")
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, UntiltTheme.Spacing.s5)
            } else {
                let barData = computeUrgeBarData()

                Chart(barData) { datum in
                    BarMark(
                        x: .value("Week", datum.weekLabel),
                        y: .value("Count", datum.count)
                    )
                    .foregroundStyle(by: .value("Outcome", datum.type))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale([
                    "Resisted": UntiltTheme.Color.lavender500,
                    "Slipped":  UntiltTheme.Color.warning.opacity(0.8)
                ])
                .chartLegend(position: .bottom, spacing: UntiltTheme.Spacing.s2) {
                    HStack(spacing: UntiltTheme.Spacing.s3) {
                        legendDot(UntiltTheme.Color.lavender500, "Resisted")
                        legendDot(UntiltTheme.Color.warning.opacity(0.8), "Slipped")
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
                .frame(height: 130)
            }
        }
    }

    // MARK: - Data computation

    private func computeDayData() -> [(date: Date, status: DayStatus)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDate = profile.map { cal.startOfDay(for: $0.sobrietyStartDate) } ?? today

        let eventsByDay = Dictionary(grouping: urgeEvents) {
            cal.startOfDay(for: $0.timestamp)
        }

        return (0 ..< 70).map { i in
            let date = cal.date(byAdding: .day, value: -(69 - i), to: today)!
            guard date >= startDate else { return (date, .beforeStart) }
            let events = eventsByDay[date] ?? []
            if events.isEmpty { return (date, .cleanQuiet) }
            return (date, events.contains { !$0.completed } ? .slip : .cleanResisted)
        }
    }

    private func computeSavingsData() -> [SavingsPoint] {
        guard let profile else { return [] }
        let totalWeeks = max(1, dayNumber / 7 + 1)
        return (0 ... totalWeeks).map { w in
            SavingsPoint(week: w, amount: Double(w) * profile.weeklySpend)
        }
    }

    private func computeUrgeBarData() -> [UrgeBarDatum] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        return (0 ..< 8).reversed().flatMap { weeksAgo -> [UrgeBarDatum] in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: today),
                  let weekEnd   = cal.date(byAdding: .day, value: 7, to: weekStart)
            else { return [] }

            let events = urgeEvents.filter {
                let d = cal.startOfDay(for: $0.timestamp)
                return d >= weekStart && d < weekEnd
            }
            guard !events.isEmpty else { return [] }

            let label = weeksAgo == 0 ? "Now" : "\(weeksAgo)w"
            let resisted = events.filter { $0.completed }.count
            let slipped  = events.filter { !$0.completed }.count

            var results: [UrgeBarDatum] = []
            if resisted > 0 { results.append(UrgeBarDatum(weekLabel: label, count: resisted, type: "Resisted")) }
            if slipped  > 0 { results.append(UrgeBarDatum(weekLabel: label, count: slipped,  type: "Slipped")) }
            return results
        }
    }
}

// MARK: - Day Cell
private struct DayCell: View {
    let status: DayStatus
    let isToday: Bool

    private var fill: Color {
        switch status {
        case .beforeStart:   return UntiltTheme.Color.warmGray
        case .cleanQuiet:    return UntiltTheme.Color.lavender100
        case .cleanResisted: return UntiltTheme.Color.lavender700
        case .slip:          return UntiltTheme.Color.warning.opacity(0.75)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fill)
            .frame(width: 24, height: 24)
            .overlay(
                isToday ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(UntiltTheme.Color.slate, lineWidth: 1.5)
                : nil
            )
    }
}

// MARK: - Milestone Badge
private struct MilestoneBadgeView: View {
    let milestone: MilestoneTypeRaw
    let isEarned: Bool
    let isNext: Bool
    let dayNumber: Int

    private var progressFraction: Double {
        guard !isEarned, isNext else { return 0 }
        return min(1, Double(dayNumber) / Double(milestone.daysRequired))
    }

    var body: some View {
        VStack(spacing: UntiltTheme.Spacing.s2) {
            ZStack {
                // Base circle
                Circle()
                    .fill(isEarned ? UntiltTheme.Color.lavender50 : UntiltTheme.Color.warmGray)
                    .frame(width: 54, height: 54)

                // Progress arc for the "next" milestone
                if isNext && !isEarned {
                    Circle()
                        .trim(from: 0, to: progressFraction)
                        .stroke(
                            UntiltTheme.Color.lavender500.opacity(0.5),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                }

                Image(systemName: milestone.badgeIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isEarned ? UntiltTheme.Color.lavender700 : UntiltTheme.Color.muted
                    )
            }

            Text(milestone.displayName)
                .font(UntiltTheme.Font.micro)
                .foregroundStyle(isEarned ? UntiltTheme.Color.slate : UntiltTheme.Color.muted)
                .lineLimit(1)

            if isEarned {
                Text("Earned")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.lavender700)
            } else if isNext {
                Text("\(milestone.daysRequired - dayNumber)d left")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.muted)
            } else {
                Text("\(milestone.daysRequired)d")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.muted.opacity(0.6))
            }
        }
        .frame(width: 66)
    }
}

// MARK: - Progress Card Container
private struct ProgressCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(UntiltTheme.Font.overline)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .kerning(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(UntiltTheme.Font.micro)
                        .foregroundStyle(UntiltTheme.Color.muted.opacity(0.8))
                }
            }
            content()
        }
        .padding(UntiltTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UntiltTheme.Color.white)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl)
                .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(for: [UserProfile.self, UrgeEvent.self, MilestoneRecord.self], inMemory: true)
}
