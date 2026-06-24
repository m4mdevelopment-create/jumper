import SwiftUI

struct GameSceneLandingVisual: Equatable {
    let triggerID: Int
    let fromStep: Int
    let landedStep: Int
    let pointsDelta: Int
    let event: StepEvent
}

struct GameSceneFailVisual: Equatable {
    let triggerID: Int
    let fromStep: Int
    let targetStep: Int
    let displayedHeight: Int
    let previousDisplayedHeight: Int
    let lostPoints: Int
    let bestStep: Int
    let lastEvent: StepEvent?
}

struct JumperGameSceneView: View {
    let currentHeight: Int
    let bestHeight: Int
    let previousHeight: Int?
    let nextRisk: Double
    let currentEvent: StepEvent?
    let isActive: Bool
    let reduceMotion: Bool
    let landingVisual: GameSceneLandingVisual?
    let failVisual: GameSceneFailVisual?
    let onJumpRequested: () -> Void

    @State private var scenePhase: JumperScenePhase = .idle
    @State private var landingPulseStep: Int?
    @State private var scorePop: GameSceneLandingVisual?
    @State private var scorePopVisible = false
    @State private var bonusBurst: GameSceneLandingVisual?
    @State private var bonusBurstVisible = false
    @State private var failFlashVisible = false
    @State private var showFailOverlay = false
    @State private var missedEffectTrigger = 0

    private let visibleStepCount = 10

    private var anchorStep: Int {
        failVisual?.fromStep ?? currentHeight
    }

    private var visibleFloor: Int {
        max(0, anchorStep - 3)
    }

    private var visibleTop: Int {
        visibleFloor + visibleStepCount - 1
    }

    private var visibleSteps: [Int] {
        Array(visibleFloor...visibleTop)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let currentPlatformY = yPosition(for: anchorStep, in: size)
            let currentX = platformX(for: anchorStep, in: size)
            let spriteWidth = min(size.width * 0.25, 94)
            let spriteHeight = min(size.width * 0.34, 128)
            let spritePosition = jumperPosition(
                fromX: currentX,
                fromPlatformY: currentPlatformY,
                spriteHeight: spriteHeight,
                in: size
            )

            ZStack {
                ArcadeTowerBackground()

                if failFlashVisible {
                    SceneFailFlash()
                        .transition(.opacity)
                }

                ForEach(visibleSteps, id: \.self) { step in
                    let risk = GameProgress.jumpRisk(for: max(step - 1, 0))
                    let isTapTarget = isActive && failVisual == nil && step == currentHeight + 1
                    let isMissedTarget = failVisual?.targetStep == step
                    let isFailAnchor = failVisual?.fromStep == step
                    ScenePlatformView(
                        step: step,
                        state: platformState(for: step),
                        risk: risk,
                        nextRisk: nextRisk,
                        event: step == anchorStep ? currentEvent : nil,
                        isTapTarget: isTapTarget,
                        landingPulse: step == landingPulseStep,
                        isMissedTarget: isMissedTarget,
                        isFailAnchor: isFailAnchor,
                        missedEffectTrigger: missedEffectTrigger,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: platformWidth(for: step, in: size))
                    .position(x: platformX(for: step, in: size), y: yPosition(for: step, in: size))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isTapTarget else { return }
                        onJumpRequested()
                    }
                }

                if markerIsVisible(bestHeight) {
                    SceneMarkerLine(
                        title: "BEST",
                        value: bestHeight,
                        accent: DJTheme.voltAmber,
                        width: size.width
                    )
                    .position(x: size.width / 2, y: yPosition(for: bestHeight, in: size))
                }

                if let previousHeight, previousHeight != bestHeight, markerIsVisible(previousHeight) {
                    SceneMarkerLine(
                        title: "PREV",
                        value: previousHeight,
                        accent: DJTheme.pulseMagenta.opacity(0.85),
                        width: size.width
                    )
                    .position(x: size.width / 2, y: yPosition(for: previousHeight, in: size))
                }

                JumperSpriteView(
                    event: currentEvent,
                    isActive: isActive,
                    reduceMotion: reduceMotion,
                    phase: scenePhase
                )
                .frame(width: spriteWidth, height: spriteHeight)
                .position(x: spritePosition.x, y: spritePosition.y)
                .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.70), value: currentHeight)
                .animation(reduceMotion ? nil : .easeIn(duration: 0.30), value: scenePhase)

                if let scorePop, scorePopVisible {
                    SceneScorePop(points: scorePop.pointsDelta, accent: scorePop.event.sceneAccent)
                        .position(
                            x: min(platformX(for: scorePop.landedStep, in: size) + spriteWidth * 0.38, size.width - 48),
                            y: max(44, yPosition(for: scorePop.landedStep, in: size) - spriteHeight * 0.86)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.82)))
                }

                if let bonusBurst, bonusBurstVisible, bonusBurst.event.isBonus {
                    SceneBonusBurst(event: bonusBurst.event, reduceMotion: reduceMotion)
                        .frame(width: min(size.width * 0.34, 126), height: min(size.width * 0.34, 126))
                        .position(
                            x: platformX(for: bonusBurst.landedStep, in: size),
                            y: yPosition(for: bonusBurst.landedStep, in: size) - 8
                        )
                        .transition(.opacity)
                }

                SceneVignette()

                if let failVisual, showFailOverlay {
                    VStack {
                        HStack {
                            Spacer(minLength: 0)
                            SceneFailResultOverlay(failVisual: failVisual)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                    .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DJTheme.electricCyan.opacity(0.18), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, minHeight: 330)
        .onChange(of: landingVisual?.triggerID) { _, newValue in
            guard newValue != nil else { return }
            runLandingAnimation()
        }
        .onChange(of: failVisual?.triggerID) { _, newValue in
            if newValue == nil {
                resetFailState()
            } else {
                runFailAnimation()
            }
        }
        .onAppear {
            if failVisual != nil {
                runFailAnimation()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jumper scene. Current Step \(currentHeight). Best Step \(bestHeight).")
    }

    private func runLandingAnimation() {
        guard let landingVisual else { return }

        showFailOverlay = false
        failFlashVisible = false
        landingPulseStep = nil
        scorePop = nil
        scorePopVisible = false
        bonusBurst = nil
        bonusBurstVisible = false

        if reduceMotion {
            scenePhase = .landed
            landingPulseStep = landingVisual.landedStep
            scorePop = landingVisual.pointsDelta > 0 ? landingVisual : nil
            scorePopVisible = landingVisual.pointsDelta > 0
            bonusBurst = landingVisual.event.isBonus ? landingVisual : nil
            bonusBurstVisible = landingVisual.event.isBonus
            clearLandingEffects(after: .milliseconds(520), triggerID: landingVisual.triggerID)
            return
        }

        withAnimation(.easeOut(duration: 0.15)) {
            scenePhase = .jumping
        }

        let triggerID = landingVisual.triggerID
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            guard self.landingVisual?.triggerID == triggerID else { return }

            withAnimation(.spring(response: 0.26, dampingFraction: 0.58)) {
                scenePhase = .landed
                landingPulseStep = landingVisual.landedStep
                scorePop = landingVisual.pointsDelta > 0 ? landingVisual : nil
                scorePopVisible = landingVisual.pointsDelta > 0
                bonusBurst = landingVisual.event.isBonus ? landingVisual : nil
                bonusBurstVisible = landingVisual.event.isBonus
            }

            try? await Task.sleep(for: .milliseconds(420))
            guard self.landingVisual?.triggerID == triggerID else { return }

            withAnimation(.easeOut(duration: 0.18)) {
                scorePopVisible = false
                bonusBurstVisible = false
            }

            try? await Task.sleep(for: .milliseconds(130))
            guard self.landingVisual?.triggerID == triggerID else { return }

            withAnimation(.easeOut(duration: 0.16)) {
                landingPulseStep = nil
                scenePhase = .idle
            }
        }
    }

    private func clearLandingEffects(after delay: Duration, triggerID: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard self.landingVisual?.triggerID == triggerID else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                scorePopVisible = false
                bonusBurstVisible = false
                landingPulseStep = nil
                scenePhase = .idle
            }
        }
    }

    private func runFailAnimation() {
        guard let failVisual else { return }

        landingPulseStep = nil
        scorePopVisible = false
        bonusBurstVisible = false
        showFailOverlay = false
        missedEffectTrigger = failVisual.triggerID

        if reduceMotion {
            scenePhase = .fallen
            failFlashVisible = true
            showFailOverlay = true
            clearFailFlash(after: .milliseconds(180), triggerID: failVisual.triggerID)
            return
        }

        scenePhase = .idle
        withAnimation(.easeOut(duration: 0.12)) {
            failFlashVisible = true
        }

        let triggerID = failVisual.triggerID
        withAnimation(.easeOut(duration: 0.18)) {
            scenePhase = .failing
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(190))
            guard self.failVisual?.triggerID == triggerID else { return }

            withAnimation(.easeIn(duration: 0.34)) {
                scenePhase = .fallen
            }

            try? await Task.sleep(for: .milliseconds(110))
            guard self.failVisual?.triggerID == triggerID else { return }

            withAnimation(.easeOut(duration: 0.16)) {
                showFailOverlay = true
            }

            try? await Task.sleep(for: .milliseconds(180))
            guard self.failVisual?.triggerID == triggerID else { return }

            withAnimation(.easeOut(duration: 0.20)) {
                failFlashVisible = false
            }
        }
    }

    private func clearFailFlash(after delay: Duration, triggerID: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard self.failVisual?.triggerID == triggerID else { return }
            failFlashVisible = false
        }
    }

    private func resetFailState() {
        failFlashVisible = false
        showFailOverlay = false
        missedEffectTrigger = 0
        if landingVisual == nil {
            scenePhase = .idle
        }
    }

    private func markerIsVisible(_ value: Int) -> Bool {
        value > 0 && value >= visibleFloor && value <= visibleTop
    }

    private func platformState(for step: Int) -> ScenePlatformState {
        if step == anchorStep {
            .current
        } else if step < anchorStep {
            .completed
        } else if step == anchorStep + 1 {
            .next
        } else {
            .upcoming
        }
    }

    private func yPosition(for step: Int, in size: CGSize) -> CGFloat {
        let clampedStep = min(max(step, visibleFloor), visibleTop)
        let topInset: CGFloat = 32
        let bottomInset: CGFloat = 34
        let travel = max(size.height - topInset - bottomInset, 1)
        let index = CGFloat(clampedStep - visibleFloor)
        return size.height - bottomInset - travel * (index / CGFloat(visibleStepCount - 1))
    }

    private func platformX(for step: Int, in size: CGSize) -> CGFloat {
        let left = size.width * 0.29
        let center = size.width * 0.52
        let right = size.width * 0.72

        let x: CGFloat = switch step % 5 {
        case 1:
            left
        case 2:
            right
        case 3:
            size.width * 0.43
        case 4:
            size.width * 0.65
        default:
            center
        }

        let margin = min(size.width * 0.22, 86)
        return min(max(x, margin), size.width - margin)
    }

    private func platformWidth(for step: Int, in size: CGSize) -> CGFloat {
        let base = min(max(size.width * 0.44, 138), 206)
        return platformState(for: step) == .current ? base + 22 : base
    }

    private func jumperPosition(
        fromX: CGFloat,
        fromPlatformY: CGFloat,
        spriteHeight: CGFloat,
        in size: CGSize
    ) -> CGPoint {
        let baseY = max(spriteHeight * 0.58 + 6, fromPlatformY - spriteHeight * 0.47)

        guard let failVisual else {
            let jumpLift = scenePhase == .jumping ? min(size.height * 0.12, 58) : 0
            let landedDrop = scenePhase == .landed ? min(spriteHeight * 0.04, 7) : 0
            return CGPoint(x: fromX, y: baseY - jumpLift + landedDrop)
        }

        let targetX = platformX(for: failVisual.targetStep, in: size)
        let targetPlatformY = yPosition(for: failVisual.targetStep, in: size)
        let targetY = max(spriteHeight * 0.58 + 6, targetPlatformY - spriteHeight * 0.47)

        switch scenePhase {
        case .failing:
            return CGPoint(
                x: fromX + (targetX - fromX) * 0.56,
                y: min(baseY, targetY) - min(size.height * 0.10, 48)
            )
        case .fallen:
            return CGPoint(
                x: fromX + (targetX - fromX) * 0.72,
                y: size.height + spriteHeight * 0.08
            )
        default:
            return CGPoint(x: fromX, y: baseY)
        }
    }
}

private enum JumperScenePhase: Equatable {
    case idle
    case jumping
    case landed
    case failing
    case fallen
}

private enum ScenePlatformState {
    case completed
    case current
    case next
    case upcoming
}

private struct ArcadeTowerBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.020, green: 0.030, blue: 0.070),
                    Color(red: 0.055, green: 0.080, blue: 0.160),
                    Color(red: 0.125, green: 0.065, blue: 0.165)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DJTheme.deepDeck.opacity(0.46))
                        .frame(width: width * 0.09, height: height * towerHeight(index))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(towerAccent(index).opacity(0.34))
                                .frame(height: 3)
                                .padding(.horizontal, 6)
                                .padding(.top, 8)
                        }
                        .position(
                            x: width * towerX(index),
                            y: height - (height * towerHeight(index) / 2)
                        )
                }

                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(DJTheme.electricCyan.opacity(index.isMultiple(of: 2) ? 0.09 : 0.05))
                        .frame(width: 2, height: height * 0.92)
                        .position(x: width * railX(index), y: height * 0.50)
                }

                ForEach(0..<10, id: \.self) { index in
                    SceneSpark(index: index)
                        .position(
                            x: width * sparkX(index),
                            y: height * sparkY(index)
                        )
                }

                LinearGradient(
                    colors: [
                        DJTheme.pulseMagenta.opacity(0.28),
                        DJTheme.electricCyan.opacity(0.10),
                        .clear
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .frame(width: width * 0.68, height: height * 1.2)
                .rotationEffect(.degrees(-22))
                .position(x: width * 0.18, y: height * 0.60)
            }
        }
    }

    private func towerX(_ index: Int) -> CGFloat {
        [0.11, 0.25, 0.78, 0.91][index % 4]
    }

    private func towerHeight(_ index: Int) -> CGFloat {
        [0.46, 0.30, 0.38, 0.54][index % 4]
    }

    private func towerAccent(_ index: Int) -> Color {
        [DJTheme.electricCyan, DJTheme.voltAmber, DJTheme.pulseMagenta, DJTheme.signalMint][index % 4]
    }

    private func railX(_ index: Int) -> CGFloat {
        [0.18, 0.32, 0.45, 0.58, 0.72, 0.86][index % 6]
    }

    private func sparkX(_ index: Int) -> CGFloat {
        [0.16, 0.36, 0.54, 0.82, 0.72, 0.24, 0.62, 0.43, 0.91, 0.30][index % 10]
    }

    private func sparkY(_ index: Int) -> CGFloat {
        [0.11, 0.18, 0.09, 0.16, 0.27, 0.39, 0.36, 0.50, 0.45, 0.62][index % 10]
    }
}

private struct SceneSpark: View {
    let index: Int

    var body: some View {
        Group {
            if index.isMultiple(of: 4) {
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .black))
            } else {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .frame(width: 4, height: 4)
                    .rotationEffect(.degrees(45))
            }
        }
        .foregroundStyle(index.isMultiple(of: 2) ? DJTheme.voltAmber.opacity(0.32) : DJTheme.electricCyan.opacity(0.26))
    }
}

private struct ScenePlatformView: View {
    let step: Int
    let state: ScenePlatformState
    let risk: Double
    let nextRisk: Double
    let event: StepEvent?
    let isTapTarget: Bool
    let landingPulse: Bool
    let isMissedTarget: Bool
    let isFailAnchor: Bool
    let missedEffectTrigger: Int
    let reduceMotion: Bool

    @State private var pulse = false
    @State private var shake = false

    private var accent: Color {
        if isMissedTarget {
            return DJTheme.riskRed
        }

        if state == .current, let event, event.isBonus {
            return event.sceneAccent
        }

        switch state {
        case .completed:
            return DJTheme.signalMint
        case .current:
            return DJTheme.electricCyan
        case .next:
            return riskAccent(nextRisk)
        case .upcoming:
            return riskAccent(risk)
        }
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(DJTheme.void.opacity(0.34))
                .frame(height: 12)
                .blur(radius: 1.2)
                .offset(y: 18)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(platformFill)
                .frame(height: state == .current ? 34 : 28)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(isMissedTarget ? 0.42 : state == .upcoming ? 0.16 : 0.30))
                        .frame(height: 4)
                        .padding(.horizontal, 14)
                        .padding(.top, 5)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(accent.opacity(isMissedTarget ? 0.92 : state == .current ? 0.92 : 0.52), lineWidth: state == .current || isMissedTarget ? 1.4 : 1)
                )
                .shadow(color: accent.opacity(state == .current || isMissedTarget ? 0.34 : 0.14), radius: state == .current || isMissedTarget ? 16 : 9, x: 0, y: 8)

            HStack(spacing: 6) {
                platformBadge

                Spacer(minLength: 0)

                if isMissedTarget {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(DJTheme.void)
                        .frame(width: 22, height: 20)
                        .background(DJTheme.riskRed.opacity(0.92), in: Circle())
                } else if state == .current, let event, event.isBonus {
                    EventPlatformBadge(event: event)
                } else if state == .next {
                    if isTapTarget {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(DJTheme.void)
                            .frame(width: 22, height: 20)
                            .background(accent.opacity(0.86), in: Capsule())
                    }

                    RiskGem(risk: nextRisk, accent: accent)
                } else if state == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(DJTheme.void)
                        .frame(width: 20, height: 20)
                        .background(DJTheme.signalMint.opacity(0.70), in: Circle())
                }
            }
            .padding(.horizontal, 9)
        }
        .opacity(platformOpacity)
        .scaleEffect(platformScale)
        .offset(x: shakeOffset)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.58), value: landingPulse)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
        .animation(reduceMotion ? nil : .linear(duration: 0.055).repeatCount(5, autoreverses: true), value: shake)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
        .onChange(of: missedEffectTrigger) { _, newValue in
            guard newValue > 0, (isMissedTarget || isFailAnchor), !reduceMotion else { return }
            shake = false
            withAnimation(.linear(duration: 0.055).repeatCount(5, autoreverses: true)) {
                shake = true
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(330))
                shake = false
            }
        }
    }

    private var platformScale: CGFloat {
        if landingPulse {
            return 1.06
        }

        if isMissedTarget && !reduceMotion {
            return 1.035
        }

        if isTapTarget && pulse && !reduceMotion {
            return 1.025
        }

        return state == .current ? 1.01 : 1.0
    }

    private var platformOpacity: Double {
        if isMissedTarget {
            return 1.0
        }

        switch state {
        case .completed:
            return 0.66
        case .upcoming:
            return 0.78
        case .current, .next:
            return 1.0
        }
    }

    private var shakeOffset: CGFloat {
        guard shake else { return 0 }
        return isMissedTarget ? 6 : -4
    }

    private var platformBadge: some View {
        Text("\(step)")
            .font(DJTheme.monoFont(11, weight: .black))
            .foregroundStyle(state == .current ? DJTheme.void : accent)
            .frame(width: 26, height: 22)
            .background(badgeFill, in: Capsule())
    }

    private var badgeFill: AnyShapeStyle {
        switch state {
        case .current:
            AnyShapeStyle(accent)
        case .completed:
            AnyShapeStyle(DJTheme.signalMint.opacity(0.16))
        case .next:
            AnyShapeStyle(accent.opacity(0.22))
        case .upcoming:
            AnyShapeStyle(DJTheme.void.opacity(0.38))
        }
    }

    private var platformFill: AnyShapeStyle {
        if isMissedTarget {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DJTheme.riskRed.opacity(0.82), DJTheme.voltAmber.opacity(0.46)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        if state == .current, let event, event.isBonus {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [event.sceneAccent, DJTheme.electricCyan.opacity(0.86)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        switch state {
        case .completed:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DJTheme.signalMint.opacity(0.30), DJTheme.electricCyan.opacity(0.16)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .current:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DJTheme.electricCyan, DJTheme.signalMint.opacity(0.88)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .next:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [accent.opacity(0.66), DJTheme.deepDeck.opacity(0.90)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .upcoming:
            return AnyShapeStyle(accent.opacity(0.28 + min(max(risk, 0), 1) * 0.20))
        }
    }

    private func riskAccent(_ risk: Double) -> Color {
        if risk >= 0.34 {
            DJTheme.riskRed
        } else if risk >= 0.22 {
            DJTheme.voltAmber
        } else {
            DJTheme.electricCyan
        }
    }
}

private struct RiskGem: View {
    let risk: Double
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<gemCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.opacity(0.92 - Double(index) * 0.08))
                    .frame(width: 5, height: 13)
                    .rotationEffect(.degrees(12))
            }
        }
        .accessibilityLabel("Next risk \(risk.formatted(.percent.precision(.fractionLength(0))))")
    }

    private var gemCount: Int {
        if risk >= 0.34 {
            5
        } else if risk >= 0.22 {
            4
        } else {
            3
        }
    }
}

private struct SceneFailFlash: View {
    var body: some View {
        LinearGradient(
            colors: [
                DJTheme.riskRed.opacity(0.36),
                DJTheme.voltAmber.opacity(0.18),
                .clear
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
        .overlay(DJTheme.riskRed.opacity(0.10))
        .allowsHitTesting(false)
    }
}

private struct SceneScorePop: View {
    let points: Int
    let accent: Color

    var body: some View {
        Text("+\(points.formatted(.number))")
            .font(DJTheme.monoFont(18, weight: .black))
            .foregroundStyle(DJTheme.void)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.48), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.45), radius: 14, x: 0, y: 8)
            .allowsHitTesting(false)
    }
}

private struct SceneBonusBurst: View {
    let event: StepEvent
    let reduceMotion: Bool

    @State private var pulse = false

    private var accent: Color {
        event.sceneAccent
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.58), lineWidth: 3)
                .scaleEffect(pulse && !reduceMotion ? 1.20 : 0.82)
                .opacity(pulse && !reduceMotion ? 0.08 : 0.58)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.36), .clear],
                        center: .center,
                        startRadius: 1,
                        endRadius: 58
                    )
                )

            Image(systemName: event.sceneIconName)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.40), radius: 8, x: 0, y: 4)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.48)) {
                pulse = true
            }
        }
    }
}

private struct SceneFailResultOverlay: View {
    let failVisual: GameSceneFailVisual

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "figure.fall")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(DJTheme.riskRed)

                Text("Slip!")
                    .font(DJTheme.labelFont(14))
                    .foregroundStyle(DJTheme.textPrimary)
            }

            Text("Lost \(failVisual.lostPoints.formatted(.number)) pts")
                .font(DJTheme.monoFont(12, weight: .black))
                .foregroundStyle(DJTheme.riskRed)
                .lineLimit(1)

            Text("Best Step \(failVisual.bestStep)")
                .font(DJTheme.labelFont(10))
                .foregroundStyle(DJTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DJTheme.void.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DJTheme.riskRed.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: DJTheme.riskRed.opacity(0.22), radius: 14, x: 0, y: 8)
    }
}

private struct EventPlatformBadge: View {
    let event: StepEvent

    var body: some View {
        Image(systemName: event.sceneIconName)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(DJTheme.void)
            .frame(width: 24, height: 22)
            .background(Color.white.opacity(0.82), in: Capsule())
            .accessibilityLabel(event.sceneTitle)
    }
}

private struct SceneMarkerLine: View {
    let title: String
    let value: Int
    let accent: Color
    let width: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text("\(title) \(value)")
                .font(DJTheme.labelFont(9))
                .foregroundStyle(accent)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(DJTheme.void.opacity(0.62), in: Capsule())

            Rectangle()
                .fill(accent.opacity(0.40))
                .frame(height: 1)
        }
        .frame(width: width * 0.76)
        .opacity(0.78)
    }
}

private struct JumperSpriteView: View {
    let event: StepEvent?
    let isActive: Bool
    let reduceMotion: Bool
    let phase: JumperScenePhase

    private var accent: Color {
        if phase == .failing || phase == .fallen {
            return DJTheme.riskRed
        }

        return event?.sceneAccent ?? (isActive ? DJTheme.electricCyan : DJTheme.textSecondary)
    }

    private var isJumping: Bool {
        phase == .jumping
    }

    private var isLanding: Bool {
        phase == .landed
    }

    private var isFailing: Bool {
        phase == .failing
    }

    private var isFallen: Bool {
        phase == .fallen
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Capsule()
                    .fill(DJTheme.void.opacity(0.34))
                    .frame(width: size.width * 0.62, height: size.height * 0.09)
                    .blur(radius: 1.2)
                    .offset(y: size.height * 0.42)

                if (isActive && isJumping || isFailing) && !reduceMotion {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(accent.opacity(isFailing ? 0.24 - Double(index) * 0.05 : 0.30 - Double(index) * 0.07))
                            .frame(width: size.width * 0.08, height: size.height * (0.42 - CGFloat(index) * 0.06))
                            .rotationEffect(.degrees(isFailing ? 38 : -28))
                            .offset(
                                x: size.width * (isFailing ? 0.20 + CGFloat(index) * 0.07 : -0.28 - CGFloat(index) * 0.08),
                                y: size.height * (0.18 + CGFloat(index) * 0.07)
                            )
                    }
                }

                Image("JumperBoy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.98, height: size.height)
                    .shadow(color: DJTheme.void.opacity(0.45), radius: 5, x: 0, y: 3)
                    .rotationEffect(.degrees(spriteRotation))
                    .offset(y: spriteYOffset(size: size))
            }
            .scaleEffect(spriteScale)
        }
        .shadow(color: accent.opacity(isFallen ? 0.16 : 0.30), radius: isFallen ? 9 : 16, x: 0, y: 8)
    }

    private var spriteRotation: Double {
        guard !reduceMotion else { return isFallen ? 42 : 0 }

        if isFailing {
            return 28
        }

        if isFallen {
            return 74
        }

        if isJumping {
            return -7
        }

        if isLanding {
            return 3
        }

        return 0
    }

    private func spriteYOffset(size: CGSize) -> CGFloat {
        guard !reduceMotion else { return 0 }

        if isJumping {
            return -size.height * 0.05
        }

        if isLanding {
            return size.height * 0.02
        }

        if isFallen {
            return size.height * 0.12
        }

        return 0
    }

    private var spriteScale: CGFloat {
        guard !reduceMotion else { return 1.0 }

        if isJumping {
            return 1.07
        }

        if isLanding {
            return 0.95
        }

        if isFailing {
            return 1.03
        }

        if isFallen {
            return 0.94
        }

        return isActive ? 1.01 : 1.0
    }
}

private struct FallbackJumperCharacter: View {
    let accent: Color
    let isActive: Bool

    private let skin = Color(red: 1.0, green: 0.76, blue: 0.56)
    private let hair = Color(red: 0.08, green: 0.06, blue: 0.11)
    private let shorts = Color(red: 0.14, green: 0.25, blue: 0.58)

    var body: some View {
        ZStack {
            Capsule()
                .fill(skin)
                .frame(width: 8, height: 28)
                .rotationEffect(.degrees(-42))
                .offset(x: -18, y: 2)

            Capsule()
                .fill(skin)
                .frame(width: 8, height: 27)
                .rotationEffect(.degrees(40))
                .offset(x: 18, y: 1)

            Capsule()
                .fill(shorts)
                .frame(width: 9, height: 28)
                .rotationEffect(.degrees(35))
                .offset(x: -10, y: 26)

            Capsule()
                .fill(shorts)
                .frame(width: 9, height: 30)
                .rotationEffect(.degrees(-38))
                .offset(x: 13, y: 25)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, DJTheme.signalMint.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 34)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isActive ? "bolt.fill" : "play.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(DJTheme.void)
                        .padding(5)
                }

            Circle()
                .fill(skin)
                .frame(width: 26, height: 26)
                .offset(y: -29)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(hair)
                        .frame(width: 25, height: 11)
                        .offset(y: -38)
                }
        }
    }
}

private struct SceneVignette: View {
    var body: some View {
        LinearGradient(
            colors: [
                DJTheme.void.opacity(0.44),
                .clear,
                DJTheme.void.opacity(0.30)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}

private extension StepEvent {
    var sceneTitle: String {
        switch kind {
        case .normal:
            "Step"
        case .boost:
            "Boost"
        case .safe:
            "Safe Step"
        case .shield:
            "Shield"
        case .surge:
            "Surge"
        }
    }

    var sceneIconName: String {
        switch kind {
        case .normal:
            "arrow.up"
        case .boost:
            "bolt.fill"
        case .safe:
            "checkmark.shield.fill"
        case .shield:
            "shield.fill"
        case .surge:
            "sparkles"
        }
    }

    var sceneAccent: Color {
        switch kind {
        case .normal:
            DJTheme.electricCyan
        case .boost:
            DJTheme.pulseMagenta
        case .safe:
            DJTheme.electricCyan
        case .shield:
            DJTheme.stableBlue
        case .surge:
            DJTheme.voltAmber
        }
    }
}

#Preview {
    JumperGameSceneView(
        currentHeight: 5,
        bestHeight: 8,
        previousHeight: 4,
        nextRisk: 0.31,
        currentEvent: StepEvent(
            kind: .surge,
            pointsBonus: 0,
            multiplierBonus: 0,
            riskReduction: 0,
            grantsShield: false,
            surgeMultiplier: 0.5,
            duration: 1
        ),
        isActive: true,
        reduceMotion: false,
        landingVisual: GameSceneLandingVisual(
            triggerID: 1,
            fromStep: 4,
            landedStep: 5,
            pointsDelta: 120,
            event: .normal
        ),
        failVisual: nil,
        onJumpRequested: {}
    )
    .padding()
    .background(DJTheme.void)
}
