import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    private static weak var shared: AppDelegate?
    private static var didConfigureFirebase = false
    private var didStartAppsFlyer = false
    private var supportedOrientationMask = AppDelegate.defaultSupportedOrientationMask

    override init() {
        Self.configureFirebaseIfNeeded()
        super.init()
        Self.shared = self
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.configureFirebaseIfNeeded()

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        configureAppsFlyer()
        logPush(
            "did-finish-launching",
            details: [
                "launchOptionsKeys=\(Self.launchOptionKeysDescription(launchOptions))",
                "hasRemoteNotification=\(launchOptions?[.remoteNotification] != nil)"
            ]
        )
        handleLaunchNotificationIfNeeded(launchOptions)
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        supportedOrientationMask
    }

    private static func configureFirebaseIfNeeded() {
        guard !didConfigureFirebase else { return }
        FirebaseApp.configure()
        didConfigureFirebase = true
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

    func applicationDidBecomeActive(_ application: UIApplication) {
        logPush("did-become-active")
        Task { @MainActor in
            startAppsFlyerOnce()
            PushNotificationService.shared.deliverPendingNotificationURLIfPossible(source: "application-did-become-active")
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        logPush("will-enter-foreground")
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        logPush(
            "did-register-apns-token",
            details: ["token=\(Self.redactedDeviceToken(deviceToken))"]
        )
        Messaging.messaging().apnsToken = deviceToken
        AppsFlyerLib.shared().registerUninstall(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        logPush("did-receive-remote-notification-fetch", userInfo: userInfo)
        AppsFlyerLib.shared().handlePushNotification(userInfo)

        completionHandler(.noData)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    private func configureAppsFlyer() {
        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.appsFlyerDevKey = AppConfiguration.appsFlyerDevKey
        appsFlyer.appleAppID = AppConfiguration.appleAppID
        appsFlyer.delegate = self
        appsFlyer.deepLinkDelegate = self
        registerAppsFlyerIDProvider()

        #if DEBUG
        appsFlyer.isDebug = true
        #endif
    }

    private func handleLaunchNotificationIfNeeded(
        _ launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        guard
            let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any]
        else {
            logPush("cold-start-no-remote-notification")
            return
        }

        logPush("cold-start-remote-notification", userInfo: userInfo)
        handleNotificationOpen(userInfo)
    }

    private func handleNotificationOpen(_ userInfo: [AnyHashable: Any]) {
        logPush("notification-open-received", userInfo: userInfo)
        AppsFlyerLib.shared().handlePushNotification(userInfo)

        guard let url = PushNotificationService.notificationURL(from: userInfo) else {
            logPush("notification-open-no-http-url", userInfo: userInfo)
            return
        }

        logPush("notification-open-url-selected", details: ["url=\(url.absoluteString)"])

        Task { @MainActor in
            PushNotificationService.shared.openNotificationURL(url)
        }
    }

    private func registerAppsFlyerIDProvider() {
        Task { @MainActor in
            AttributionService.shared.setAppsFlyerIDProvider {
                AppsFlyerLib.shared().getAppsFlyerUID()
            }
        }
    }

    @MainActor
    static func startAppsFlyerForLaunch() {
        shared?.startAppsFlyerOnce()
    }

    @MainActor
    private func startAppsFlyerOnce() {
        guard !didStartAppsFlyer else { return }

        didStartAppsFlyer = true
        AppsFlyerLib.shared().start()

        let appsFlyerID = AppsFlyerLib.shared().getAppsFlyerUID()
        Task { @MainActor in
            AttributionService.shared.recordAppsFlyerID(appsFlyerID)
        }
    }

    private func logPush(
        _ event: String,
        userInfo: [AnyHashable: Any]? = nil,
        details: [String] = []
    ) {
        var components = [
            "[DuperPush]",
            "AppDelegate",
            event,
            "appState=\(UIApplication.shared.applicationState.duperPushDebugLabel)"
        ]
        components.append(contentsOf: details)

        if let userInfo {
            components.append("payloadKeys=\(Self.payloadKeysDescription(userInfo))")
            components.append("payload=\(Self.payloadDescription(userInfo))")
        }

        NSLog("%@", components.joined(separator: " | "))
    }

    nonisolated private static func launchOptionKeysDescription(
        _ launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> String {
        guard let launchOptions, !launchOptions.isEmpty else { return "none" }

        return launchOptions.keys
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }

    nonisolated private static func payloadKeysDescription(_ userInfo: [AnyHashable: Any]) -> String {
        userInfo.keys
            .map { String(describing: $0) }
            .sorted()
            .joined(separator: ",")
    }

    nonisolated private static func payloadDescription(_ userInfo: [AnyHashable: Any]) -> String {
        let normalized = normalizePayloadValue(userInfo)

        guard
            JSONSerialization.isValidJSONObject(normalized),
            let data = try? JSONSerialization.data(
                withJSONObject: normalized,
                options: [.sortedKeys]
            ),
            let string = String(data: data, encoding: .utf8)
        else {
            return String(describing: userInfo)
        }

        return string
    }

    nonisolated private static func normalizePayloadValue(_ value: Any) -> Any {
        if let dictionary = value as? [AnyHashable: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                result[String(describing: entry.key)] = normalizePayloadValue(entry.value)
            }
        }

        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                result[entry.key] = normalizePayloadValue(entry.value)
            }
        }

        if let array = value as? [Any] {
            return array.map(normalizePayloadValue)
        }

        if let number = value as? NSNumber {
            return number
        }

        if let string = value as? String {
            return string
        }

        if let url = value as? URL {
            return url.absoluteString
        }

        return String(describing: value)
    }

    nonisolated private static func redactedDeviceToken(_ data: Data) -> String {
        let token = data.map { String(format: "%02x", $0) }.joined()
        guard token.count > 12 else { return "length=\(token.count)" }

        return "\(token.prefix(6))...\(token.suffix(6)) length=\(token.count)"
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        Task { @MainActor in
            AttributionService.shared.recordConversionData(installData)
        }
    }

    func onConversionDataFail(_ error: Error) {
        Task { @MainActor in
            AttributionService.shared.recordConversionFailure()
        }
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        Task { @MainActor in
            AttributionService.shared.recordDeepLinkData(attributionData)
        }
    }

    func onAppOpenAttributionFailure(_ error: Error) { }
}

extension AppDelegate: DeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard result.status == .found, let deepLink = result.deepLink else { return }

        var data = deepLink.clickEvent
        if let value = deepLink.deeplinkValue {
            data["deep_link_value"] = value
        }

        Task { @MainActor in
            AttributionService.shared.recordDeepLinkData(data)
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        logPush(
            "did-receive-fcm-token",
            details: ["token=\(Self.redactedStringToken(fcmToken))"]
        )
        Task { @MainActor in
            PushNotificationService.shared.updateToken(fcmToken)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logPush(
            "will-present-notification",
            userInfo: notification.request.content.userInfo,
            details: [
                "requestIdentifier=\(notification.request.identifier)",
                "category=\(notification.request.content.categoryIdentifier)"
            ]
        )
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        logPush(
            "did-receive-notification-response",
            userInfo: userInfo,
            details: [
                "actionIdentifier=\(response.actionIdentifier)",
                "requestIdentifier=\(response.notification.request.identifier)",
                "category=\(response.notification.request.content.categoryIdentifier)"
            ]
        )
        handleNotificationOpen(userInfo)

        completionHandler()
    }
}

private extension AppDelegate {
    nonisolated static func redactedStringToken(_ token: String?) -> String {
        guard let token, !token.isEmpty else { return "nil" }
        guard token.count > 12 else { return "length=\(token.count)" }

        return "\(token.prefix(6))...\(token.suffix(6)) length=\(token.count)"
    }
}

private extension UIApplication.State {
    var duperPushDebugLabel: String {
        switch self {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}
