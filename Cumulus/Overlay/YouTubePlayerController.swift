import AppKit
import WebKit

@MainActor
final class YouTubePlayerController: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private var lastLoadKey: String?
    private var lastLoadGeneration = -1
    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 0.5

    var onLoadError: ((String?) -> Void)?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        webView.layer?.isOpaque = false
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func attach(to container: VideoContainerView) {
        webView.frame = container.clipView.bounds
        webView.autoresizingMask = [.width, .height]
        container.clipView.addSubview(webView)
    }

    func setFrame(_ rect: NSRect) {
        // Frame is applied to videoContainer by OverlayContentView layout.
    }

    func layoutInContainer(_ container: VideoContainerView) {
        webView.frame = container.clipView.bounds
    }

    var playerFrame: NSRect {
        webView.frame
    }

    func load(videoID: String, autoplayMuted: Bool, generation: Int) {
        let loadKey = "\(videoID)-\(autoplayMuted)-\(generation)"

        if lastLoadKey == loadKey {
            return
        }

        if generation == lastLoadGeneration,
           let lastLoadTime,
           Date().timeIntervalSince(lastLoadTime) < minimumLoadInterval {
            DebugLog.write("YouTubePlayer load suppressed (debounced, generation=\(generation))")
            return
        }

        lastLoadKey = loadKey
        lastLoadGeneration = generation
        lastLoadTime = Date()
        onLoadError?(nil)
        DebugLog.write("YouTubePlayer loading (generation=\(generation))")

        Task { @MainActor in
            await loadPlayer(videoID: videoID, autoplayMuted: autoplayMuted)
        }
    }

    func notifyResized(width: Int, height: Int) {
        let script = "window.cumulusSetSize && window.cumulusSetSize(\(width), \(height));"
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                DebugLog.write("cumulusSetSize failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadPlayer(videoID: String, autoplayMuted: Bool) async {
        do {
            try await LoopbackWebServer.shared.start()
            guard let url = LoopbackWebServer.shared.playerURL(videoID: videoID, autoplayMuted: autoplayMuted) else {
                onLoadError?("Could not start local player server.")
                return
            }

            DebugLog.write("Loading player URL: \(url.absoluteString)")
            webView.load(URLRequest(url: url))
        } catch {
            let message = "Player server failed: \(error.localizedDescription)"
            onLoadError?(message)
            DebugLog.write(message)
            await loadFallbackProxy(videoID: videoID, autoplayMuted: autoplayMuted)
        }
    }

    private func loadFallbackProxy(videoID: String, autoplayMuted: Bool) async {
        let embed = "https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&playsinline=1&controls=1&enablejsapi=1&mute=\(autoplayMuted ? "1" : "0")"
        guard let encoded = embed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let proxy = "https://corsproxy.io/?url=\(encoded)"
        let html = """
        <!DOCTYPE html><html><head><meta name="referrer" content="strict-origin-when-cross-origin"></head>
        <body style="margin:0;background:#000">
        <iframe width="100%" height="100%" style="position:fixed;inset:0;border:0"
          src="\(proxy)" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen
          allow="autoplay; encrypted-media; picture-in-picture"></iframe>
        </body></html>
        """
        DebugLog.write("Loading corsproxy fallback for \(videoID)")
        webView.loadHTMLString(html, baseURL: URL(string: "https://cumulus.local/")!)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DebugLog.write("WebView finished: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        let host = url.host?.lowercased() ?? ""
        let allowed = host.hasPrefix("127.0.0.1")
            || host == "localhost"
            || host.contains("youtube.com")
            || host.contains("youtube-nocookie.com")
            || host.contains("google.com")
            || host.contains("googlevideo.com")
            || host.contains("gstatic.com")
            || host.contains("ytimg.com")
            || host.contains("corsproxy.io")

        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let message = error.localizedDescription
        onLoadError?(message)
        DebugLog.write("WebView navigation failed: \(message)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let message = error.localizedDescription
        onLoadError?(message)
        DebugLog.write("WebView provisional navigation failed: \(message)")
    }
}
