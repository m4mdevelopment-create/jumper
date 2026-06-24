import SwiftUI

extension GameplayRiskState {
    var title: String {
        switch self {
        case .safe:
            "Safe"
        case .heated:
            "Heated"
        case .danger:
            "Danger"
        }
    }

    var iconName: String {
        switch self {
        case .safe:
            "shield.checkered"
        case .heated:
            "flame.fill"
        case .danger:
            "exclamationmark.triangle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .safe:
            DJTheme.signalMint
        case .heated:
            DJTheme.voltAmber
        case .danger:
            DJTheme.riskRed
        }
    }

    var nextJumpMessage: String {
        switch self {
        case .safe:
            "Safe rhythm. Build the climb cleanly."
        case .heated:
            "Heated now. Each jump can swing the round."
        case .danger:
            "Danger step. Collect soon or commit fast."
        }
    }
}

extension StepEvent {
    var feedbackTitle: String {
        switch self {
        case .normal:
            "Clean Jump"
        default:
            title
        }
    }

    var feedbackMessage: String {
        switch kind {
        case .normal:
            "Rhythm stayed clean."
        case .boost:
            "Boost added \(pointsBonus.formatted(.number)) points to the climb."
        case .safe:
            "Safe step calmed the next jump."
        case .shield:
            "Shield is ready for one save."
        case .surge:
            "Surge changes the next jump tempo."
        }
    }
}

struct GameplayRiskBadge: View {
    let state: GameplayRiskState

    var body: some View {
        Label(state.title, systemImage: state.iconName)
            .font(DJTheme.labelFont(11))
            .foregroundStyle(state.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(state.accent.opacity(0.14), in: Capsule())
            .accessibilityLabel("\(state.title) risk state")
    }
}
