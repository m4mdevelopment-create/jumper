import Foundation
import Observation

enum AppLaunchRoute: Equatable {
    case loading(message: String)
    case noInternet(message: String)
    case fanContent
    case notificationPrompt(URL)
    case webView(URL)
}

@MainActor
@Observable
final class AppLaunchCoordinator {
    var route: AppLaunchRoute = .loading(message: "Preparing launch")

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let attributionService: AttributionService
    @ObservationIgnored private let pushService: PushNotificationService
    @ObservationIgnored private let configClient: ConfigClient
    @ObservationIgnored private var storedState: StoredLaunchState
    @ObservationIgnored private var didStart = false

    private static let storageKey = "steadyflow.launch.state.v1"
    private static let conversionWaitTimeout: TimeInterval = 5
    private static let deepLinkWaitTimeout: TimeInterval = 1
    private static let notificationPromptDelay: TimeInterval = 3 * 24 * 60 * 60

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.attributionService = AttributionService.shared
        self.pushService = PushNotificationService.shared
        self.configClient = ConfigClient()
        self.storedState = Self.loadState(from: defaults)
    }

    func start() async {
        guard !didStart else { return }
        didStart = true

        pushService.notificationURLHandler = { [weak self] url in
            self?.openNotificationURL(url)
        }
        pushService.tokenUpdatedHandler = { [weak self] _ in
            Task { @MainActor in
                await self?.refreshConfigAfterPushTokenChange()
            }
        }

        if let notificationURL = pushService.consumePendingNotificationURL() {
            openNotificationURL(notificationURL)
            return
        }

        await resolveLaunch()
    }

    func retry() {
        Task {
            await resolveLaunch()
        }
    }

    func acceptNotifications() {
        guard case .notificationPrompt(let url) = route else { return }

        Task {
            await pushService.requestAuthorizationAndRegister()
            let refreshedURL = await refreshConfigAfterPushTokenChange()
            route = .webView(refreshedURL ?? url)
        }
    }

    func skipNotifications() {
        guard case .notificationPrompt(let url) = route else { return }

        storedState.lastNotificationPromptSkipAt = .now
        persistState()
        route = .webView(url)
    }

    private func resolveLaunch() async {
        switch storedState.mode {
        case .fanContent:
            route = .fanContent
        case .webView:
            await resolveStoredWebViewLaunch()
        case nil:
            await resolveFirstLaunch()
        }
    }

    private func resolveFirstLaunch() async {
        route = .loading(message: "Checking first launch")

        let payload = await attributionService.initialPayload(
            timeout: Self.conversionWaitTimeout,
            deepLinkTimeout: Self.deepLinkWaitTimeout
        )
        let result = await configClient.fetchLink(payload: payload, pushToken: pushService.fcmToken)

        switch result {
        case .success(let url, let expiresAt):
            storedState.mode = .webView
            storedState.lastWebURL = url
            storedState.expiresAt = expiresAt
            persistState()
            await presentWebView(url)
        case .networkUnavailable:
            route = .noInternet(message: "Internet connection is required on first launch.")
        case .negative:
            storedState.mode = .fanContent
            persistState()
            route = .fanContent
        }
    }

    private func resolveStoredWebViewLaunch() async {
        guard let savedURL = storedState.lastWebURL else {
            storedState.mode = nil
            persistState()
            await resolveFirstLaunch()
            return
        }

        if let expiresAt = storedState.expiresAt, expiresAt > .now {
            await presentWebView(savedURL)
            return
        }

        route = .loading(message: "Refreshing link")
        let result = await configClient.fetchLink(
            payload: attributionService.currentPayload(),
            pushToken: pushService.fcmToken
        )

        switch result {
        case .success(let url, let expiresAt):
            storedState.lastWebURL = url
            storedState.expiresAt = expiresAt
            persistState()
            await presentWebView(url)
        case .networkUnavailable:
            route = .noInternet(message: "Internet connection is required to open WebView.")
        case .negative:
            await presentWebView(savedURL)
        }
    }

    private func presentWebView(_ url: URL) async {
        if await shouldShowNotificationPrompt() {
            route = .notificationPrompt(url)
        } else {
            route = .webView(url)
        }
    }

    private func shouldShowNotificationPrompt() async -> Bool {
        guard await pushService.canRequestAuthorization() else { return false }

        if
            let skippedAt = storedState.lastNotificationPromptSkipAt,
            Date().timeIntervalSince(skippedAt) < Self.notificationPromptDelay
        {
            return false
        }

        return true
    }

    private func openNotificationURL(_ url: URL) {
        route = .webView(url)
    }

    @discardableResult
    private func refreshConfigAfterPushTokenChange() async -> URL? {
        guard storedState.mode == .webView, pushService.fcmToken != nil else { return nil }

        let result = await configClient.fetchLink(
            payload: attributionService.currentPayload(),
            pushToken: pushService.fcmToken
        )

        guard case .success(let url, let expiresAt) = result else { return nil }
        storedState.lastWebURL = url
        storedState.expiresAt = expiresAt
        persistState()
        return url
    }

    private func persistState() {
        guard let data = try? JSONEncoder().encode(storedState) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func loadState(from defaults: UserDefaults) -> StoredLaunchState {
        guard
            let data = defaults.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(StoredLaunchState.self, from: data)
        else {
            return StoredLaunchState()
        }

        return state
    }
}

private struct StoredLaunchState: Codable {
    var mode: StoredLaunchMode?
    var lastWebURL: URL?
    var expiresAt: Date?
    var lastNotificationPromptSkipAt: Date?
}

private enum StoredLaunchMode: String, Codable {
    case webView
    case fanContent
}
