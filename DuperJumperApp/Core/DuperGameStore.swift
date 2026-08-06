import Foundation
import Observation

@MainActor
@Observable
final class DuperGameStore {
    var selectedTab: DuperTab = .game
    private(set) var progress: GameProgress
    private(set) var recentResults: [RoundResult]
    private(set) var achievements: [Achievement]
    private(set) var guideArticles: [GuideArticle]
    private(set) var localProgressResetRevision = 0
    var settings: AppSettings

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let randomValue: () -> Double
    private static let storageKey = "duperjumper.local.state.v1"

    init(
        defaults: UserDefaults = .standard,
        randomValue: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.defaults = defaults
        self.randomValue = randomValue

        if
            let data = defaults.data(forKey: Self.storageKey),
            let storedState = try? JSONDecoder().decode(StoredGameState.self, from: data)
        {
            progress = storedState.progress
            recentResults = storedState.recentResults
            achievements = DuperGameStore.mergedAchievements(with: storedState.achievements)
            guideArticles = DuperGameStore.mergedGuideArticles(with: storedState.guideArticles)
            settings = storedState.settings
        } else {
            let initialState = StoredGameState.initial
            progress = initialState.progress
            recentResults = initialState.recentResults
            achievements = initialState.achievements
            guideArticles = initialState.guideArticles
            settings = initialState.settings
        }

        refreshAchievements(persistAfterUpdate: true)
    }

    var guideReads: Int {
        guideArticles.filter(\.isRead).count
    }

    var currentScorePreview: Int {
        currentPotentialPoints
    }

    var currentStep: Int {
        progress.currentHeight
    }

    var activeRoundBonuses: [RoundBonus] {
        progress.activeBonuses
    }

    var isShieldAvailable: Bool {
        progress.shieldCharges > 0
    }

    var lastStepEvent: StepEvent? {
        progress.lastStepEvent
    }

    var lastActionOutcome: RoundActionOutcomeKind? {
        progress.lastActionOutcome
    }

    var currentPotentialPoints: Int {
        progress.currentRunPoints
    }

    var currentJumpEnergy: Double {
        DuperGameRules.jumpEnergy(
            currentStep: progress.currentHeight,
            activeBonuses: progress.activeBonuses
        )
    }

    var currentJumpRisk: Double {
        DuperGameRules.jumpRisk(
            currentStep: progress.currentHeight,
            activeBonuses: progress.activeBonuses
        )
    }

    var latestRoundOutcome: RoundOutcome? {
        guard !progress.isRoundActive else { return nil }
        return recentResults.first?.outcome
    }

    @discardableResult
    func startRound() -> Bool {
        guard !progress.isRoundActive else { return false }

        progress.activeRoundID = UUID()
        progress.currentHeight = 0
        progress.currentMultiplier = DuperGameRules.startingMultiplier
        progress.currentRunPoints = 0
        progress.highestRoundStep = 0
        progress.roundMultiplierBonus = 0
        progress.activeBonuses = []
        progress.shieldCharges = 0
        progress.lastStepEvent = nil
        progress.lastActionOutcome = nil
        progress.lastPlayedAt = .now
        persist()
        return true
    }

    @discardableResult
    func attemptJump() -> JumpAttemptOutcome? {
        guard progress.isRoundActive else { return nil }

        let energy = currentJumpEnergy
        let risk = currentJumpRisk
        let roll = min(max(randomValue(), 0), 0.999_999)
        let lostPoints = currentPotentialPoints

        guard roll <= energy else {
            if progress.shieldCharges > 0 {
                progress.shieldCharges -= 1
                progress.activeBonuses = DuperGameRules.activeBonuses(afterConsuming: progress.activeBonuses)
                refreshCurrentMultiplier()
                progress.lastActionOutcome = .shieldSaved
                progress.lastPlayedAt = .now

                let context = makeOutcomeContext(
                    pointsDelta: 0,
                    energy: energy,
                    risk: risk,
                    event: progress.lastStepEvent ?? .normal,
                    lostPoints: 0,
                    collectedPoints: 0
                )

                persist()
                return .shieldSaved(context)
            }

            let context = makeOutcomeContext(
                pointsDelta: 0,
                energy: energy,
                risk: risk,
                event: progress.lastStepEvent ?? .normal,
                lostPoints: lostPoints,
                collectedPoints: 0
            )
            let result = RoundResult(
                height: progress.highestRoundStep,
                multiplier: progress.currentMultiplier,
                score: 0,
                lostPoints: lostPoints,
                highestStep: progress.highestRoundStep,
                finalEvent: progress.lastStepEvent,
                actionOutcome: .failed,
                outcome: .slipped
            )
            finishRound(with: result)
            return .failed(context)
        }

        let landedStep = progress.currentHeight + 1
        let eventRoll = min(max(randomValue(), 0), 0.999_999)
        let event = DuperGameRules.event(
            for: landedStep,
            roll: eventRoll,
            hasShield: progress.shieldCharges > 0
        )

        progress.activeBonuses = DuperGameRules.activeBonuses(afterConsuming: progress.activeBonuses)
        if event.kind == .boost {
            progress.roundMultiplierBonus += event.multiplierBonus
        }
        progress.activeBonuses = DuperGameRules.bonuses(afterApplying: event, to: progress.activeBonuses)
        if event.grantsShield {
            progress.shieldCharges = min(DuperGameRules.maxShieldCharges, progress.shieldCharges + 1)
        }

        progress.currentHeight = landedStep
        progress.highestRoundStep = max(progress.highestRoundStep, landedStep)
        refreshCurrentMultiplier()

        let pointsDelta = DuperGameRules.pointsForLandedStep(
            step: landedStep,
            multiplier: progress.currentMultiplier,
            event: event
        )
        progress.currentRunPoints += pointsDelta
        progress.lastStepEvent = event
        progress.bestHeight = max(progress.bestHeight, progress.currentHeight)
        progress.bestMultiplier = max(progress.bestMultiplier, progress.currentMultiplier)
        progress.totalJumps += 1
        progress.lastPlayedAt = .now

        let isNearMiss = DuperGameRules.isNearMiss(energy: energy, roll: roll)
        let outcomeKind: RoundActionOutcomeKind = if isNearMiss {
            .nearMiss
        } else if event.isBonus {
            .landedWithBonus
        } else {
            .landed
        }
        progress.lastActionOutcome = outcomeKind

        refreshAchievements(persistAfterUpdate: false)
        persist()

        let context = makeOutcomeContext(
            pointsDelta: pointsDelta,
            energy: energy,
            risk: risk,
            event: event,
            lostPoints: 0,
            collectedPoints: 0
        )

        switch outcomeKind {
        case .nearMiss:
            return .nearMiss(context)
        case .landedWithBonus:
            return .landedWithBonus(context)
        default:
            return .landed(context)
        }
    }

    @discardableResult
    func collectRound() -> JumpAttemptOutcome? {
        guard progress.isRoundActive else { return nil }

        let collectedPoints = currentPotentialPoints
        let context = makeOutcomeContext(
            pointsDelta: 0,
            energy: currentJumpEnergy,
            risk: currentJumpRisk,
            event: progress.lastStepEvent ?? .normal,
            lostPoints: 0,
            collectedPoints: collectedPoints
        )
        let result = RoundResult(
            height: progress.highestRoundStep,
            multiplier: progress.currentMultiplier,
            score: collectedPoints,
            lostPoints: 0,
            highestStep: progress.highestRoundStep,
            finalEvent: progress.lastStepEvent,
            actionOutcome: .collected,
            outcome: .banked
        )
        finishRound(with: result)
        return .collected(context)
    }

    func achievementProgress(for achievement: Achievement) -> Int {
        switch achievement.metric {
        case .totalJumps:
            progress.totalJumps
        case .bestHeight:
            max(progress.bestHeight, progress.currentHeight)
        case .bestMultiplierGainPercent:
            max(0, Int(((max(progress.bestMultiplier, progress.currentMultiplier) - 1.0) * 100).rounded(.down)))
        case .totalRounds:
            progress.totalRounds
        case .bankedRounds:
            progress.bankedRounds
        case .comebackRounds:
            progress.comebackRounds
        case .totalScore:
            progress.totalScore
        case .guideReads:
            guideReads
        }
    }

    func markArticleRead(_ article: GuideArticle) {
        guard let index = guideArticles.firstIndex(where: { $0.id == article.id }) else { return }

        guideArticles[index].isRead = true
        refreshAchievements(persistAfterUpdate: false)
        persist()
    }

    func updateSettings(_ update: (inout AppSettings) -> Void) {
        update(&settings)
        persist()
    }

    func resetLocalProgress() {
        let preservedSettings = settings
        let initialState = StoredGameState.initial

        progress = initialState.progress
        recentResults = initialState.recentResults
        achievements = initialState.achievements
        guideArticles = initialState.guideArticles
        settings = preservedSettings
        localProgressResetRevision &+= 1
        persist()
    }

    private func refreshCurrentMultiplier() {
        progress.currentMultiplier = DuperGameRules.effectiveMultiplier(
            for: progress.currentHeight,
            roundMultiplierBonus: progress.roundMultiplierBonus,
            activeBonuses: progress.activeBonuses
        )
    }

    private func makeOutcomeContext(
        pointsDelta: Int,
        energy: Double,
        risk: Double,
        event: StepEvent,
        lostPoints: Int,
        collectedPoints: Int
    ) -> JumpOutcomeContext {
        JumpOutcomeContext(
            step: progress.currentHeight,
            highestStep: progress.highestRoundStep,
            multiplier: progress.currentMultiplier,
            potentialPoints: progress.currentRunPoints,
            pointsDelta: pointsDelta,
            energy: energy,
            risk: risk,
            event: event,
            activeBonuses: progress.activeBonuses,
            shieldCharges: progress.shieldCharges,
            lostPoints: lostPoints,
            collectedPoints: collectedPoints
        )
    }

    private func finishRound(with result: RoundResult) {
        let previousOutcome = recentResults.first?.outcome

        recentResults.insert(result, at: 0)
        recentResults = Array(recentResults.prefix(6))

        progress.activeRoundID = nil
        progress.currentHeight = 0
        progress.currentMultiplier = DuperGameRules.startingMultiplier
        progress.currentRunPoints = 0
        progress.highestRoundStep = 0
        progress.roundMultiplierBonus = 0
        progress.activeBonuses = []
        progress.shieldCharges = 0
        progress.lastStepEvent = result.finalEvent
        progress.lastActionOutcome = result.actionOutcome
        progress.bestHeight = max(progress.bestHeight, result.highestStep)
        progress.bestMultiplier = max(progress.bestMultiplier, result.multiplier)
        progress.totalRounds += 1
        switch result.outcome {
        case .banked:
            progress.bankedRounds += 1
            if previousOutcome == .slipped {
                progress.comebackRounds += 1
            }
        case .slipped:
            progress.slippedRounds += 1
        }
        progress.totalScore += result.score
        progress.lastPlayedAt = result.playedAt

        refreshAchievements(persistAfterUpdate: false)
        persist()
    }

    private func refreshAchievements(persistAfterUpdate: Bool) {
        var changed = false

        achievements = achievements.map { achievement in
            var updatedAchievement = achievement
            let value = achievementProgress(for: achievement)

            if value >= achievement.targetValue && !achievement.isUnlocked {
                updatedAchievement.isUnlocked = true
                updatedAchievement.unlockedAt = .now
                changed = true
            }

            return updatedAchievement
        }

        if changed && persistAfterUpdate {
            persist()
        }
    }

    private func persist() {
        let storedState = StoredGameState(
            progress: progress,
            recentResults: recentResults,
            achievements: achievements,
            guideArticles: guideArticles,
            settings: settings
        )

        guard let data = try? JSONEncoder().encode(storedState) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func mergedAchievements(with storedAchievements: [Achievement]) -> [Achievement] {
        Achievement.starterSet.map { current in
            guard let stored = storedAchievements.first(where: { $0.id == current.id }) else {
                return current
            }

            var updatedAchievement = current
            updatedAchievement.isUnlocked = stored.isUnlocked
            updatedAchievement.unlockedAt = stored.unlockedAt
            return updatedAchievement
        }
    }

    private static func mergedGuideArticles(with storedArticles: [GuideArticle]) -> [GuideArticle] {
        GuideArticle.placeholders.map { current in
            storedArticles.first(where: { $0.id == current.id }) ?? current
        }
    }
}

extension DuperGameStore {
    static var preview: DuperGameStore {
        let suiteName = "duperjumper.preview"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let store = DuperGameStore(defaults: defaults, randomValue: { 0.12 })
        store.startRound()
        store.attemptJump()
        store.attemptJump()
        return store
    }
}
