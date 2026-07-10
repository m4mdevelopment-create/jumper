import SwiftUI
import UIKit
import WebKit

struct DuperWebView: UIViewRepresentable {
    let url: URL
    let requestID: UUID

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
        configuration.userContentController.addUserScript(Self.casinoDiagnosticsScript)
        configuration.userContentController.add(context.coordinator, name: Self.diagnosticsHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = Self.userAgent
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.keyboardDismissMode = .interactive
        webView.inputAssistantItem.leadingBarButtonGroups = []
        webView.inputAssistantItem.trailingBarButtonGroups = []
        context.coordinator.webView = webView
        context.coordinator.log("initial-load", url: url, details: "requestID=\(requestID.uuidString)")
        context.coordinator.logCasinoNative(
            "initial-load",
            url: url,
            details: ["requestID=\(requestID.uuidString)"]
        )
        context.coordinator.resetHTTPUpgradeAttempts()
        webView.load(URLRequest(url: url))
        context.coordinator.loadedURL = url
        context.coordinator.loadedRequestID = requestID
        return webView
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: Self.diagnosticsHandlerName
        )
        coordinator.webView = nil
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url || context.coordinator.loadedRequestID != requestID else {
            context.coordinator.log(
                "update-skip",
                url: url,
                details: [
                    "requestID=\(requestID.uuidString)",
                    "webViewURL=\(webView.url?.absoluteString ?? "nil")"
                ].joined(separator: " ")
            )
            return
        }

        context.coordinator.log(
            "update-load",
            url: url,
            details: [
                "requestID=\(requestID.uuidString)",
                "previousRequestID=\(context.coordinator.loadedRequestID?.uuidString ?? "nil")",
                "webViewURL=\(webView.url?.absoluteString ?? "nil")"
            ].joined(separator: " ")
        )
        context.coordinator.logCasinoNative(
            "update-load",
            url: url,
            details: [
                "requestID=\(requestID.uuidString)",
                "previousRequestID=\(context.coordinator.loadedRequestID?.uuidString ?? "nil")",
                "webViewURL=\(webView.url?.absoluteString ?? "nil")"
            ]
        )
        context.coordinator.resetHTTPUpgradeAttempts()
        webView.load(URLRequest(url: url))
        context.coordinator.loadedURL = url
        context.coordinator.loadedRequestID = requestID
    }

    private static var userAgent: String {
        let systemVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(systemVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }

    private static let diagnosticsHandlerName = "duperDiagnostics"

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

    private static let casinoDiagnosticsScript = WKUserScript(
        source: """
        (function() {
            if (window.__duperCasinoDiagnosticsInstalled) { return; }
            window.__duperCasinoDiagnosticsInstalled = true;

            var lastViewportLogAt = 0;
            var lastInputLogAt = 0;

            function post(type, data) {
                try {
                    var payload = data || {};
                    payload.type = type;
                    payload.href = String(location.href || '');
                    payload.title = String(document.title || '');
                    payload.readyState = String(document.readyState || '');
                    payload.visibility = String(document.visibilityState || '');
                    window.webkit.messageHandlers.duperDiagnostics.postMessage(payload);
                } catch (e) {}
            }

            function compactText(value) {
                value = String(value || '').replace(/\\s+/g, ' ').trim();
                return value.length > 120 ? value.slice(0, 120) : value;
            }

            function selectorFor(element) {
                if (!element || !element.tagName) { return 'nil'; }
                var parts = [String(element.tagName).toLowerCase()];
                if (element.id) { parts.push('#' + element.id); }
                if (element.name) { parts.push('[name=' + element.name + ']'); }
                if (element.type) { parts.push('[type=' + element.type + ']'); }
                if (element.className && typeof element.className === 'string') {
                    var classes = element.className.trim().split(/\\s+/).slice(0, 3).join('.');
                    if (classes) { parts.push('.' + classes); }
                }
                return parts.join('');
            }

            function rectFor(element) {
                if (!element || !element.getBoundingClientRect) { return 'nil'; }
                var rect = element.getBoundingClientRect();
                return [
                    'x=' + Math.round(rect.x),
                    'y=' + Math.round(rect.y),
                    'w=' + Math.round(rect.width),
                    'h=' + Math.round(rect.height),
                    'top=' + Math.round(rect.top),
                    'bottom=' + Math.round(rect.bottom)
                ].join(',');
            }

            function viewportData() {
                var vv = window.visualViewport;
                return {
                    inner: Math.round(window.innerWidth || 0) + 'x' + Math.round(window.innerHeight || 0),
                    screen: Math.round(screen.width || 0) + 'x' + Math.round(screen.height || 0),
                    scroll: Math.round(window.scrollX || 0) + ',' + Math.round(window.scrollY || 0),
                    visual: vv ? [
                        Math.round(vv.width || 0) + 'x' + Math.round(vv.height || 0),
                        'offset=' + Math.round(vv.offsetLeft || 0) + ',' + Math.round(vv.offsetTop || 0),
                        'pageTop=' + Math.round(vv.pageTop || 0),
                        'scale=' + Number(vv.scale || 1).toFixed(2)
                    ].join(' ') : 'nil',
                    orientation: Math.round((screen.orientation && screen.orientation.angle) || window.orientation || 0),
                    active: selectorFor(document.activeElement)
                };
            }

            function eventElement(event) {
                var target = event.target;
                if (!target || target.nodeType !== 1) {
                    target = target && target.parentElement;
                }
                return target;
            }

            function closestInteractive(element) {
                if (!element || !element.closest) { return null; }
                return element.closest('a,button,input,textarea,select,[role="button"],[onclick],form');
            }

            function inputInfo(element) {
                var data = viewportData();
                data.element = selectorFor(element);
                data.rect = rectFor(element);
                data.valueLength = element && typeof element.value === 'string' ? element.value.length : -1;
                data.placeholder = compactText(element && element.placeholder);
                data.autocomplete = String((element && element.autocomplete) || '');
                data.inputMode = String((element && element.inputMode) || '');
                data.readOnly = !!(element && element.readOnly);
                data.disabled = !!(element && element.disabled);
                return data;
            }

            document.addEventListener('focusin', function(event) {
                post('focusin', inputInfo(eventElement(event)));
            }, true);

            document.addEventListener('focusout', function(event) {
                post('focusout', inputInfo(eventElement(event)));
            }, true);

            document.addEventListener('input', function(event) {
                var now = Date.now();
                if (now - lastInputLogAt < 250) { return; }
                lastInputLogAt = now;
                post('input', inputInfo(eventElement(event)));
            }, true);

            document.addEventListener('click', function(event) {
                var target = eventElement(event);
                var interactive = closestInteractive(target) || target;
                var link = interactive && interactive.closest ? interactive.closest('a') : null;
                post('click', Object.assign(viewportData(), {
                    element: selectorFor(target),
                    interactive: selectorFor(interactive),
                    rect: rectFor(interactive),
                    text: compactText((interactive && (interactive.innerText || interactive.textContent || interactive.value)) || ''),
                    link: link ? String(link.href || '') : ''
                }));
            }, true);

            document.addEventListener('submit', function(event) {
                var form = event.target;
                post('submit', Object.assign(viewportData(), {
                    element: selectorFor(form),
                    action: String((form && form.action) || ''),
                    method: String((form && form.method) || '')
                }));
            }, true);

            function logViewport(type) {
                var now = Date.now();
                if (type !== 'orientationchange' && now - lastViewportLogAt < 250) { return; }
                lastViewportLogAt = now;
                post(type, viewportData());
            }

            window.addEventListener('resize', function() { logViewport('window-resize'); }, true);
            window.addEventListener('orientationchange', function() { logViewport('orientationchange'); }, true);
            if (window.visualViewport) {
                window.visualViewport.addEventListener('resize', function() { logViewport('visual-viewport-resize'); }, true);
                window.visualViewport.addEventListener('scroll', function() { logViewport('visual-viewport-scroll'); }, true);
            }

            ['pagehide', 'pageshow', 'beforeunload'].forEach(function(name) {
                window.addEventListener(name, function(event) {
                    post(name, Object.assign(viewportData(), {
                        persisted: !!event.persisted
                    }));
                }, true);
            });

            document.addEventListener('visibilitychange', function() {
                post('visibilitychange', viewportData());
            }, true);

            ['pushState', 'replaceState'].forEach(function(method) {
                var original = history[method];
                if (typeof original !== 'function') { return; }
                history[method] = function() {
                    var targetURL = arguments.length > 2 && arguments[2] !== undefined ? String(arguments[2]) : '';
                    post('history-' + method, Object.assign(viewportData(), {
                        targetURL: targetURL
                    }));
                    return original.apply(this, arguments);
                };
            });

            window.addEventListener('popstate', function() { post('popstate', viewportData()); }, true);
            window.addEventListener('hashchange', function() { post('hashchange', viewportData()); }, true);

            post('diagnostics-installed', viewportData());
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var loadedURL: URL?
        var loadedRequestID: UUID?
        private var lastRequestedURL: URL?
        private var isRecoveringFromRedirectError = false
        private var focusedInputWorkItem: DispatchWorkItem?
        private var lastKeyboardWebViewSize: CGSize = .zero
        private var httpUpgradeAttempts: [String: Int] = [:]

        private static let maxHTTPUpgradeAttemptsPerURL = 3

        private enum HTTPUpgradeDecision {
            case notNeeded
            case loaded
            case blocked
        }

        override init() {
            super.init()
            registerKeyboardDiagnostics()
        }

        deinit {
            focusedInputWorkItem?.cancel()
            NotificationCenter.default.removeObserver(self)
        }

        func log(_ event: String, url: URL?, details: String? = nil) {
            var components = ["[DuperWebRedirect]", event]
            if let url {
                components.append("url=\(url.absoluteString)")
            }
            if let details, !details.isEmpty {
                components.append(details)
            }

            NSLog("%@", components.joined(separator: " | "))
        }

        func logCasinoNative(_ event: String, url: URL?, details: [String] = []) {
            var components = ["[DuperCasinoNav]", "native-\(event)"]
            if let url {
                components.append("url=\(url.absoluteString)")
            }
            components.append(contentsOf: details)

            NSLog("%@", components.joined(separator: " | "))
        }

        func resetHTTPUpgradeAttempts() {
            httpUpgradeAttempts.removeAll()
        }

        private func logCasinoKeyboard(_ event: String, details: [String] = []) {
            var components = ["[DuperCasinoKeyboard]", event]
            components.append(contentsOf: details)

            NSLog("%@", components.joined(separator: " | "))
        }

        private func logCasinoInput(_ event: String, details: [String] = []) {
            var components = ["[DuperCasinoInput]", event]
            components.append(contentsOf: details)

            NSLog("%@", components.joined(separator: " | "))
        }

        private func registerKeyboardDiagnostics() {
            let notifications: [(Notification.Name, Selector)] = [
                (UIResponder.keyboardWillShowNotification, #selector(keyboardWillShow(_:))),
                (UIResponder.keyboardDidShowNotification, #selector(keyboardDidShow(_:))),
                (UIResponder.keyboardWillHideNotification, #selector(keyboardWillHide(_:))),
                (UIResponder.keyboardDidHideNotification, #selector(keyboardDidHide(_:))),
                (UIResponder.keyboardWillChangeFrameNotification, #selector(keyboardWillChangeFrame(_:))),
                (UIResponder.keyboardDidChangeFrameNotification, #selector(keyboardDidChangeFrame(_:)))
            ]

            for (name, selector) in notifications {
                NotificationCenter.default.addObserver(
                    self,
                    selector: selector,
                    name: name,
                    object: nil
                )
            }
        }

        @objc private func keyboardWillShow(_ notification: Notification) {
            logKeyboardNotification("will-show", notification: notification)
        }

        @objc private func keyboardDidShow(_ notification: Notification) {
            logKeyboardNotification("did-show", notification: notification)
            if shouldScheduleFocusedInputVisibilityCheck() {
                scheduleFocusedInputVisibilityCheck(source: "keyboard-did-show")
            }
        }

        @objc private func keyboardWillHide(_ notification: Notification) {
            logKeyboardNotification("will-hide", notification: notification)
        }

        @objc private func keyboardDidHide(_ notification: Notification) {
            logKeyboardNotification("did-hide", notification: notification)
            focusedInputWorkItem?.cancel()
            lastKeyboardWebViewSize = .zero
        }

        @objc private func keyboardWillChangeFrame(_ notification: Notification) {
            logKeyboardNotification("will-change-frame", notification: notification)
        }

        @objc private func keyboardDidChangeFrame(_ notification: Notification) {
            logKeyboardNotification("did-change-frame", notification: notification)
        }

        private func logKeyboardNotification(_ event: String, notification: Notification) {
            let userInfo = notification.userInfo ?? [:]
            let beginFrame = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect) ?? .null
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .null
            let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? -1
            let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue ?? -1

            logCasinoKeyboard(
                event,
                details: [
                    "begin=\(Self.rectDescription(beginFrame))",
                    "end=\(Self.rectDescription(endFrame))",
                    "duration=\(String(format: "%.3f", duration))",
                    "curve=\(curve)",
                    "orientation=\(UIDevice.current.orientation.debugLabel)"
                ]
            )
        }

        private func shouldScheduleFocusedInputVisibilityCheck() -> Bool {
            guard let webView else { return false }

            let currentSize = webView.bounds.size
            let isLandscape = currentSize.width > currentSize.height
            let hadPreviousSize = lastKeyboardWebViewSize != .zero
            let wasPortrait = lastKeyboardWebViewSize.height > lastKeyboardWebViewSize.width
            lastKeyboardWebViewSize = currentSize

            guard isLandscape else { return false }
            return !hadPreviousSize || wasPortrait
        }

        private func scheduleFocusedInputVisibilityCheck(source: String) {
            guard let webView, webView.bounds.width > webView.bounds.height else { return }

            focusedInputWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.ensureFocusedInputVisible(source: source)
            }
            focusedInputWorkItem = workItem

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }

        private func ensureFocusedInputVisible(source: String) {
            guard let webView, webView.bounds.width > webView.bounds.height else { return }

            let script = """
            (function() {
                var element = document.activeElement;
                if (!element || !element.matches) {
                    return { status: 'no-active-element' };
                }

                var isEditable = element.matches('input, textarea, select, [contenteditable=""], [contenteditable="true"]');
                if (!isEditable) {
                    return { status: 'not-editable', element: element.tagName ? element.tagName.toLowerCase() : 'unknown' };
                }

                var vv = window.visualViewport;
                if (!vv) {
                    return { status: 'no-visual-viewport' };
                }

                var topLimit = Math.max(0, vv.offsetTop) + 10;
                var bottomLimit = vv.offsetTop + vv.height - 10;

                function isVisible(rect) {
                    return rect.top >= topLimit && rect.bottom <= bottomLimit;
                }

                function scrollableAncestors(node) {
                    var ancestors = [];
                    var current = node.parentElement;

                    while (current && current !== document.body && current !== document.documentElement) {
                        if (current.scrollHeight > current.clientHeight + 1) {
                            ancestors.push(current);
                        }
                        current = current.parentElement;
                    }

                    var scrollingElement = document.scrollingElement || document.documentElement;
                    if (scrollingElement) {
                        ancestors.push(scrollingElement);
                    }

                    return ancestors;
                }

                function labelFor(node) {
                    if (!node || !node.tagName) { return 'unknown'; }
                    return [
                        node.tagName.toLowerCase(),
                        node.id ? ('#' + node.id) : '',
                        node.className && typeof node.className === 'string' ? ('.' + node.className.trim().split(/\\s+/).slice(0, 2).join('.')) : ''
                    ].join('');
                }

                function centerDelta(rect) {
                    var visibleHeight = Math.max(1, bottomLimit - topLimit);
                    var targetTop = topLimit + Math.max(0, (visibleHeight - rect.height) / 2);
                    return rect.top - targetTop;
                }

                var rect = element.getBoundingClientRect();
                var wasHidden = !isVisible(rect);
                var actions = [];

                if (wasHidden) {
                    element.scrollIntoView({
                        block: 'center',
                        inline: 'nearest',
                        behavior: 'auto'
                    });
                    actions.push('scrollIntoView');

                    var ancestors = scrollableAncestors(element);
                    for (var pass = 0; pass < 3; pass++) {
                        var currentRect = element.getBoundingClientRect();
                        if (isVisible(currentRect)) { break; }

                        var delta = centerDelta(currentRect);
                        if (Math.abs(delta) < 1) { break; }

                        for (var i = 0; i < ancestors.length; i++) {
                            var ancestor = ancestors[i];
                            var beforeScroll = ancestor.scrollTop;
                            var maxScroll = Math.max(0, ancestor.scrollHeight - ancestor.clientHeight);
                            var nextScroll = Math.max(0, Math.min(maxScroll, beforeScroll + delta));

                            if (Math.abs(nextScroll - beforeScroll) < 1) { continue; }

                            ancestor.scrollTop = nextScroll;
                            actions.push(labelFor(ancestor) + ':' + Math.round(beforeScroll) + '->' + Math.round(ancestor.scrollTop));
                            break;
                        }
                    }
                }

                var updatedRect = element.getBoundingClientRect();
                var finalVisible = isVisible(updatedRect);
                return {
                    status: wasHidden ? (finalVisible ? 'scrolled-visible' : 'scrolled-still-hidden') : 'visible',
                    element: [
                        element.tagName ? element.tagName.toLowerCase() : 'unknown',
                        element.id ? ('#' + element.id) : '',
                        element.name ? ('[name=' + element.name + ']') : '',
                        element.type ? ('[type=' + element.type + ']') : ''
                    ].join(''),
                    before: 'top=' + Math.round(rect.top) + ',bottom=' + Math.round(rect.bottom),
                    after: 'top=' + Math.round(updatedRect.top) + ',bottom=' + Math.round(updatedRect.bottom),
                    actions: actions.join(';'),
                    visual: Math.round(vv.width) + 'x' + Math.round(vv.height) + ' offset=' + Math.round(vv.offsetLeft) + ',' + Math.round(vv.offsetTop) + ' pageTop=' + Math.round(vv.pageTop),
                    scroll: Math.round(window.scrollX || 0) + ',' + Math.round(window.scrollY || 0)
                };
            })();
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                var details = ["source=\(source)"]

                if let error {
                    details.append("error=\(error.localizedDescription)")
                } else if let result = result as? [String: Any] {
                    for key in ["status", "element", "before", "after", "actions", "visual", "scroll"] {
                        if let value = result[key] {
                            details.append("\(key)=\(Self.shortValueDescription(value))")
                        }
                    }
                } else if let result {
                    details.append("result=\(Self.shortValueDescription(result))")
                } else {
                    details.append("result=nil")
                }

                self?.logCasinoInput("native-focused-input-visibility-check", details: details)
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == DuperWebView.diagnosticsHandlerName,
                let body = message.body as? [String: Any],
                let type = body["type"] as? String
            else {
                logCasino("[DuperCasinoJS]", event: "invalid-message", body: [:])
                return
            }

            logCasino(Self.casinoTag(for: type), event: type, body: body)
        }

        private func logCasino(_ tag: String, event: String, body: [String: Any]) {
            let ignoredKeys = Set(["type"])
            var components = [tag, event]

            for key in body.keys.map({ String($0) }).sorted() where !ignoredKeys.contains(key) {
                let value = body[key] ?? ""
                components.append("\(key)=\(Self.shortValueDescription(value))")
            }

            NSLog("%@", components.joined(separator: " | "))
        }

        private static func casinoTag(for event: String) -> String {
            switch event {
            case "focusin", "focusout", "input":
                return "[DuperCasinoInput]"
            case "window-resize", "orientationchange", "visual-viewport-resize", "visual-viewport-scroll":
                return "[DuperCasinoViewport]"
            case "click", "submit",
                 "history-pushState", "history-replaceState",
                 "popstate", "hashchange",
                 "pagehide", "pageshow", "beforeunload", "visibilitychange",
                 "diagnostics-installed":
                return "[DuperCasinoNav]"
            default:
                return "[DuperCasinoJS]"
            }
        }

        private static func shortValueDescription(_ value: Any) -> String {
            let description: String
            if let string = value as? String {
                description = string
            } else if let number = value as? NSNumber {
                description = number.stringValue
            } else if let bool = value as? Bool {
                description = bool ? "true" : "false"
            } else {
                description = String(describing: value)
            }

            let sanitized = description
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            guard sanitized.count > 500 else { return sanitized }
            return "\(sanitized.prefix(500))..."
        }

        private static func rectDescription(_ rect: CGRect) -> String {
            guard !rect.isNull else { return "null" }

            return [
                "x=\(Int(rect.origin.x.rounded()))",
                "y=\(Int(rect.origin.y.rounded()))",
                "w=\(Int(rect.width.rounded()))",
                "h=\(Int(rect.height.rounded()))"
            ].joined(separator: ",")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                log(
                    "decide-policy-no-url",
                    url: nil,
                    details: "type=\(navigationAction.navigationType.debugLabel)"
                )
                decisionHandler(.allow)
                return
            }

            log(
                "decide-policy",
                url: url,
                details: [
                    "type=\(navigationAction.navigationType.debugLabel)",
                    "target=\(navigationAction.targetFrame?.debugLabel ?? "nil")",
                    "mainDocument=\(navigationAction.request.mainDocumentURL?.absoluteString ?? "nil")"
                ].joined(separator: " ")
            )
            logCasinoNative(
                "decide-policy",
                url: url,
                details: [
                    "type=\(navigationAction.navigationType.debugLabel)",
                    "target=\(navigationAction.targetFrame?.debugLabel ?? "nil")",
                    "mainDocument=\(navigationAction.request.mainDocumentURL?.absoluteString ?? "nil")"
                ]
            )

            if url.isWebViewInternalScheme {
                log(
                    "internal-webview-url-allow",
                    url: url,
                    details: "target=\(navigationAction.targetFrame?.debugLabel ?? "nil")"
                )
                logCasinoNative(
                    "internal-webview-url-allow",
                    url: url,
                    details: ["target=\(navigationAction.targetFrame?.debugLabel ?? "nil")"]
                )
                decisionHandler(.allow)
                return
            }

            if navigationAction.targetFrame?.isMainFrame ?? true {
                switch upgradeHTTPNavigationIfNeeded(
                    request: navigationAction.request,
                    url: url,
                    webView: webView,
                    source: "decide-policy"
                ) {
                case .notNeeded:
                    break
                case .loaded, .blocked:
                    decisionHandler(.cancel)
                    return
                }
            }

            guard url.isHTTPFamily else {
                log("external-open-cancel-webview", url: url)
                logCasinoNative("external-open-cancel-webview", url: url)
                UIApplication.shared.open(url)
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
                log(
                    "create-webview-ignored",
                    url: navigationAction.request.url,
                    details: "target=\(navigationAction.targetFrame?.debugLabel ?? "non-nil")"
                )
                return nil
            }

            log("create-webview-target-blank", url: url)
            logCasinoNative("create-webview-target-blank", url: url)

            switch upgradeHTTPNavigationIfNeeded(
                request: navigationAction.request,
                url: url,
                webView: webView,
                source: "target-blank"
            ) {
            case .loaded, .blocked:
                return nil
            case .notNeeded:
                break
            }

            if url.isHTTPFamily {
                webView.load(navigationAction.request)
            } else if url.isWebViewInternalScheme {
                log("target-blank-internal-url-skip-external-open", url: url)
                logCasinoNative("target-blank-internal-url-skip-external-open", url: url)
            } else {
                log("target-blank-external-open", url: url)
                logCasinoNative("target-blank-external-open", url: url)
                UIApplication.shared.open(url)
            }

            return nil
        }

        private func upgradeHTTPNavigationIfNeeded(
            request: URLRequest,
            url: URL,
            webView: WKWebView,
            source: String
        ) -> HTTPUpgradeDecision {
            guard let upgradedURL = url.httpUpgradedToHTTPS else {
                return .notNeeded
            }

            let attemptKey = url.absoluteString
            let attempt = (httpUpgradeAttempts[attemptKey] ?? 0) + 1
            httpUpgradeAttempts[attemptKey] = attempt

            guard attempt <= Self.maxHTTPUpgradeAttemptsPerURL else {
                let details = [
                    "source=\(source)",
                    "attempt=\(attempt)",
                    "maxAttempts=\(Self.maxHTTPUpgradeAttemptsPerURL)",
                    "upgradedURL=\(upgradedURL.absoluteString)",
                    "reason=possible-http-downgrade-loop"
                ].joined(separator: " ")
                log("http-to-https-upgrade-blocked", url: url, details: details)
                logCasinoNative("http-to-https-upgrade-blocked", url: url, details: details.components(separatedBy: " "))
                return .blocked
            }

            var upgradedRequest = request
            upgradedRequest.url = upgradedURL
            lastRequestedURL = upgradedURL

            let details = [
                "source=\(source)",
                "attempt=\(attempt)",
                "upgradedURL=\(upgradedURL.absoluteString)"
            ].joined(separator: " ")
            log("http-to-https-upgrade-load", url: url, details: details)
            logCasinoNative("http-to-https-upgrade-load", url: url, details: details.components(separatedBy: " "))
            DispatchQueue.main.async { [weak webView] in
                webView?.load(upgradedRequest)
            }
            return .loaded
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            log(
                "did-start-provisional",
                url: webView.url ?? lastRequestedURL,
                details: "lastRequested=\(lastRequestedURL?.absoluteString ?? "nil")"
            )
            logCasinoNative(
                "did-start-provisional",
                url: webView.url ?? lastRequestedURL,
                details: ["lastRequested=\(lastRequestedURL?.absoluteString ?? "nil")"]
            )
        }

        func webView(
            _ webView: WKWebView,
            didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
        ) {
            log(
                "did-receive-server-redirect",
                url: webView.url ?? lastRequestedURL,
                details: "lastRequested=\(lastRequestedURL?.absoluteString ?? "nil")"
            )
            logCasinoNative(
                "did-receive-server-redirect",
                url: webView.url ?? lastRequestedURL,
                details: ["lastRequested=\(lastRequestedURL?.absoluteString ?? "nil")"]
            )
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            log("did-commit", url: webView.url ?? lastRequestedURL)
            logCasinoNative("did-commit", url: webView.url ?? lastRequestedURL)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            resetHTTPUpgradeAttempts()
            log("did-finish", url: webView.url ?? lastRequestedURL)
            logCasinoNative("did-finish", url: webView.url ?? lastRequestedURL)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            logFailure("did-fail-provisional", webView: webView, error: error)
            logCasinoFailure("did-fail-provisional", webView: webView, error: error)
            recoverFromTooManyRedirectsIfNeeded(webView: webView, error: error)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            logFailure("did-fail", webView: webView, error: error)
            logCasinoFailure("did-fail", webView: webView, error: error)
            recoverFromTooManyRedirectsIfNeeded(webView: webView, error: error)
        }

        private func logFailure(_ event: String, webView: WKWebView, error: Error) {
            let nsError = error as NSError
            log(
                event,
                url: webView.url ?? lastRequestedURL,
                details: [
                    "domain=\(nsError.domain)",
                    "code=\(nsError.code)",
                    "description=\(nsError.localizedDescription)",
                    "failingURL=\(Self.errorURL(nsError, key: NSURLErrorFailingURLErrorKey)?.absoluteString ?? "nil")",
                    "failingURLString=\(Self.errorString(nsError, key: NSURLErrorFailingURLStringErrorKey) ?? "nil")",
                    "lastRequested=\(lastRequestedURL?.absoluteString ?? "nil")"
                ].joined(separator: " ")
            )
        }

        private static func errorURL(_ error: NSError, key: String) -> URL? {
            error.userInfo[key] as? URL
        }

        private static func errorString(_ error: NSError, key: String) -> String? {
            error.userInfo[key] as? String
        }

        private func logCasinoFailure(_ event: String, webView: WKWebView, error: Error) {
            let nsError = error as NSError
            logCasinoNative(
                event,
                url: webView.url ?? lastRequestedURL,
                details: [
                    "domain=\(nsError.domain)",
                    "code=\(nsError.code)",
                    "description=\(nsError.localizedDescription)",
                    "failingURL=\(Self.errorURL(nsError, key: NSURLErrorFailingURLErrorKey)?.absoluteString ?? "nil")",
                    "failingURLString=\(Self.errorString(nsError, key: NSURLErrorFailingURLStringErrorKey) ?? "nil")",
                    "lastRequested=\(lastRequestedURL?.absoluteString ?? "nil")"
                ]
            )
        }

        private func recoverFromTooManyRedirectsIfNeeded(webView: WKWebView, error: Error) {
            let nsError = error as NSError
            guard
                nsError.domain == NSURLErrorDomain,
                nsError.code == NSURLErrorHTTPTooManyRedirects
            else {
                return
            }

            log(
                "too-many-redirects",
                url: lastRequestedURL,
                details: "isRecovering=\(isRecoveringFromRedirectError)"
            )

            guard !isRecoveringFromRedirectError, let lastRequestedURL else {
                log("too-many-redirects-recovery-skipped", url: self.lastRequestedURL)
                return
            }

            isRecoveringFromRedirectError = true
            log("too-many-redirects-recovery-load", url: lastRequestedURL)
            webView.load(URLRequest(url: lastRequestedURL))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self.isRecoveringFromRedirectError = false
                self.log("too-many-redirects-recovery-reset", url: lastRequestedURL)
            }
        }
    }
}

private extension WKNavigationType {
    var debugLabel: String {
        switch self {
        case .linkActivated:
            return "linkActivated"
        case .formSubmitted:
            return "formSubmitted"
        case .backForward:
            return "backForward"
        case .reload:
            return "reload"
        case .formResubmitted:
            return "formResubmitted"
        case .other:
            return "other"
        @unknown default:
            return "unknown"
        }
    }
}

private extension WKFrameInfo {
    var debugLabel: String {
        isMainFrame ? "main" : "child"
    }
}

private extension UIDeviceOrientation {
    var debugLabel: String {
        switch self {
        case .unknown:
            return "unknown"
        case .portrait:
            return "portrait"
        case .portraitUpsideDown:
            return "portraitUpsideDown"
        case .landscapeLeft:
            return "landscapeLeft"
        case .landscapeRight:
            return "landscapeRight"
        case .faceUp:
            return "faceUp"
        case .faceDown:
            return "faceDown"
        @unknown default:
            return "unknown"
        }
    }
}

private extension URL {
    var isHTTPFamily: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    var httpUpgradedToHTTPS: URL? {
        guard
            scheme?.lowercased() == "http",
            var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        components.scheme = "https"
        return components.url
    }

    var isWebViewInternalScheme: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "about" || scheme == "blob" || scheme == "data" || scheme == "javascript"
    }
}
