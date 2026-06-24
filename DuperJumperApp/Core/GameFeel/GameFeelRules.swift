import Foundation

enum GameplayRiskState: String, CaseIterable, Hashable {
    case safe
    case heated
    case danger

    static func state(forRisk risk: Double) -> GameplayRiskState {
        switch risk {
        case ..<0.22:
            .safe
        case ..<0.42:
            .heated
        default:
            .danger
        }
    }
}

enum GameFeelRules {
    static func riskState(forRisk risk: Double) -> GameplayRiskState {
        GameplayRiskState.state(forRisk: risk)
    }

    static func riskState(forHeight height: Int) -> GameplayRiskState {
        GameplayRiskState.state(forRisk: DuperGameRules.baseRisk(for: height))
    }
}
