import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    private(set) var fcmToken: String?
    var tokenUpdatedHandler: ((String) -> Void)?
    var notificationURLHandler: ((URL) -> Void)?
    private var pendingNotificationURL: URL?

    private init() { }

    func updateToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        fcmToken = token
        tokenUpdatedHandler?(token)
    }

    func openNotificationURL(_ url: URL) {
        if let notificationURLHandler {
            notificationURLHandler(url)
        } else {
            pendingNotificationURL = url
        }
    }

    func consumePendingNotificationURL() -> URL? {
        let url = pendingNotificationURL
        pendingNotificationURL = nil
        return url
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func canRequestAuthorization() async -> Bool {
        await authorizationStatus() == .notDetermined
    }

    func requestAuthorizationAndRegister() async {
        let granted = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }

        guard granted else { return }

        UIApplication.shared.registerForRemoteNotifications()
        await refreshFCMToken()
    }

    func refreshFCMToken() async {
        await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                Task { @MainActor in
                    self.updateToken(token)
                    continuation.resume()
                }
            }
        }
    }

    nonisolated static func notificationURL(from userInfo: [AnyHashable: Any]) -> URL? {
        if
            let urlString = userInfo["url"] as? String,
            let url = URL(string: urlString),
            !urlString.isEmpty
        {
            return url
        }

        if
            let data = userInfo["data"] as? [AnyHashable: Any],
            let url = notificationURL(from: data)
        {
            return url
        }

        if
            let aps = userInfo["aps"] as? [AnyHashable: Any],
            let url = notificationURL(from: aps)
        {
            return url
        }

        return nil
    }
}
