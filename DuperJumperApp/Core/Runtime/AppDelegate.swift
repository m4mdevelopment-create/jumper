import AppTrackingTransparency
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
        Task {
            await requestTrackingAuthorizationAndStartAppsFlyer()
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        AppsFlyerLib.shared().registerUninstall(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
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

        if #available(iOS 14, *) {
            appsFlyer.waitForATTUserAuthorization(timeoutInterval: 5)
        }

        #if DEBUG
        appsFlyer.isDebug = true
        #endif
    }

    private func registerAppsFlyerIDProvider() {
        Task { @MainActor in
            AttributionService.shared.setAppsFlyerIDProvider {
                AppsFlyerLib.shared().getAppsFlyerUID()
            }
        }
    }

    @MainActor
    static func requestTrackingAuthorizationAndStartAppsFlyer() async {
        await shared?.requestTrackingAuthorizationAndStartAppsFlyer()
    }

    @MainActor
    private func requestTrackingAuthorizationAndStartAppsFlyer() async {
        guard !didStartAppsFlyer else { return }

        if #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            debugATTStatus("will request")

            try? await Task.sleep(nanoseconds: 800_000_000)

            let currentStatus = ATTrackingManager.trackingAuthorizationStatus
            guard currentStatus == .notDetermined else {
                debugATTStatus("skipped request", status: currentStatus)
                startAppsFlyerOnce()
                return
            }

            let status = await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            debugATTStatus("request completed", status: status)
            startAppsFlyerOnce()
            return
        }

        startAppsFlyerOnce()
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

    @available(iOS 14, *)
    private func debugATTStatus(
        _ context: String,
        status: ATTrackingManager.AuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus
    ) {
        #if DEBUG
        let label: String
        switch status {
        case .notDetermined:
            label = "notDetermined"
        case .restricted:
            label = "restricted"
        case .denied:
            label = "denied"
        case .authorized:
            label = "authorized"
        @unknown default:
            label = "unknown"
        }

        print("[ATT] \(context): \(label)")
        #endif
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
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        AppsFlyerLib.shared().handlePushNotification(userInfo)

        if let url = PushNotificationService.notificationURL(from: userInfo) {
            Task { @MainActor in
                PushNotificationService.shared.openNotificationURL(url)
            }
        }

        completionHandler()
    }
}
