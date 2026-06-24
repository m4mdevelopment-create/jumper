import SwiftUI

struct GameRoundSummaryCard: View {
    let summary: GameRoundSummary
    let reduceMotion: Bool
    let tryAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summary.iconName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(summary.accent)
                    .frame(width: 38, height: 38)
                    .background(summary.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.title)
                        .font(DJTheme.labelFont(17))
                        .foregroundStyle(DJTheme.textPrimary)

                    Text(summary.insight)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(DJTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                RoundSummaryMetric(title: "Step", value: "\(summary.stepReached)", accent: DJTheme.electricCyan)
                RoundSummaryMetric(title: "Multiplier", value: summary.multiplierText, accent: DJTheme.pulseMagenta)
                RoundSummaryMetric(title: summary.pointsTitle, value: summary.pointsText, accent: summary.accent)
                RoundSummaryMetric(title: "Best", value: summary.bestComparison, accent: DJTheme.voltAmber)
            }

            Button(action: tryAgain) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(DuperButtonStyle(accent: DJTheme.electricCyan, reduceMotion: reduceMotion))
            .accessibilityIdentifier("game.tryAgain")
        }
        .neonCard(accent: summary.accent, isBright: true)
    }
}

struct GameRoundSummary: Hashable {
    let result: RoundResult
    let bestHeight: Int

    var stepReached: Int {
        result.highestStep
    }

    var title: String {
        switch result.outcome {
        case .banked:
            "Round Collected"
        case .slipped:
            "Round Failed"
        }
    }

    var iconName: String {
        switch result.outcome {
        case .banked:
            "checkmark.seal.fill"
        case .slipped:
            "xmark.circle.fill"
        }
    }

    var accent: Color {
        switch result.outcome {
        case .banked:
            DJTheme.signalMint
        case .slipped:
            DJTheme.riskRed
        }
    }

    var multiplierText: String {
        "\(result.multiplier.formatted(.number.precision(.fractionLength(2))))x"
    }

    var pointsTitle: String {
        switch result.outcome {
        case .banked:
            "Collected"
        case .slipped:
            "Lost"
        }
    }

    var pointsText: String {
        let points: Int
        switch result.outcome {
        case .banked:
            points = result.score
        case .slipped:
            points = result.lostPoints > 0
                ? result.lostPoints
                : GameProgress.potentialPoints(height: result.height, multiplier: result.multiplier)
        }

        return "\(points.formatted(.number)) pts"
    }

    var bestComparison: String {
        guard bestHeight > 0 else { return "First run" }

        if result.highestStep >= bestHeight {
            return "Best climb"
        }

        return "-\((bestHeight - result.highestStep).formatted(.number)) steps"
    }

    var insight: String {
        switch result.outcome {
        case .banked:
            return collectedInsight
        case .slipped:
            return failedInsight
        }
    }

    private var collectedInsight: String {
        if result.highestStep == 0 {
            return "No climb yet. Restart and land the first jump."
        }

        if result.highestStep >= bestHeight, bestHeight > 0 {
            return "Clean stop at the top of your current climb."
        }

        if GameFeelRules.riskState(forHeight: result.highestStep) == .danger {
            return "Good stop. The next step was already in danger."
        }

        if result.highestStep < 3 {
            return "Safe collect. Push one more step when rhythm feels clear."
        }

        return "Solid collect. Try to repeat that pace, then add one step."
    }

    private var failedInsight: String {
        if result.highestStep == 0 {
            return "Opening miss. Restart fast and take the first step clean."
        }

        if result.highestStep >= bestHeight, bestHeight > 0 {
            return "Peak attempt. Try collecting one step earlier next run."
        }

        if GameFeelRules.riskState(forHeight: result.highestStep) == .danger {
            return "The climb was in danger. Watch that state before pushing."
        }

        return "Near the heated zone. Reset quickly and rebuild the rhythm."
    }
}

private struct RoundSummaryMetric: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(DJTheme.labelFont(10))
                .foregroundStyle(DJTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(value)
                .font(DJTheme.monoFont(16, weight: .black))
                .foregroundStyle(DJTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(DJTheme.deepDeck.opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.44), lineWidth: 1)
        )
    }
}
