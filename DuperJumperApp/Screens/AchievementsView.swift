import SwiftUI

struct AchievementsView: View {
    @Environment(DuperGameStore.self) private var store

    private let columns = [
        GridItem(.adaptive(minimum: 154), spacing: 10, alignment: .top)
    ]

    private var unlockedCount: Int {
        store.achievements.filter(\.isUnlocked).count
    }

    private var completionFraction: Double {
        guard !store.achievements.isEmpty else { return 0 }
        return Double(unlockedCount) / Double(store.achievements.count)
    }

    private var nextAchievement: Achievement? {
        store.achievements.first { !$0.isUnlocked }
    }

    private var isFirstRun: Bool {
        store.progress.totalJumps == 0
            && store.progress.totalRounds == 0
            && unlockedCount == 0
    }

    private var isComplete: Bool {
        !store.achievements.isEmpty && unlockedCount == store.achievements.count
    }

    var body: some View {
        DuperScreen(
            title: "Achievements",
            subtitle: "Milestones earned from local climbs, collected rounds, multiplier peaks, and comeback runs.",
            accent: DJTheme.pulseMagenta
        ) {
            VStack(alignment: .leading, spacing: 12) {
                AchievementSummaryCard(
                    unlockedCount: unlockedCount,
                    totalCount: store.achievements.count,
                    completionFraction: completionFraction,
                    nextHint: nextTargetHint
                )

                if isComplete {
                    AchievementStateBanner(
                        title: "Board Complete",
                        message: "Every local milestone is unlocked. Reset in Settings returns this board to a fresh run.",
                        symbolName: "checkmark.seal.fill",
                        accent: DJTheme.signalMint
                    )
                } else if isFirstRun {
                    AchievementStateBanner(
                        title: "First Jump Waiting",
                        message: "Start a round in Game and land one jump. This board will update from stored local stats.",
                        symbolName: "play.circle.fill",
                        accent: DJTheme.electricCyan
                    )
                }

                if store.achievements.isEmpty {
                    EmptyAchievementCard()
                } else {
                    achievementGrid
                }
            }
        }
    }

    private var achievementGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(store.achievements) { achievement in
                AchievementProgressCard(
                    achievement: achievement,
                    progressValue: store.achievementProgress(for: achievement)
                )
            }
        }
    }

    private var nextTargetHint: String {
        guard let nextAchievement else {
            return "All milestones are unlocked"
        }

        let progressValue = store.achievementProgress(for: nextAchievement)
        return "\(nextAchievement.title): \(progressText(for: nextAchievement, progressValue: progressValue))"
    }
}

private struct AchievementSummaryCard: View {
    let unlockedCount: Int
    let totalCount: Int
    let completionFraction: Double
    let nextHint: String

    private var isComplete: Bool {
        totalCount > 0 && unlockedCount == totalCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Milestone Board")
                        .font(DJTheme.labelFont(12))
                        .textCase(.uppercase)
                        .foregroundStyle(DJTheme.textSecondary)

                    Text("\(unlockedCount)/\(totalCount)")
                        .font(DJTheme.monoFont(34, weight: .black))
                        .foregroundStyle(DJTheme.textPrimary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.68)
                        .accessibilityLabel("\(unlockedCount) of \(totalCount) achievements unlocked")
                }

                Spacer(minLength: 8)

                AchievementBadge(
                    text: isComplete ? "Complete" : "Climbing",
                    symbolName: isComplete ? "checkmark.seal.fill" : "sparkles",
                    accent: isComplete ? DJTheme.signalMint : DJTheme.pulseMagenta,
                    filled: true
                )
            }

            AchievementMeter(
                fraction: completionFraction,
                accent: isComplete ? DJTheme.signalMint : DJTheme.pulseMagenta,
                accessibilityLabel: "Achievement completion",
                accessibilityValue: "\(unlockedCount) of \(totalCount) achievements unlocked"
            )

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isComplete ? "flag.checkered" : "target")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(isComplete ? DJTheme.signalMint : DJTheme.voltAmber)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isComplete ? "Status" : "Next Target")
                        .font(DJTheme.labelFont(11))
                        .textCase(.uppercase)
                        .foregroundStyle(DJTheme.textSecondary)

                    Text(nextHint)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(DJTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonCard(accent: isComplete ? DJTheme.signalMint : DJTheme.pulseMagenta, isBright: true)
        .accessibilityElement(children: .combine)
    }
}

private struct AchievementStateBanner: View {
    let title: String
    let message: String
    let symbolName: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DJTheme.labelFont(15))
                    .foregroundStyle(DJTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DJTheme.deepDeck.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.42), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyAchievementCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Achievements Yet")
                .font(DJTheme.labelFont(16))
                .foregroundStyle(DJTheme.textPrimary)

            Text("Local achievements will appear here when stored milestones are available.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(DJTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonCard(accent: DJTheme.pulseMagenta)
    }
}

private struct AchievementProgressCard: View {
    let achievement: Achievement
    let progressValue: Int

    @ScaledMetric(relativeTo: .body) private var iconBoxSize: CGFloat = 38

    private var cappedProgress: Int {
        min(progressValue, achievement.targetValue)
    }

    private var progressFraction: Double {
        guard achievement.targetValue > 0 else { return 1 }
        return min(Double(progressValue) / Double(achievement.targetValue), 1)
    }

    private var remainingValue: Int {
        max(achievement.targetValue - cappedProgress, 0)
    }

    private var accent: Color {
        achievement.isUnlocked ? DJTheme.signalMint : DJTheme.pulseMagenta
    }

    private var foreground: Color {
        achievement.isUnlocked ? DJTheme.textPrimary : DJTheme.textPrimary.opacity(0.88)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(achievement.isUnlocked ? 0.22 : 0.12))
                        .frame(width: iconBoxSize, height: iconBoxSize)

                    Image(systemName: achievement.symbolName)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                }
                .accessibilityHidden(true)

                Spacer(minLength: 4)

                Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(achievement.isUnlocked ? DJTheme.signalMint : DJTheme.textSecondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(achievement.title)
                    .font(DJTheme.labelFont(15))
                    .foregroundStyle(foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text(achievement.summary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                AchievementMeter(
                    fraction: progressFraction,
                    accent: accent,
                    accessibilityLabel: "\(achievement.title) progress",
                    accessibilityValue: progressText(for: achievement, progressValue: cappedProgress)
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 6) {
                        progressLabel
                        Spacer(minLength: 4)
                        AchievementBadge(
                            text: achievement.isUnlocked ? "Unlocked" : "\(remainingValue) left",
                            symbolName: achievement.isUnlocked ? "checkmark" : "arrow.up",
                            accent: accent,
                            filled: achievement.isUnlocked
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        progressLabel
                        AchievementBadge(
                            text: achievement.isUnlocked ? "Unlocked" : "\(remainingValue) left",
                            symbolName: achievement.isUnlocked ? "checkmark" : "arrow.up",
                            accent: accent,
                            filled: achievement.isUnlocked
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(achievement.isUnlocked ? DJTheme.panelBright.opacity(0.92) : DJTheme.panel.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(achievement.isUnlocked ? 0.70 : 0.34), lineWidth: 1)
        )
        .shadow(color: accent.opacity(achievement.isUnlocked ? 0.16 : 0.05), radius: achievement.isUnlocked ? 14 : 8, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), \(achievement.isUnlocked ? "unlocked" : "locked"), \(achievement.summary)")
        .accessibilityValue(progressText(for: achievement, progressValue: cappedProgress))
    }

    private var progressLabel: some View {
        Text(progressText(for: achievement, progressValue: cappedProgress))
            .font(DJTheme.monoFont(11, weight: .black))
            .foregroundStyle(DJTheme.textSecondary)
            .contentTransition(.numericText())
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AchievementMeter: View {
    let fraction: Double
    let accent: Color
    let accessibilityLabel: String
    let accessibilityValue: String

    private var normalizedFraction: Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DJTheme.line)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, DJTheme.electricCyan.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * CGFloat(normalizedFraction))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}

private struct AchievementBadge: View {
    let text: String
    let symbolName: String
    let accent: Color
    var filled = false

    var body: some View {
        Label(text, systemImage: symbolName)
            .font(DJTheme.labelFont(11))
            .foregroundStyle(filled ? DJTheme.void : accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(filled ? accent : accent.opacity(0.12), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func progressText(for achievement: Achievement, progressValue: Int) -> String {
    switch achievement.metric {
    case .bestMultiplierGainPercent:
        let currentMultiplier = 1.0 + Double(progressValue) / 100.0
        let targetMultiplier = 1.0 + Double(achievement.targetValue) / 100.0
        return "\(multiplierText(currentMultiplier)) of \(multiplierText(targetMultiplier))"
    default:
        return "\(progressValue) of \(achievement.targetValue)"
    }
}

private func multiplierText(_ value: Double) -> String {
    "\(value.formatted(.number.precision(.fractionLength(2))))x"
}

private extension Achievement {
    var symbolName: String {
        switch id {
        case "first-jump":
            "arrow.up.circle.fill"
        case "five-step-climb":
            "5.circle.fill"
        case "multiplier-spark":
            "bolt.circle.fill"
        case "safe-collector":
            "checkmark.seal.fill"
        case "comeback-round":
            "arrow.counterclockwise.circle.fill"
        case "tower-regular":
            "calendar.circle.fill"
        case "guide-explorer":
            "book.pages.fill"
        default:
            isUnlocked ? "checkmark.circle.fill" : "sparkles"
        }
    }
}

#Preview {
    AchievementsView()
        .environment(DuperGameStore.preview)
}
