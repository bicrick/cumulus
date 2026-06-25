import Foundation
import WebKit

/// Shared YouTube web session backed by the default WKWebsiteDataStore.
enum YouTubeSessionStore {
    static let dataStore: WKWebsiteDataStore = .default()

    private static let authCookieNames: Set<String> = [
        "LOGIN_INFO",
        "SID",
        "__Secure-1PSID",
        "__Secure-3PSID",
        "__Secure-1PSIDTS",
        "__Secure-3PSIDTS"
    ]

    static func isLoggedIn() async -> Bool {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: hasAuthCookies(cookies))
            }
        }
    }

    static func hasAuthCookies(_ cookies: [HTTPCookie]) -> Bool {
        cookies.contains { cookie in
            guard authCookieNames.contains(cookie.name) else { return false }
            let domain = cookie.domain.lowercased()
            return domain.contains("youtube.com") || domain.contains("google.com")
        }
    }

    static func makeWebViewConfiguration(userScripts: [WKUserScript] = []) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        for script in userScripts {
            configuration.userContentController.addUserScript(script)
        }
        return configuration
    }
}
