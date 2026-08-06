import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private static weak var shared: AppDelegate?
    private var supportedOrientationMask = AppDelegate.defaultSupportedOrientationMask

    override init() {
        super.init()
        Self.shared = self
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        supportedOrientationMask
    }

    @MainActor
    static func lockGameOrientation() {
        shared?.setSupportedOrientationMask(.portrait)
    }

    @MainActor
    static func restoreDefaultOrientations() {
        shared?.setSupportedOrientationMask(defaultSupportedOrientationMask)
    }

    private static var defaultSupportedOrientationMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    @MainActor
    private func setSupportedOrientationMask(_ mask: UIInterfaceOrientationMask) {
        supportedOrientationMask = mask

        guard let windowScene = activeWindowScene else { return }

        windowScene.windows.forEach {
            $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        if #available(iOS 16.0, *) {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }

    @MainActor
    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
}
