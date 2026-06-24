import Foundation

#if DEBUG
struct GameBalanceSimulationReport: Hashable {
    let rounds: Int
    let averageSuccessfulJumps: Double
    let averageCollectedPoints: Double
    let collectRate: Double
    let failDistributionByStep: [Int: Int]

    var readableSummary: String {
        let failures = failDistributionByStep
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(8)
            .map { "step \($0.key): \($0.value)" }
            .joined(separator: ", ")

        return [
            "rounds: \(rounds)",
            "averageSuccessfulJumps: \(averageSuccessfulJumps.formatted(.number.precision(.fractionLength(2))))",
            "averageCollectedPoints: \(averageCollectedPoints.formatted(.number.precision(.fractionLength(0))))",
            "collectRate: \(collectRate.formatted(.percent.precision(.fractionLength(1))))",
            "failDistributionByStep: \(failures)"
        ].joined(separator: "\n")
    }
}

enum GameBalanceSimulator {
    struct Configuration: Hashable {
        var rounds = 10_000
        var collectRiskThreshold = 0.33
        var minimumCollectHeight = 3
        var seed: UInt64 = 0xD0A6_2026
    }

    static func run(configuration: Configuration = Configuration()) -> GameBalanceSimulationReport {
        var generator = SeededRandomNumberGenerator(seed: configuration.seed)
        var totalSuccessfulJumps = 0
        var totalCollectedPoints = 0
        var collectedRounds = 0
        var failDistribution: [Int: Int] = [:]

        for _ in 0..<max(configuration.rounds, 1) {
            var currentStep = 0
            var highestStep = 0
            var currentRunPoints = 0
            var currentMultiplier = DuperGameRules.startingMultiplier
            var roundMultiplierBonus = 0.0
            var activeBonuses: [RoundBonus] = []
            var shieldCharges = 0

            while true {
                if
                    currentStep >= configuration.minimumCollectHeight,
                    DuperGameRules.jumpRisk(currentStep: currentStep, activeBonuses: activeBonuses) >= configuration.collectRiskThreshold
                {
                    totalSuccessfulJumps += currentStep
                    totalCollectedPoints += currentRunPoints
                    collectedRounds += 1
                    break
                }

                let energy = DuperGameRules.jumpEnergy(currentStep: currentStep, activeBonuses: activeBonuses)
                let roll = Double.random(in: 0..<1, using: &generator)

                if roll <= energy {
                    let landedStep = currentStep + 1
                    let eventRoll = Double.random(in: 0..<1, using: &generator)
                    let event = DuperGameRules.event(
                        for: landedStep,
                        roll: eventRoll,
                        hasShield: shieldCharges > 0
                    )

                    activeBonuses = DuperGameRules.activeBonuses(afterConsuming: activeBonuses)
                    if event.kind == .boost {
                        roundMultiplierBonus += event.multiplierBonus
                    }
                    activeBonuses = DuperGameRules.bonuses(afterApplying: event, to: activeBonuses)
                    if event.grantsShield {
                        shieldCharges = min(DuperGameRules.maxShieldCharges, shieldCharges + 1)
                    }

                    currentStep = landedStep
                    highestStep = max(highestStep, landedStep)
                    currentMultiplier = DuperGameRules.effectiveMultiplier(
                        for: currentStep,
                        roundMultiplierBonus: roundMultiplierBonus,
                        activeBonuses: activeBonuses
                    )
                    currentRunPoints += DuperGameRules.pointsForLandedStep(
                        step: landedStep,
                        multiplier: currentMultiplier,
                        event: event
                    )
                } else {
                    if shieldCharges > 0 {
                        shieldCharges -= 1
                        activeBonuses = DuperGameRules.activeBonuses(afterConsuming: activeBonuses)
                        currentMultiplier = DuperGameRules.effectiveMultiplier(
                            for: currentStep,
                            roundMultiplierBonus: roundMultiplierBonus,
                            activeBonuses: activeBonuses
                        )
                    } else {
                        totalSuccessfulJumps += highestStep
                        failDistribution[highestStep, default: 0] += 1
                        break
                    }
                }
            }
        }

        let rounds = max(configuration.rounds, 1)

        return GameBalanceSimulationReport(
            rounds: rounds,
            averageSuccessfulJumps: Double(totalSuccessfulJumps) / Double(rounds),
            averageCollectedPoints: Double(totalCollectedPoints) / Double(rounds),
            collectRate: Double(collectedRounds) / Double(rounds),
            failDistributionByStep: failDistribution
        )
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
#endif
