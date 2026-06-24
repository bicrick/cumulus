import AppKit
import SwiftUI
import WebKit

struct YouTubeWebView: NSViewRepresentable {
    let videoID: String?
    let autoplayMuted: Bool
    let generation: Int
    @Binding var loadError: String?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let loadKey = "\(videoID ?? "")-\(autoplayMuted)-\(generation)"
        guard context.coordinator.lastLoadKey != loadKey else { return }

        guard let videoID, !videoID.isEmpty else {
            loadError = "Invalid YouTube URL"
            return
        }

        context.coordinator.lastLoadKey = loadKey
        loadError = nil

        Task { @MainActor in
            await context.coordinator.load(videoID: videoID, autoplayMuted: autoplayMuted, in: webView, loadError: $loadError)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(loadError: $loadError)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var loadError: String?
        var lastLoadKey: String?

        init(loadError: Binding<String?>) {
            _loadError = loadError
        }

        func load(videoID: String, autoplayMuted: Bool, in webView: WKWebView, loadError: Binding<String?>) async {
            do {
                try await LoopbackWebServer.shared.start()
                guard let url = LoopbackWebServer.shared.playerURL(videoID: videoID, autoplayMuted: autoplayMuted) else {
                    loadError.wrappedValue = "Could not start local player server."
                    return
                }

                DebugLog.write("Loading player URL: \(url.absoluteString)")
                webView.load(URLRequest(url: url))
            } catch {
                let message = "Player server failed: \(error.localizedDescription)"
                loadError.wrappedValue = message
                DebugLog.write(message)
                await loadFallbackProxy(videoID: videoID, autoplayMuted: autoplayMuted, in: webView)
            }
        }

        private func loadFallbackProxy(videoID: String, autoplayMuted: Bool, in webView: WKWebView) async {
            let embed = "https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&playsinline=1&controls=1&mute=\(autoplayMuted ? "1" : "0")"
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
            loadError = message
            DebugLog.write("WebView navigation failed: \(message)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let message = error.localizedDescription
            loadError = message
            DebugLog.write("WebView provisional navigation failed: \(message)")
        }
    }
}
