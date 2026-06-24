import Foundation
import SwiftUI

enum DuperTab: String, CaseIterable, Identifiable, Codable {
    case game
    case achievements
    case guide
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .game: "Game"
        case .achievements: "Achievements"
        case .guide: "Guide"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .game: "arrow.up.to.line.compact"
        case .achievements: "sparkles"
        case .guide: "book.pages"
        case .settings: "slider.horizontal.3"
        }
    }

    var accentColor: Color {
        switch self {
        case .game: DJTheme.electricCyan
        case .achievements: DJTheme.pulseMagenta
        case .guide: DJTheme.voltAmber
        case .settings: DJTheme.signalMint
        }
    }
}

struct GameProgress: Codable, Hashable {
    var activeRoundID: UUID?
    var currentHeight: Int
    var currentMultiplier: Double
    var currentRunPoints: Int
    var highestRoundStep: Int
    var roundMultiplierBonus: Double
    var activeBonuses: [RoundBonus]
    var shieldCharges: Int
    var lastStepEvent: StepEvent?
    var lastActionOutcome: RoundActionOutcomeKind?
    var bestHeight: Int
    var bestMultiplier: Double
    var totalJumps: Int
    var totalRounds: Int
    var bankedRounds: Int
    var slippedRounds: Int
    var comebackRounds: Int
    var totalScore: Int
    var lastPlayedAt: Date?

    var isRoundActive: Bool {
        activeRoundID != nil
    }

    init(
        activeRoundID: UUID?,
        currentHeight: Int,
        currentMultiplier: Double,
        currentRunPoints: Int = 0,
        highestRoundStep: Int = 0,
        roundMultiplierBonus: Double = 0,
        activeBonuses: [RoundBonus] = [],
        shieldCharges: Int = 0,
        lastStepEvent: StepEvent? = nil,
        lastActionOutcome: RoundActionOutcomeKind? = nil,
        bestHeight: Int,
        bestMultiplier: Double,
        totalJumps: Int,
        totalRounds: Int,
        bankedRounds: Int,
        slippedRounds: Int,
        comebackRounds: Int,
        totalScore: Int,
        lastPlayedAt: Date?
    ) {
        self.activeRoundID = activeRoundID
        self.currentHeight = currentHeight
        self.currentMultiplier = currentMultiplier
        self.currentRunPoints = currentRunPoints
        self.highestRoundStep = highestRoundStep
        self.roundMultiplierBonus = roundMultiplierBonus
        self.activeBonuses = activeBonuses
        self.shieldCharges = shieldCharges
        self.lastStepEvent = lastStepEvent
        self.lastActionOutcome = lastActionOutcome
        self.bestHeight = bestHeight
        self.bestMultiplier = bestMultiplier
        self.totalJumps = totalJumps
        self.totalRounds = totalRounds
        self.bankedRounds = bankedRounds
        self.slippedRounds = slippedRounds
        self.comebackRounds = comebackRounds
        self.totalScore = totalScore
        self.lastPlayedAt = lastPlayedAt
    }

    enum CodingKeys: String, CodingKey {
        case activeRoundID
        case currentHeight
        case currentMultiplier
        case currentRunPoints
        case highestRoundStep
        case roundMultiplierBonus
        case activeBonuses
        case shieldCharges
        case lastStepEvent
        case lastActionOutcome
        case bestHeight
        case bestMultiplier
        case totalJumps
        case totalRounds
        case bankedRounds
        case slippedRounds
        case comebackRounds
        case totalScore
        case lastPlayedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        activeRoundID = try container.decodeIfPresent(UUID.self, forKey: .activeRoundID)
        currentHeight = try container.decode(Int.self, forKey: .currentHeight)
        currentMultiplier = try container.decode(Double.self, forKey: .currentMultiplier)
        currentRunPoints = try container.decodeIfPresent(Int.self, forKey: .currentRunPoints) ?? 0
        highestRoundStep = try container.decodeIfPresent(Int.self, forKey: .highestRoundStep) ?? currentHeight
        roundMultiplierBonus = try container.decodeIfPresent(Double.self, forKey: .roundMultiplierBonus) ?? 0
        activeBonuses = try container.decodeIfPresent([RoundBonus].self, forKey: .activeBonuses) ?? []
        shieldCharges = try container.decodeIfPresent(Int.self, forKey: .shieldCharges) ?? 0
        lastStepEvent = try container.decodeIfPresent(StepEvent.self, forKey: .lastStepEvent)
        lastActionOutcome = try container.decodeIfPresent(RoundActionOutcomeKind.self, forKey: .lastActionOutcome)
        bestHeight = try container.decode(Int.self, forKey: .bestHeight)
        bestMultiplier = try container.decode(Double.self, forKey: .bestMultiplier)
        totalJumps = try container.decodeIfPresent(Int.self, forKey: .totalJumps) ?? 0
        totalRounds = try container.decode(Int.self, forKey: .totalRounds)
        bankedRounds = try container.decodeIfPresent(Int.self, forKey: .bankedRounds) ?? 0
        slippedRounds = try container.decodeIfPresent(Int.self, forKey: .slippedRounds) ?? 0
        comebackRounds = try container.decodeIfPresent(Int.self, forKey: .comebackRounds) ?? 0
        totalScore = try container.decode(Int.self, forKey: .totalScore)
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
    }

    static let initial = GameProgress(
        activeRoundID: nil,
        currentHeight: 0,
        currentMultiplier: DuperGameRules.startingMultiplier,
        currentRunPoints: 0,
        highestRoundStep: 0,
        roundMultiplierBonus: 0,
        activeBonuses: [],
        shieldCharges: 0,
        lastStepEvent: nil,
        lastActionOutcome: nil,
        bestHeight: 0,
        bestMultiplier: DuperGameRules.startingMultiplier,
        totalJumps: 0,
        totalRounds: 0,
        bankedRounds: 0,
        slippedRounds: 0,
        comebackRounds: 0,
        totalScore: 0,
        lastPlayedAt: nil
    )

    static func multiplier(for height: Int) -> Double {
        DuperGameRules.baseMultiplier(for: height)
    }

    static func potentialPoints(height: Int, multiplier: Double) -> Int {
        DuperGameRules.projectedPotentialPoints(height: height, multiplier: multiplier)
    }

    static func jumpEnergy(for currentHeight: Int) -> Double {
        DuperGameRules.jumpEnergy(currentStep: currentHeight, activeBonuses: [])
    }

    static func jumpRisk(for currentHeight: Int) -> Double {
        DuperGameRules.jumpRisk(currentStep: currentHeight, activeBonuses: [])
    }
}

enum RoundOutcome: String, Codable, Hashable {
    case banked
    case slipped

    var title: String {
        switch self {
        case .banked: "Collected"
        case .slipped: "Failed"
        }
    }
}

struct RoundResult: Identifiable, Codable, Hashable {
    var id: UUID
    var playedAt: Date
    var height: Int
    var multiplier: Double
    var score: Int
    var lostPoints: Int
    var highestStep: Int
    var finalEvent: StepEvent?
    var actionOutcome: RoundActionOutcomeKind?
    var outcome: RoundOutcome

    init(
        id: UUID = UUID(),
        playedAt: Date = .now,
        height: Int,
        multiplier: Double,
        score: Int,
        lostPoints: Int = 0,
        highestStep: Int? = nil,
        finalEvent: StepEvent? = nil,
        actionOutcome: RoundActionOutcomeKind? = nil,
        outcome: RoundOutcome
    ) {
        self.id = id
        self.playedAt = playedAt
        self.height = height
        self.multiplier = multiplier
        self.score = score
        self.lostPoints = lostPoints
        self.highestStep = highestStep ?? height
        self.finalEvent = finalEvent
        self.actionOutcome = actionOutcome
        self.outcome = outcome
    }

    enum CodingKeys: String, CodingKey {
        case id
        case playedAt
        case height
        case multiplier
        case score
        case lostPoints
        case highestStep
        case finalEvent
        case actionOutcome
        case outcome
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        playedAt = try container.decode(Date.self, forKey: .playedAt)
        height = try container.decode(Int.self, forKey: .height)
        multiplier = try container.decode(Double.self, forKey: .multiplier)
        score = try container.decode(Int.self, forKey: .score)
        lostPoints = try container.decodeIfPresent(Int.self, forKey: .lostPoints) ?? 0
        highestStep = try container.decodeIfPresent(Int.self, forKey: .highestStep) ?? height
        finalEvent = try container.decodeIfPresent(StepEvent.self, forKey: .finalEvent)
        actionOutcome = try container.decodeIfPresent(RoundActionOutcomeKind.self, forKey: .actionOutcome)
        outcome = try container.decode(RoundOutcome.self, forKey: .outcome)
    }
}

enum AchievementMetric: String, Codable, Hashable {
    case totalJumps
    case bestHeight
    case bestMultiplierGainPercent
    case totalRounds
    case bankedRounds
    case comebackRounds
    case totalScore
    case guideReads
}

struct Achievement: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var summary: String
    var metric: AchievementMetric
    var targetValue: Int
    var isUnlocked: Bool
    var unlockedAt: Date? = nil

    static let starterSet: [Achievement] = [
        Achievement(
            id: "first-jump",
            title: "First Jump",
            summary: "Start a round and land one clean jump.",
            metric: .totalJumps,
            targetValue: 1,
            isUnlocked: false
        ),
        Achievement(
            id: "five-step-climb",
            title: "Five-Step Climb",
            summary: "Reach step 5 in a single tower run.",
            metric: .bestHeight,
            targetValue: 5,
            isUnlocked: false
        ),
        Achievement(
            id: "multiplier-spark",
            title: "Multiplier Spark",
            summary: "Push the multiplier from 1.00x to at least 2.00x.",
            metric: .bestMultiplierGainPercent,
            targetValue: 100,
            isUnlocked: false
        ),
        Achievement(
            id: "safe-collector",
            title: "Safe Collector",
            summary: "Collect three rounds before they slip away.",
            metric: .bankedRounds,
            targetValue: 3,
            isUnlocked: false
        ),
        Achievement(
            id: "comeback-round",
            title: "Comeback Round",
            summary: "Collect points right after a failed round.",
            metric: .comebackRounds,
            targetValue: 1,
            isUnlocked: false
        ),
        Achievement(
            id: "tower-regular",
            title: "Tower Regular",
            summary: "Complete ten local rounds.",
            metric: .totalRounds,
            targetValue: 10,
            isUnlocked: false
        )
    ]
}

struct GuideArticle: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var summary: String
    var readTimeMinutes: Int
    var isRead: Bool

    static let placeholders: [GuideArticle] = [
        GuideArticle(
            id: "core-loop",
            title: "Reading the Climb",
            summary: "Notice pace, height, and confidence before choosing the next upward step.",
            readTimeMinutes: 2,
            isRead: false
        ),
        GuideArticle(
            id: "multiplier-meter",
            title: "When to Collect",
            summary: "Set a stop point while focus is clear, then respect it before rhythm gets noisy.",
            readTimeMinutes: 2,
            isRead: false
        ),
        GuideArticle(
            id: "safe-design",
            title: "Momentum and Focus",
            summary: "Use short mental resets to keep quick decisions crisp instead of hurried.",
            readTimeMinutes: 3,
            isRead: false
        ),
        GuideArticle(
            id: "tiny-risks",
            title: "Tiny Risks, Better Runs",
            summary: "Take small, deliberate risks so each attempt teaches something useful.",
            readTimeMinutes: 2,
            isRead: false
        ),
        GuideArticle(
            id: "personal-best",
            title: "Building a Personal Best",
            summary: "Turn repeat attempts into useful signals for cleaner arcade progress.",
            readTimeMinutes: 1,
            isRead: false
        )
    ]
}

enum DuperAccentStyle: String, CaseIterable, Identifiable, Codable, Hashable {
    case neon
    case ocean
    case ember
    case mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neon: "Neon"
        case .ocean: "Ocean"
        case .ember: "Ember"
        case .mint: "Mint"
        }
    }

    var primaryColor: Color {
        switch self {
        case .neon: DJTheme.electricCyan
        case .ocean: DJTheme.stableBlue
        case .ember: DJTheme.voltAmber
        case .mint: DJTheme.signalMint
        }
    }

    var secondaryColor: Color {
        switch self {
        case .neon: DJTheme.pulseMagenta
        case .ocean: DJTheme.electricCyan
        case .ember: DJTheme.riskRed
        case .mint: DJTheme.voltAmber
        }
    }

    var meterFill: Color {
        switch self {
        case .neon: DJTheme.electricCyan
        case .ocean: DJTheme.stableBlue
        case .ember: DJTheme.voltAmber
        case .mint: DJTheme.signalMint
        }
    }
}

struct AppSettings: Codable, Hashable {
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var reduceMotion: Bool
    var highContrastMeter: Bool
    var accentStyle: DuperAccentStyle

    static let defaults = AppSettings(
        soundEnabled: true,
        hapticsEnabled: true,
        reduceMotion: false,
        highContrastMeter: false,
        accentStyle: .neon
    )

    init(
        soundEnabled: Bool,
        hapticsEnabled: Bool,
        reduceMotion: Bool,
        highContrastMeter: Bool,
        accentStyle: DuperAccentStyle
    ) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.reduceMotion = reduceMotion
        self.highContrastMeter = highContrastMeter
        self.accentStyle = accentStyle
    }

    var effectiveMeterFill: Color {
        highContrastMeter ? DJTheme.voltAmber : accentStyle.meterFill
    }

    func reducesMotion(systemReduceMotion: Bool) -> Bool {
        reduceMotion || systemReduceMotion
    }

    enum CodingKeys: String, CodingKey {
        case soundEnabled
        case hapticsEnabled
        case reduceMotion
        case highContrastMeter
        case accentStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaults

        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? defaults.reduceMotion
        highContrastMeter = try container.decodeIfPresent(Bool.self, forKey: .highContrastMeter) ?? defaults.highContrastMeter
        accentStyle = try container.decodeIfPresent(DuperAccentStyle.self, forKey: .accentStyle) ?? defaults.accentStyle
    }
}

struct StoredGameState: Codable {
    var progress: GameProgress
    var recentResults: [RoundResult]
    var achievements: [Achievement]
    var guideArticles: [GuideArticle]
    var settings: AppSettings

    static let initial = StoredGameState(
        progress: .initial,
        recentResults: [],
        achievements: Achievement.starterSet,
        guideArticles: GuideArticle.placeholders,
        settings: .defaults
    )
}
