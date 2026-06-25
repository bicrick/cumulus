import AppKit
import WebKit

@MainActor
final class ShortsFeedController: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView

    var onLoadError: ((String?) -> Void)?

    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// Minimal chrome hiding for desktop /shorts — no MutationObserver (that breaks YouTube hydration).
    private static let chromeHideCSS = """
    html,body{margin:0!important;padding:0!important;overflow:hidden!important;background:#000!important;height:100%!important;}
    ytd-masthead,#masthead-container,#guide-wrapper,#guide,ytd-mini-guide-renderer,
    #header,.ytd-masthead,tp-yt-app-header{display:none!important;}
    ytd-app,ytd-shorts,#content,.ytd-shorts{height:100%!important;max-height:100%!important;}
    """

    private static func makeChromeHidingScript() -> WKUserScript {
        let escaped = chromeHideCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let source = """
        (function() {
          var s = document.getElementById('cumulus-shorts-chrome-hide');
          if (!s) {
            s = document.createElement('style');
            s.id = 'cumulus-shorts-chrome-hide';
            (document.head || document.documentElement).appendChild(s);
          }
          s.textContent = '\(escaped)';
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }

    override init() {
        let configuration = YouTubeSessionStore.makeWebViewConfiguration(
            userScripts: [Self.makeChromeHidingScript()]
        )

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.customUserAgent = Self.desktopUserAgent
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
    }

    func attach(to container: VideoContainerView) {
        container.setClipMode(.nativeVideo)
        webView.frame = container.clipView.bounds
        webView.autoresizingMask = [.width, .height]
        webView.wantsLayer = false
        if webView.superview !== container.clipView {
            container.clipView.addSubview(webView)
        }
    }

    func detach() {
        webView.removeFromSuperview()
    }

    func layoutInContainer(_ container: VideoContainerView) {
        webView.frame = container.clipView.bounds
    }

    func loadFeed() {
        onLoadError?(nil)
        guard let url = URL(string: "https://www.youtube.com/shorts") else { return }
        DebugLog.write("ShortsFeed loading \(url.absoluteString) (webview frame: \(webView.frame.size))")
        webView.load(URLRequest(url: url))
    }

    func reloadFeed() {
        loadFeed()
    }

    private func reinjectChromeHideCSS() {
        webView.evaluateJavaScript(
            "(function(){ var s=document.getElementById('cumulus-shorts-chrome-hide'); if(!s){s=document.createElement('style');s.id='cumulus-shorts-chrome-hide';document.head.appendChild(s);} s.textContent=\(Self.chromeHideCSS.jsStringLiteral); })();",
            completionHandler: nil
        )
    }

    private func isAllowedHost(_ host: String) -> Bool {
        guard !host.isEmpty else { return true }
        return host.contains("youtube.com")
            || host.contains("google.com")
            || host.contains("googlevideo.com")
            || host.contains("gstatic.com")
            || host.contains("ytimg.com")
            || host.contains("ggpht.com")
            || host.contains("googleapis.com")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DebugLog.write("ShortsFeed started: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        DebugLog.write("ShortsFeed committed: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DebugLog.write("ShortsFeed finished: \(webView.url?.absoluteString ?? "unknown")")
        reinjectChromeHideCSS()
        kickstartPlayback()
        schedulePlaybackRetries()
    }

    func nudgePlayback() {
        kickstartPlayback()
    }

    private func kickstartPlayback() {
        let script = """
        (function() {
          document.querySelectorAll('video').forEach(function(v) {
            v.playsInline = true;
            if (v.paused) {
              var attempt = v.play();
              if (attempt && attempt.catch) {
                attempt.catch(function() {
                  v.muted = true;
                  v.play().catch(function(){});
                });
              }
            }
          });
        })();
        """
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                DebugLog.write("ShortsFeed kickstart failed: \(error.localizedDescription)")
            }
        }
    }

    private func schedulePlaybackRetries() {
        Task { @MainActor in
            for delayMs in [400, 1200, 2500] {
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                guard webView.url?.absoluteString.contains("youtube.com") == true else { return }
                kickstartPlayback()
            }
        }
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

        if navigationAction.navigationType == .linkActivated {
            let host = url.host?.lowercased() ?? ""
            if host.contains("youtube.com"), url.path.contains("/shorts") || url.path == "/shorts" {
                decisionHandler(.allow)
                return
            }
            DebugLog.write("ShortsFeed opening external link: \(url.absoluteString)")
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        let host = url.host?.lowercased() ?? ""
        let allowed = isAllowedHost(host)
        if !allowed {
            DebugLog.write("ShortsFeed blocked navigation: \(url.absoluteString)")
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
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        let message = error.localizedDescription
        onLoadError?(message)
        DebugLog.write("ShortsFeed navigation failed: \(message)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        let message = error.localizedDescription
        onLoadError?(message)
        DebugLog.write("ShortsFeed provisional navigation failed: \(message)")
    }
}

private extension String {
    var jsStringLiteral: String {
        let escaped = replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
        return "'\(escaped)'"
    }
}
