import SwiftUI
import UIKit
import WebKit

struct DuperWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.addUserScript(Self.inputZoomPreventionScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = Self.userAgent
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.load(URLRequest(url: url))
        context.coordinator.loadedURL = url
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }

        webView.load(URLRequest(url: url))
        context.coordinator.loadedURL = url
    }

    private static var userAgent: String {
        let systemVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(systemVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }

    private static let inputZoomPreventionScript = WKUserScript(
        source: """
        (function() {
            function applyInputZoomFix() {
                var head = document.head || document.getElementsByTagName('head')[0] || document.documentElement;
                if (!head) { return; }

                var viewport = document.querySelector('meta[name="viewport"]');
                if (!viewport) {
                    viewport = document.createElement('meta');
                    viewport.name = 'viewport';
                    head.appendChild(viewport);
                }
                viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover');

                if (!document.getElementById('duper-input-zoom-fix')) {
                    var style = document.createElement('style');
                    style.id = 'duper-input-zoom-fix';
                    style.textContent = 'input, textarea, select { font-size: 16px !important; }';
                    head.appendChild(style);
                }
            }

            applyInputZoomFix();
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', applyInputZoomFix);
            }
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: false
    )

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var loadedURL: URL?
        private var lastRequestedURL: URL?
        private var isRecoveringFromRedirectError = false

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            guard url.isHTTPFamily else {
                UIApplication.shared.open(url)
                if webView.canGoBack {
                    webView.goBack()
                }
                decisionHandler(.cancel)
                return
            }

            lastRequestedURL = url
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil, let url = navigationAction.request.url else {
                return nil
            }

            if url.isHTTPFamily {
                webView.load(navigationAction.request)
            } else {
                UIApplication.shared.open(url)
            }

            return nil
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            recoverFromTooManyRedirectsIfNeeded(webView: webView, error: error)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            recoverFromTooManyRedirectsIfNeeded(webView: webView, error: error)
        }

        private func recoverFromTooManyRedirectsIfNeeded(webView: WKWebView, error: Error) {
            let nsError = error as NSError
            guard
                nsError.domain == NSURLErrorDomain,
                nsError.code == NSURLErrorHTTPTooManyRedirects,
                !isRecoveringFromRedirectError,
                let lastRequestedURL
            else {
                return
            }

            isRecoveringFromRedirectError = true
            webView.load(URLRequest(url: lastRequestedURL))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self.isRecoveringFromRedirectError = false
            }
        }
    }
}

private extension URL {
    var isHTTPFamily: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
