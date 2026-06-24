import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum GameplayHaptics {
    static func playJumpLanded(isEnabled: Bool) {
        guard isEnabled else { return }

        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.55)
        #endif
    }

    static func playNearMiss(isEnabled: Bool) {
        guard isEnabled else { return }

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    static func playBonusTriggered(isEnabled: Bool) {
        guard isEnabled else { return }

        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.prepare()
        impact.impactOccurred(intensity: 0.72)

        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)
        #endif
    }

    static func playShieldSaved(isEnabled: Bool) {
        guard isEnabled else { return }

        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
        #endif
    }

    static func playCollect(isEnabled: Bool) {
        guard isEnabled else { return }

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    static func playFail(isEnabled: Bool) {
        guard isEnabled else { return }

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }
}
