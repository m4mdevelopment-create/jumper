import SwiftUI

struct GameView: View {
    @Environment(DuperGameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var actionFeedback: RoundFeedback?
    @State private var jumpAnimationTrigger = 0
    @State private var failVisual: GameSceneFailVisual?
    @State private var landingVisual: GameSceneLandingVisual?

    private var reduceMotion: Bool {
        systemReduceMotion || store.settings.reduceMotion
    }

    private var activeRunBoosts: [ActiveRunBoost] {
        guard store.progress.isRoundActive else { return [] }

        var boosts: [ActiveRunBoost] = []

        if store.isShieldAvailable {
            boosts.append(
                ActiveRunBoost(
                    id: "shield",
                    title: "Shield ready",
                    iconName: "shield.fill",
                    accent: DJTheme.stableBlue
                )
            )
        }

        boosts.append(contentsOf: store.activeRoundBonuses.map { bonus in
            switch bonus.kind {
            case .saferNextJump:
                ActiveRunBoost(
                    id: bonus.id,
                    title: "Safe next jump",
                    iconName: "checkmark.shield.fill",
                    accent: DJTheme.signalMint
                )
            case .surgeMultiplier:
                ActiveRunBoost(
                    id: bonus.id,
                    title: "Surge active",
                    iconName: "sparkles",
                    accent: DJTheme.pulseMagenta
                )
            }
        })

        return boosts
    }

    private var nextHeight: Int {
        store.progress.currentHeight + 1
    }

    private var nextMultiplier: Double {
        DuperGameRules.effectiveMultiplier(
            for: nextHeight,
            roundMultiplierBonus: store.progress.roundMultiplierBonus,
            activeBonuses: store.progress.activeBonuses
        )
    }

    private var nextPotentialPoints: Int {
        store.currentPotentialPoints + DuperGameRules.pointsForLandedStep(
            step: nextHeight,
            multiplier: nextMultiplier,
            event: .normal
        )
    }

    private var previousHeight: Int? {
        store.recentResults.first?.highestStep
    }

    private var displayedSceneHeight: Int {
        if let failVisual {
            return failVisual.displayedHeight
        }

        if store.progress.isRoundActive || store.recentResults.isEmpty {
            return store.progress.currentHeight
        }

        return store.recentResults.first?.highestStep ?? store.progress.currentHeight
    }

    private var displayedPreviousMarker: Int? {
        store.progress.isRoundActive ? previousHeight : nil
    }

    var body: some View {
        ZStack {
            DuperBackground()

            GeometryReader { proxy in
                let showsFeedback = proxy.size.height > 720
                let stageHeight = stageHeight(for: proxy.size.height, showsFeedback: showsFeedback)

                VStack(spacing: 10) {
                    compactGameHeader

                    gameStage
                        .frame(height: stageHeight)

                    decisionBar

                    if showsFeedback {
                        if let postRoundSummary, store.latestRoundOutcome == .banked {
                            postRoundSummaryStrip(postRoundSummary)
                        } else if failVisual == nil {
                            feedbackTicker
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
        }
        .toolbarBackground(DJTheme.deepDeck, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: store.progress.currentHeight)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: store.progress.currentMultiplier)
        .onAppear {
            AppDelegate.lockGameOrientation()
            restoreVisualOutcomeIfNeeded()
        }
        .onDisappear {
            AppDelegate.restoreDefaultOrientations()
        }
        .onChange(of: store.localProgressResetRevision) { _, _ in
            failVisual = nil
            landingVisual = nil
            actionFeedback = nil
        }
    }

    private var gameStage: some View {
        ZStack {
            JumperGameSceneView(
                currentHeight: displayedSceneHeight,
                bestHeight: store.progress.bestHeight,
                previousHeight: displayedPreviousMarker,
                nextRisk: store.currentJumpRisk,
                currentEvent: failVisual?.lastEvent ?? store.lastStepEvent,
                isActive: store.progress.isRoundActive,
                reduceMotion: reduceMotion,
                landingVisual: landingVisual,
                failVisual: failVisual,
                onJumpRequested: handleJump
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DJTheme.void.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            currentRiskState.accent.opacity(store.progress.isRoundActive ? 0.78 : 0.36),
                            DJTheme.electricCyan.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: currentRiskState.accent.opacity(store.progress.isRoundActive ? 0.20 : 0.10), radius: 20, x: 0, y: 12)
    }

    private var compactGameHeader: some View {
        HStack(spacing: 8) {
            statusBadge

            Spacer(minLength: 4)

            StageHUDPill(
                title: "Step",
                value: "\(displayedSceneHeight)",
                iconName: "figure.stairs",
                accent: DJTheme.electricCyan,
                reduceMotion: reduceMotion
            )

            StageHUDPill(
                title: "Best",
                value: "\(store.progress.bestHeight)",
                iconName: "arrow.up.to.line.compact",
                accent: DJTheme.voltAmber,
                reduceMotion: reduceMotion
            )
        }
    }

    private var gameStageTopHUD: some View {
        HStack(spacing: 8) {
            statusBadge

            Spacer(minLength: 6)

            StageHUDPill(
                title: "Step",
                value: "\(displayedSceneHeight)",
                iconName: "figure.stairs",
                accent: DJTheme.electricCyan,
                reduceMotion: reduceMotion
            )

            StageHUDPill(
                title: "Best",
                value: "\(store.progress.bestHeight)",
                iconName: "arrow.up.to.line.compact",
                accent: DJTheme.voltAmber,
                reduceMotion: reduceMotion
            )
        }
    }

    private var gameStageBottomHUD: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                StageHeroMetric(
                    title: "Multiplier",
                    value: multiplierText(store.progress.currentMultiplier),
                    accent: DJTheme.electricCyan,
                    reduceMotion: reduceMotion
                )

                StageHUDPill(
                    title: "Ready",
                    value: "\(pointsText(store.currentPotentialPoints)) pts",
                    iconName: "checkmark.seal.fill",
                    accent: DJTheme.signalMint,
                    reduceMotion: reduceMotion
                )

                StageHUDPill(
                    title: "Risk",
                    value: percentText(store.currentJumpRisk),
                    iconName: currentRiskState.iconName,
                    accent: currentRiskState.accent,
                    reduceMotion: reduceMotion
                )
            }

            HStack(spacing: 8) {
                GameplayRiskBadge(state: currentRiskState)

                Text(riskCueMessage)
                    .font(DJTheme.labelFont(11))
                    .foregroundStyle(store.progress.isRoundActive ? currentRiskState.accent : DJTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(DJTheme.void.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var decisionBar: some View {
        VStack(spacing: 8) {
            if store.progress.isRoundActive {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 9) {
                        collectButton
                            .frame(width: 124)
                        jumpButton
                    }

                    VStack(spacing: 9) {
                        jumpButton
                        collectButton
                    }
                }
            } else {
                Button {
                    handleStart()
                } label: {
                    DecisionButtonLabel(
                        title: idleActionTitle,
                        detail: "Step 1 starts at \(percentText(GameProgress.jumpEnergy(for: 0))) Energy",
                        iconName: idleActionIcon
                    )
                }
                .buttonStyle(DuperButtonStyle(accent: DJTheme.electricCyan, reduceMotion: reduceMotion))
                .accessibilityIdentifier("game.start")
            }

            HStack(spacing: 8) {
                MiniDecisionChip(title: "Multiplier", value: multiplierText(store.progress.currentMultiplier), accent: DJTheme.electricCyan)
                MiniDecisionChip(title: "Ready", value: "\(pointsText(store.currentPotentialPoints)) pts", accent: DJTheme.signalMint)
                MiniDecisionChip(title: "Risk", value: percentText(store.currentJumpRisk), accent: currentRiskState.accent)
            }

            JumpReadinessMeter(
                energy: store.currentJumpEnergy,
                fill: store.settings.effectiveMeterFill,
                highContrast: store.settings.highContrastMeter,
                reduceMotion: reduceMotion
            )

            if !activeRunBoosts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(activeRunBoosts) { boost in
                        ActiveRunBoostChip(boost: boost)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(8)
        .background(DJTheme.void.opacity(0.50), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(currentRiskState.accent.opacity(store.progress.isRoundActive ? 0.26 : 0.16), lineWidth: 1)
        )
    }

    private var feedbackTicker: some View {
        let feedback = currentFeedback

        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: feedback.iconName)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(feedback.accent)
                .frame(width: 28, height: 28)
                .background(feedback.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(DJTheme.labelFont(13))
                    .foregroundStyle(DJTheme.textPrimary)
                    .lineLimit(1)

                Text(feedback.message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(DJTheme.deepDeck.opacity(0.58), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(feedback.accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func postRoundSummaryStrip(_ summary: GameRoundSummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: summary.iconName)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(summary.accent)
                .frame(width: 30, height: 30)
                .background(summary.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.title)
                    .font(DJTheme.labelFont(13))
                    .foregroundStyle(DJTheme.textPrimary)
                    .lineLimit(1)

                Text(summary.insight)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)

            CompactRoundMetric(title: "Step", value: "\(summary.stepReached)", accent: DJTheme.electricCyan)
            CompactRoundMetric(title: summary.pointsTitle, value: summary.pointsText, accent: summary.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(DJTheme.deepDeck.opacity(0.64), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(summary.accent.opacity(0.30), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var recentRoundsCompact: some View {
        if !store.recentResults.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("Recent")
                        .font(DJTheme.labelFont(11))
                        .foregroundStyle(DJTheme.textSecondary)
                        .textCase(.uppercase)

                    Spacer(minLength: 0)

                    Text("\(store.progress.totalRounds) total")
                        .font(DJTheme.labelFont(10))
                        .foregroundStyle(DJTheme.textSecondary.opacity(0.82))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(store.recentResults.prefix(5))) { result in
                            CompactResultPill(result: result)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var statusBadge: some View {
        Label(roundStatusTitle, systemImage: roundStatusIcon)
            .font(DJTheme.labelFont(12))
            .foregroundStyle(roundStatusAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(roundStatusAccent.opacity(0.14), in: Capsule())
    }

    private var jumpButton: some View {
        Button {
            handleJump()
        } label: {
            DecisionButtonLabel(
                title: "Jump",
                detail: "\(percentText(store.currentJumpRisk)) Risk to Step \(nextHeight)",
                iconName: "arrow.up"
            )
        }
        .buttonStyle(DuperButtonStyle(accent: DJTheme.electricCyan, reduceMotion: reduceMotion))
        .accessibilityIdentifier("game.jump")
    }

    private var collectButton: some View {
        Button {
            handleCollect()
        } label: {
            DecisionButtonLabel(
                title: "Collect",
                detail: store.progress.currentHeight == 0 ? "Locked" : "\(pointsText(store.currentPotentialPoints)) pts",
                iconName: "checkmark.seal"
            )
        }
        .buttonStyle(DuperButtonStyle(accent: DJTheme.signalMint, role: .secondary, reduceMotion: reduceMotion))
        .disabled(store.progress.currentHeight == 0)
        .accessibilityIdentifier("game.collect")
    }

    private var collectDetailText: String {
        guard store.progress.currentHeight > 0 else {
            return "Reach Step 1 first"
        }

        return "\(pointsText(store.currentPotentialPoints)) pts ready"
    }

    private var idleActionTitle: String {
        store.latestRoundOutcome == .slipped ? "Try Again" : "Start"
    }

    private var idleActionIcon: String {
        store.latestRoundOutcome == .slipped ? "arrow.clockwise" : "play.fill"
    }

    private var currentFeedback: RoundFeedback {
        actionFeedback ?? persistedFeedback
    }

    private var persistedFeedback: RoundFeedback {
        guard !store.progress.isRoundActive else {
            return .started(energy: percentText(store.currentJumpEnergy), riskState: currentRiskState)
        }

        guard let result = store.recentResults.first else {
            return .ready
        }

        switch result.outcome {
        case .banked:
            return .collected(points: result.score)
        case .slipped:
            let lostPoints = result.lostPoints > 0
                ? result.lostPoints
                : GameProgress.potentialPoints(height: result.height, multiplier: result.multiplier)
            return .failed(lostPoints: lostPoints)
        }
    }

    private var postRoundSummary: GameRoundSummary? {
        guard !store.progress.isRoundActive, let result = store.recentResults.first else { return nil }

        return GameRoundSummary(result: result, bestHeight: store.progress.bestHeight)
    }

    private var currentRiskState: GameplayRiskState {
        GameplayRiskState.state(forRisk: store.currentJumpRisk)
    }

    private var riskCueMessage: String {
        guard store.progress.isRoundActive else {
            return postRoundSummary == nil ? "Step 1 starts safe." : "Round over. Restart fast."
        }

        return currentRiskState.nextJumpMessage
    }

    private var roundStatusTitle: String {
        if store.progress.isRoundActive {
            return "\(currentRiskState.title) Climb"
        }

        switch store.latestRoundOutcome {
        case .banked:
            return "Collected"
        case .slipped:
            return "Failed"
        case nil:
            return "Ready"
        }
    }

    private var roundStatusIcon: String {
        if store.progress.isRoundActive {
            return currentRiskState.iconName
        }

        switch store.latestRoundOutcome {
        case .banked:
            return "checkmark.circle.fill"
        case .slipped:
            return "xmark.circle.fill"
        case nil:
            return "play.circle.fill"
        }
    }

    private var roundStatusAccent: Color {
        if store.progress.isRoundActive {
            return currentRiskState.accent
        }

        switch store.latestRoundOutcome {
        case .banked:
            return DJTheme.signalMint
        case .slipped:
            return DJTheme.riskRed
        case nil:
            return DJTheme.voltAmber
        }
    }

    private func handleStart() {
        guard store.startRound() else { return }

        failVisual = nil
        landingVisual = nil

        withFeedbackAnimation {
            actionFeedback = .started(energy: percentText(store.currentJumpEnergy), riskState: currentRiskState)
        }
    }

    private func handleJump() {
        let sourceStep = store.progress.currentHeight
        let targetStep = sourceStep + 1
        let previousDisplayedHeight = displayedSceneHeight
        let previousEvent = store.lastStepEvent
        let bestBeforeJump = store.progress.bestHeight

        guard let outcome = store.attemptJump() else { return }

        jumpAnimationTrigger += 1

        withFeedbackAnimation {
            switch outcome {
            case let .landed(context):
                failVisual = nil
                landingVisual = GameSceneLandingVisual(
                    triggerID: jumpAnimationTrigger,
                    fromStep: sourceStep,
                    landedStep: context.step,
                    pointsDelta: context.pointsDelta,
                    event: context.event
                )
                playJumpFeedback(nearMiss: false, event: context.event)
                actionFeedback = .cleanJump(context: context, riskState: currentRiskState)
            case let .landedWithBonus(context):
                failVisual = nil
                landingVisual = GameSceneLandingVisual(
                    triggerID: jumpAnimationTrigger,
                    fromStep: sourceStep,
                    landedStep: context.step,
                    pointsDelta: context.pointsDelta,
                    event: context.event
                )
                playJumpFeedback(nearMiss: false, event: context.event)
                actionFeedback = .bonus(context: context, riskState: currentRiskState)
            case let .nearMiss(context):
                failVisual = nil
                landingVisual = GameSceneLandingVisual(
                    triggerID: jumpAnimationTrigger,
                    fromStep: sourceStep,
                    landedStep: context.step,
                    pointsDelta: context.pointsDelta,
                    event: context.event
                )
                playJumpFeedback(nearMiss: true, event: context.event)
                actionFeedback = context.event.isBonus
                    ? .bonus(context: context, riskState: currentRiskState)
                    : .nearMiss(context: context, riskState: currentRiskState)
            case let .shieldSaved(context):
                failVisual = nil
                landingVisual = GameSceneLandingVisual(
                    triggerID: jumpAnimationTrigger,
                    fromStep: sourceStep,
                    landedStep: sourceStep,
                    pointsDelta: 0,
                    event: context.event
                )
                GameplayHaptics.playShieldSaved(isEnabled: store.settings.hapticsEnabled)
                GameplaySoundManager.shared.playShield(isEnabled: store.settings.soundEnabled)
                actionFeedback = .shieldSaved(context: context)
            case let .failed(context):
                landingVisual = nil
                failVisual = GameSceneFailVisual(
                    triggerID: jumpAnimationTrigger,
                    fromStep: sourceStep,
                    targetStep: targetStep,
                    displayedHeight: max(previousDisplayedHeight, sourceStep),
                    previousDisplayedHeight: previousDisplayedHeight,
                    lostPoints: context.lostPoints,
                    bestStep: max(bestBeforeJump, context.highestStep, store.progress.bestHeight),
                    lastEvent: previousEvent
                )
                GameplayHaptics.playFail(isEnabled: store.settings.hapticsEnabled)
                GameplaySoundManager.shared.playFail(isEnabled: store.settings.soundEnabled)
                actionFeedback = .failed(lostPoints: context.lostPoints)
            case let .collected(context):
                failVisual = nil
                landingVisual = nil
                actionFeedback = .collected(points: context.collectedPoints)
            }
        }
    }

    private func handleCollect() {
        guard let outcome = store.collectRound() else { return }

        GameplayHaptics.playCollect(isEnabled: store.settings.hapticsEnabled)
        GameplaySoundManager.shared.playCollect(isEnabled: store.settings.soundEnabled)

        withFeedbackAnimation {
            failVisual = nil
            landingVisual = nil
            actionFeedback = .collected(points: outcome.context.collectedPoints)
        }
    }

    private func restoreVisualOutcomeIfNeeded() {
        guard
            failVisual == nil,
            !store.progress.isRoundActive,
            store.latestRoundOutcome == .slipped,
            let result = store.recentResults.first
        else {
            return
        }

        jumpAnimationTrigger += 1
        let lostPoints = result.lostPoints > 0
            ? result.lostPoints
            : GameProgress.potentialPoints(height: result.highestStep, multiplier: result.multiplier)

        failVisual = GameSceneFailVisual(
            triggerID: jumpAnimationTrigger,
            fromStep: result.highestStep,
            targetStep: result.highestStep + 1,
            displayedHeight: result.highestStep,
            previousDisplayedHeight: result.highestStep,
            lostPoints: lostPoints,
            bestStep: max(store.progress.bestHeight, result.highestStep),
            lastEvent: result.finalEvent
        )
    }

    private func playJumpFeedback(nearMiss: Bool, event: StepEvent) {
        if nearMiss {
            GameplayHaptics.playNearMiss(isEnabled: store.settings.hapticsEnabled)
        } else {
            GameplayHaptics.playJumpLanded(isEnabled: store.settings.hapticsEnabled)
        }

        GameplaySoundManager.shared.playJump(isEnabled: store.settings.soundEnabled)

        if event.isBonus {
            GameplayHaptics.playBonusTriggered(isEnabled: store.settings.hapticsEnabled)
            switch event.kind {
            case .shield:
                GameplaySoundManager.shared.playShield(isEnabled: store.settings.soundEnabled)
            case .boost, .safe, .surge:
                GameplaySoundManager.shared.playBoost(isEnabled: store.settings.soundEnabled)
            case .normal:
                break
            }
        }
    }

    private func withFeedbackAnimation(_ update: () -> Void) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2), update)
    }

    private func stageHeight(for availableHeight: CGFloat, showsFeedback: Bool) -> CGFloat {
        let headerHeight: CGFloat = 38
        let decisionBarHeight: CGFloat = 104
        let feedbackHeight: CGFloat = showsFeedback ? 56 : 0
        let interItemSpacing: CGFloat = showsFeedback ? 30 : 20
        let verticalPadding: CGFloat = 18
        let tabBarClearance: CGFloat = 18
        let reservedHeight = headerHeight
            + decisionBarHeight
            + feedbackHeight
            + interItemSpacing
            + verticalPadding
            + tabBarClearance
        let target = availableHeight - reservedHeight
        return min(max(target, 330), 520)
    }

    private func multiplierText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2))))x"
    }

    private func percentText(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func pointsText(_ value: Int) -> String {
        value.formatted(.number)
    }
}

private struct RoundFeedback {
    let title: String
    let message: String
    let iconName: String
    let accent: Color

    static let ready = RoundFeedback(
        title: "Ready",
        message: "Start a climb and watch the next Step.",
        iconName: "play.circle.fill",
        accent: DJTheme.voltAmber
    )

    static func started(energy: String, riskState: GameplayRiskState) -> RoundFeedback {
        RoundFeedback(
            title: "Round Started",
            message: "\(riskState.title) start. Energy is \(energy). Step 1 is open.",
            iconName: riskState.iconName,
            accent: riskState.accent
        )
    }

    static func cleanJump(context: JumpOutcomeContext, riskState: GameplayRiskState) -> RoundFeedback {
        RoundFeedback(
            title: "Clean Jump",
            message: "Step \(context.step), \(multiplierText(context.multiplier)), \(pointsText(context.potentialPoints)) points. \(riskState.title) next.",
            iconName: "arrow.up.circle.fill",
            accent: riskState == .safe ? DJTheme.signalMint : riskState.accent
        )
    }

    static func nearMiss(context: JumpOutcomeContext, riskState: GameplayRiskState) -> RoundFeedback {
        RoundFeedback(
            title: "Near Miss",
            message: "Barely held Step \(context.step). \(pointsText(context.potentialPoints)) points, \(riskState.title.lowercased()) next.",
            iconName: "exclamationmark.triangle.fill",
            accent: DJTheme.voltAmber
        )
    }

    static func bonus(context: JumpOutcomeContext, riskState: GameplayRiskState) -> RoundFeedback {
        let presentation: (title: String, iconName: String, accent: Color, detail: String) = switch context.event.kind {
        case .boost:
            (
                "Boost",
                "bolt.badge.checkmark.fill",
                DJTheme.pulseMagenta,
                "\(pointsText(context.pointsDelta)) points added."
            )
        case .safe:
            (
                "Boost",
                "bolt.badge.checkmark.fill",
                DJTheme.electricCyan,
                "Next jump gets a safer window."
            )
        case .shield:
            (
                "Shield",
                "shield.fill",
                DJTheme.stableBlue,
                "Shield is ready for one slip."
            )
        case .surge:
            (
                "Surge",
                "sparkles",
                DJTheme.pulseMagenta,
                "Multiplier spikes to \(multiplierText(context.multiplier))."
            )
        case .normal:
            (
                "Clean Jump",
                "arrow.up.circle.fill",
                riskState == .safe ? DJTheme.signalMint : riskState.accent,
                "\(pointsText(context.potentialPoints)) points ready."
            )
        }

        return RoundFeedback(
            title: presentation.title,
            message: "Step \(context.step). \(presentation.detail) \(riskState.title) next.",
            iconName: presentation.iconName,
            accent: presentation.accent
        )
    }

    static func shieldSaved(context: JumpOutcomeContext) -> RoundFeedback {
        RoundFeedback(
            title: "Shield Saved",
            message: "Shield held Step \(context.step). \(pointsText(context.potentialPoints)) points remain ready.",
            iconName: "shield.lefthalf.filled",
            accent: DJTheme.stableBlue
        )
    }

    static func surge(height: Int, multiplier: Double, points: Int) -> RoundFeedback {
        RoundFeedback(
            title: "Surge",
            message: "Step \(height) surge: \(multiplierText(multiplier)) and \(pointsText(points)) potential points.",
            iconName: "sparkles",
            accent: DJTheme.pulseMagenta
        )
    }

    static func collected(points: Int) -> RoundFeedback {
        RoundFeedback(
            title: "Collected",
            message: "\(pointsText(points)) points added.",
            iconName: "checkmark.seal.fill",
            accent: DJTheme.signalMint
        )
    }

    static func failed(lostPoints: Int) -> RoundFeedback {
        RoundFeedback(
            title: "Failed",
            message: "\(pointsText(lostPoints)) uncollected points lost.",
            iconName: "xmark.circle.fill",
            accent: DJTheme.riskRed
        )
    }

    private static func multiplierText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2))))x"
    }

    private static func pointsText(_ value: Int) -> String {
        value.formatted(.number)
    }
}

private struct GameNumericText: View {
    let text: String
    let font: Font
    let color: Color
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            label
        } else {
            label
                .contentTransition(.numericText())
        }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
    }
}

private struct StageHeroMetric: View {
    let title: String
    let value: String
    let accent: Color
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(DJTheme.labelFont(10))
                .foregroundStyle(DJTheme.textSecondary)
                .textCase(.uppercase)
                .lineLimit(1)

            GameNumericText(
                text: value,
                font: DJTheme.monoFont(34, weight: .black),
                color: accent,
                reduceMotion: reduceMotion
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DJTheme.void.opacity(0.66), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(accent.opacity(0.34), lineWidth: 1)
        )
    }
}

private struct StageHUDPill: View {
    let title: String
    let value: String
    let iconName: String
    let accent: Color
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DJTheme.labelFont(9))
                    .foregroundStyle(DJTheme.textSecondary)
                    .textCase(.uppercase)
                    .lineLimit(1)

                GameNumericText(
                    text: value,
                    font: DJTheme.monoFont(13, weight: .black),
                    color: DJTheme.textPrimary,
                    reduceMotion: reduceMotion
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(DJTheme.void.opacity(0.66), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct CompactRoundMetric: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(DJTheme.labelFont(9))
                .foregroundStyle(DJTheme.textSecondary)
                .textCase(.uppercase)
                .lineLimit(1)

            Text(value)
                .font(DJTheme.monoFont(12, weight: .black))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .frame(minWidth: 46, alignment: .trailing)
    }
}

private struct DecisionButtonLabel: View {
    let title: String
    let detail: String
    let iconName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .black))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DJTheme.labelFont(17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(detail)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 2)
    }
}

private struct MiniDecisionChip: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DJTheme.labelFont(10))
                .foregroundStyle(DJTheme.textSecondary)
                .textCase(.uppercase)

            Text(value)
                .font(DJTheme.monoFont(13, weight: .black))
                .foregroundStyle(DJTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActiveRunBoost: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let accent: Color
}

private struct ActiveRunBoostChip: View {
    let boost: ActiveRunBoost

    var body: some View {
        Label(boost.title, systemImage: boost.iconName)
            .font(DJTheme.labelFont(11))
            .foregroundStyle(boost.accent)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(boost.accent.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(boost.accent.opacity(0.42), lineWidth: 1)
            )
            .accessibilityLabel(boost.title)
    }
}

private struct JumpReadinessMeter: View {
    let energy: Double
    let fill: Color
    let highContrast: Bool
    let reduceMotion: Bool

    private var normalizedEnergy: Double {
        min(max(energy, 0), 1)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Label("Jump Readiness", systemImage: "bolt.fill")
                    .font(DJTheme.labelFont(10))
                    .foregroundStyle(DJTheme.textSecondary)

                Spacer(minLength: 0)

                Text(normalizedEnergy.formatted(.percent.precision(.fractionLength(0))))
                    .font(DJTheme.monoFont(12, weight: .black))
                    .foregroundStyle(fill)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DJTheme.line)

                    Capsule()
                        .fill(fill)
                        .frame(width: proxy.size.width * CGFloat(normalizedEnergy))
                }
            }
            .frame(height: highContrast ? 10 : 7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Jump readiness")
        .accessibilityValue(normalizedEnergy.formatted(.percent.precision(.fractionLength(0))))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: normalizedEnergy)
    }
}

private struct CompactResultPill: View {
    let result: RoundResult

    private var accent: Color {
        result.outcome == .banked ? DJTheme.signalMint : DJTheme.riskRed
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.outcome == .banked ? "checkmark.seal.fill" : "xmark.circle.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.outcome.title)
                    .font(DJTheme.labelFont(12))
                    .foregroundStyle(DJTheme.textPrimary)

                Text("Step \(result.highestStep) | \(result.multiplier.formatted(.number.precision(.fractionLength(2))))x")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .lineLimit(1)
            }

            Text("\(result.score.formatted(.number))")
                .font(DJTheme.monoFont(13, weight: .black))
                .foregroundStyle(result.outcome == .banked ? DJTheme.voltAmber : DJTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(DJTheme.deepDeck.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    GameView()
        .environment(DuperGameStore.preview)
}
