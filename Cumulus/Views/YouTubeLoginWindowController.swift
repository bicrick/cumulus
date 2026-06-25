import AppKit
import WebKit

@MainActor
final class YouTubeLoginWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
    static let shared = YouTubeLoginWindowController()

    private var panel: NSPanel?
    private var webView: WKWebView?
    private var cookieObserverRegistered = false
    private var completion: ((Bool) -> Void)?

    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    private static let signInURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://www.youtube.com/")!

    private let panelSize = NSSize(width: 440, height: 580)

    private override init() {
        super.init()
    }

    /// Presents the login sheet. Returns true if the user signed in successfully.
    func present() async -> Bool {
        if await YouTubeSessionStore.isLoggedIn() {
            return true
        }

        return await withCheckedContinuation { continuation in
            completion = { signedIn in
                continuation.resume(returning: signedIn)
            }
            open()
        }
    }

    func close(signedIn: Bool) {
        guard completion != nil else { return }
        unregisterCookieObserver()
        panel?.orderOut(nil)
        completion?(signedIn)
        completion = nil
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    private func open() {
        if panel == nil {
            createPanel()
        }

        guard let panel, let webView else { return }

        registerCookieObserver()
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        webView.load(URLRequest(url: Self.signInURL))
        checkLoginState()
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Sign in to YouTube"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.minSize = panelSize
        panel.maxSize = NSSize(width: 520, height: 720)

        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        container.material = .sidebar
        container.state = .active
        container.blendingMode = .behindWindow
        container.autoresizingMask = [.width, .height]

        let header = NSTextField(labelWithString: "Sign in for your personalized Shorts feed.")
        header.font = NSFont.systemFont(ofSize: 13)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byWordWrapping
        header.maximumNumberOfLines = 2
        header.translatesAutoresizingMaskIntoConstraints = false

        let configuration = YouTubeSessionStore.makeWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = Self.desktopUserAgent
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        let skipButton = NSButton(title: "Continue without signing in", target: self, action: #selector(skipLogin))
        skipButton.bezelStyle = .rounded
        skipButton.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(header)
        container.addSubview(webView)
        container.addSubview(skipButton)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            webView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            webView.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -10),

            skipButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            skipButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            skipButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            skipButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        panel.contentView = container
        self.panel = panel
        self.webView = webView
    }

    @objc private func skipLogin() {
        close(signedIn: false)
    }

    private func registerCookieObserver() {
        guard !cookieObserverRegistered else { return }
        YouTubeSessionStore.dataStore.httpCookieStore.add(self)
        cookieObserverRegistered = true
    }

    private func unregisterCookieObserver() {
        guard cookieObserverRegistered else { return }
        YouTubeSessionStore.dataStore.httpCookieStore.remove(self)
        cookieObserverRegistered = false
    }

    private func checkLoginState() {
        Task { @MainActor in
            if await YouTubeSessionStore.isLoggedIn() {
                DebugLog.write("YouTube login detected via session cookies")
                close(signedIn: true)
            }
        }
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        checkLoginState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DebugLog.write("YouTubeLogin finished: \(webView.url?.absoluteString ?? "unknown")")
        checkLoginState()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let host = url.host?.lowercased() ?? ""
        let allowed = host.contains("google.com")
            || host.contains("youtube.com")
            || host.contains("gstatic.com")
            || host.contains("googleusercontent.com")
            || host.contains("ytimg.com")

        if !allowed, navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DebugLog.write("YouTubeLogin navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DebugLog.write("YouTubeLogin provisional navigation failed: \(error.localizedDescription)")
    }

    func windowWillClose(_ notification: Notification) {
        if completion != nil {
            close(signedIn: false)
        }
    }
}
