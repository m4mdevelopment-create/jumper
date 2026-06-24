import Foundation

enum StepEventKind: String, CaseIterable, Codable, Hashable {
    case normal
    case boost
    case safe
    case shield
    case surge

    var title: String {
        switch self {
        case .normal:
            "Normal Step"
        case .boost:
            "Boost Step"
        case .safe:
            "Safe Step"
        case .shield:
            "Shield Step"
        case .surge:
            "Surge Step"
        }
    }
}

struct StepEvent: Codable, Hashable {
    var kind: StepEventKind
    var pointsBonus: Int
    var multiplierBonus: Double
    var riskReduction: Double
    var grantsShield: Bool
    var surgeMultiplier: Double
    var duration: Int

    var title: String {
        kind.title
    }

    var isBonus: Bool {
        kind != .normal
    }

    static let normal = StepEvent(
        kind: .normal,
        pointsBonus: 0,
        multiplierBonus: 0,
        riskReduction: 0,
        grantsShield: false,
        surgeMultiplier: 0,
        duration: 0
    )
}

enum RoundBonusKind: String, Codable, Hashable {
    case saferNextJump
    case surgeMultiplier

    var title: String {
        switch self {
        case .saferNextJump:
            "Safer Next Jump"
        case .surgeMultiplier:
            "Surge Multiplier"
        }
    }
}

struct RoundBonus: Identifiable, Codable, Hashable {
    var kind: RoundBonusKind
    var remainingJumps: Int
    var riskReduction: Double
    var multiplierBonus: Double

    var id: String {
        kind.rawValue
    }

    var title: String {
        kind.title
    }
}

enum RoundActionOutcomeKind: String, Codable, Hashable {
    case landed
    case landedWithBonus
    case nearMiss
    case shieldSaved
    case failed
    case collected
}

struct JumpOutcomeContext: Equatable {
    var step: Int
    var highestStep: Int
    var multiplier: Double
    var potentialPoints: Int
    var pointsDelta: Int
    var energy: Double
    var risk: Double
    var event: StepEvent
    var activeBonuses: [RoundBonus]
    var shieldCharges: Int
    var lostPoints: Int
    var collectedPoints: Int

    var shieldAvailable: Bool {
        shieldCharges > 0
    }
}

enum JumpAttemptOutcome: Equatable {
    case landed(JumpOutcomeContext)
    case landedWithBonus(JumpOutcomeContext)
    case nearMiss(JumpOutcomeContext)
    case shieldSaved(JumpOutcomeContext)
    case failed(JumpOutcomeContext)
    case collected(JumpOutcomeContext)

    var kind: RoundActionOutcomeKind {
        switch self {
        case .landed:
            .landed
        case .landedWithBonus:
            .landedWithBonus
        case .nearMiss:
            .nearMiss
        case .shieldSaved:
            .shieldSaved
        case .failed:
            .failed
        case .collected:
            .collected
        }
    }

    var context: JumpOutcomeContext {
        switch self {
        case let .landed(context),
             let .landedWithBonus(context),
             let .nearMiss(context),
             let .shieldSaved(context),
             let .failed(context),
             let .collected(context):
            context
        }
    }
}

enum DuperGameRules {
    static let startingMultiplier = 1.0
    static let maxShieldCharges = 1

    static func baseMultiplier(for step: Int) -> Double {
        let step = max(step, 0)

        switch step {
        case 0:
            return startingMultiplier
        case 1...3:
            return 1.0 + Double(step) * 0.22
        case 4...8:
            return 1.66 + Double(step - 3) * 0.28
        default:
            let highStep = Double(step - 8)
            return 3.06 + highStep * 0.42 + highStep * highStep * 0.025
        }
    }

    static func effectiveMultiplier(
        for step: Int,
        roundMultiplierBonus: Double,
        activeBonuses: [RoundBonus]
    ) -> Double {
        let surgeBonus = activeBonuses.reduce(0.0) { partial, bonus in
            partial + max(bonus.multiplierBonus, 0)
        }

        return baseMultiplier(for: step) + max(roundMultiplierBonus, 0) + surgeBonus
    }

    static func baseRisk(for currentStep: Int) -> Double {
        let step = max(currentStep, 0)

        switch step {
        case 0...2:
            return 0.05 + Double(step) * 0.025
        case 3...7:
            return 0.13 + Double(step - 3) * 0.045
        case 8...13:
            return 0.36 + Double(step - 8) * 0.055
        default:
            return min(0.74, 0.66 + Double(step - 14) * 0.02)
        }
    }

    static func jumpRisk(currentStep: Int, activeBonuses: [RoundBonus]) -> Double {
        let riskReduction = activeBonuses.reduce(0.0) { partial, bonus in
            partial + max(bonus.riskReduction, 0)
        }

        return min(max(baseRisk(for: currentStep) - min(riskReduction, 0.24), 0.03), 0.78)
    }

    static func jumpEnergy(currentStep: Int, activeBonuses: [RoundBonus]) -> Double {
        1.0 - jumpRisk(currentStep: currentStep, activeBonuses: activeBonuses)
    }

    static func stepBasePoints(for step: Int) -> Int {
        let step = max(step, 1)
        let middleLift = max(step - 4, 0) * 18
        let highLift = max(step - 9, 0) * 30

        return 90 + step * 26 + middleLift + highLift
    }

    static func pointsForLandedStep(step: Int, multiplier: Double, event: StepEvent) -> Int {
        let basePoints = Double(stepBasePoints(for: step)) * multiplier
        return max(0, Int(basePoints.rounded()) + event.pointsBonus)
    }

    static func projectedPotentialPoints(height: Int, multiplier: Double) -> Int {
        guard height > 0 else { return 0 }

        let averageMultiplier = max(1.0, (startingMultiplier + multiplier) / 2.0)
        let rawPoints = (1...height).reduce(0) { partial, step in
            partial + Int((Double(stepBasePoints(for: step)) * averageMultiplier).rounded())
        }

        return max(0, rawPoints)
    }

    static func isNearMiss(energy: Double, roll: Double) -> Bool {
        let risk = 1.0 - energy
        let window = min(max(0.055 + risk * 0.12, 0.055), 0.12)

        return roll <= energy && energy - roll <= window
    }

    static func event(for landedStep: Int, roll rawRoll: Double, hasShield: Bool) -> StepEvent {
        let roll = min(max(rawRoll, 0), 0.999_999)

        switch landedStep {
        case ...1:
            if roll < 0.18 {
                return boostEvent(for: landedStep, multiplierBonus: 0.12, pointScale: 0.45)
            }
            return .normal
        case 2...4:
            if roll < 0.18 {
                return boostEvent(for: landedStep, multiplierBonus: 0.14, pointScale: 0.5)
            }
            if roll < 0.30 {
                return safeEvent(reduction: 0.14)
            }
            if !hasShield && roll < 0.38 {
                return shieldEvent()
            }
            return .normal
        case 5...8:
            if roll < 0.16 {
                return boostEvent(for: landedStep, multiplierBonus: 0.18, pointScale: 0.56)
            }
            if roll < 0.31 {
                return safeEvent(reduction: 0.16)
            }
            if !hasShield && roll < 0.41 {
                return shieldEvent()
            }
            if roll < 0.52 {
                return surgeEvent(multiplier: 0.5, duration: 1)
            }
            return .normal
        default:
            if roll < 0.14 {
                return boostEvent(for: landedStep, multiplierBonus: 0.22, pointScale: 0.62)
            }
            if roll < 0.25 {
                return safeEvent(reduction: 0.18)
            }
            if !hasShield && roll < 0.34 {
                return shieldEvent()
            }
            if roll < 0.50 {
                return surgeEvent(multiplier: 0.65, duration: 1)
            }
            return .normal
        }
    }

    static func activeBonuses(afterConsuming bonuses: [RoundBonus]) -> [RoundBonus] {
        bonuses.compactMap { bonus in
            let remainingJumps = bonus.remainingJumps - 1
            guard remainingJumps > 0 else { return nil }

            var updatedBonus = bonus
            updatedBonus.remainingJumps = remainingJumps
            return updatedBonus
        }
    }

    static func bonuses(afterApplying event: StepEvent, to bonuses: [RoundBonus]) -> [RoundBonus] {
        var updatedBonuses = bonuses

        switch event.kind {
        case .safe:
            updatedBonuses.removeAll { $0.kind == .saferNextJump }
            updatedBonuses.append(
                RoundBonus(
                    kind: .saferNextJump,
                    remainingJumps: max(event.duration, 1),
                    riskReduction: event.riskReduction,
                    multiplierBonus: 0
                )
            )
        case .surge:
            updatedBonuses.removeAll { $0.kind == .surgeMultiplier }
            updatedBonuses.append(
                RoundBonus(
                    kind: .surgeMultiplier,
                    remainingJumps: max(event.duration, 1),
                    riskReduction: 0,
                    multiplierBonus: event.surgeMultiplier
                )
            )
        case .normal, .boost, .shield:
            break
        }

        return updatedBonuses
    }

    private static func boostEvent(
        for step: Int,
        multiplierBonus: Double,
        pointScale: Double
    ) -> StepEvent {
        StepEvent(
            kind: .boost,
            pointsBonus: Int((Double(stepBasePoints(for: step)) * pointScale).rounded()),
            multiplierBonus: multiplierBonus,
            riskReduction: 0,
            grantsShield: false,
            surgeMultiplier: 0,
            duration: 0
        )
    }

    private static func safeEvent(reduction: Double) -> StepEvent {
        StepEvent(
            kind: .safe,
            pointsBonus: 0,
            multiplierBonus: 0,
            riskReduction: reduction,
            grantsShield: false,
            surgeMultiplier: 0,
            duration: 1
        )
    }

    private static func shieldEvent() -> StepEvent {
        StepEvent(
            kind: .shield,
            pointsBonus: 0,
            multiplierBonus: 0,
            riskReduction: 0,
            grantsShield: true,
            surgeMultiplier: 0,
            duration: 0
        )
    }

    private static func surgeEvent(multiplier: Double, duration: Int) -> StepEvent {
        StepEvent(
            kind: .surge,
            pointsBonus: 0,
            multiplierBonus: 0,
            riskReduction: 0,
            grantsShield: false,
            surgeMultiplier: multiplier,
            duration: duration
        )
    }
}
