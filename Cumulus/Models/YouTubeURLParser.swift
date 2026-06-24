import Foundation

enum YouTubeURLParser {
    static func videoID(from urlString: String) -> String? {
        if let extracted = extractYouTubeURL(from: urlString) {
            return videoID(fromNormalizedURL: extracted)
        }
        return videoID(fromNormalizedURL: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func extractYouTubeURL(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let patterns = [
            #"https?://(?:www\.)?youtube\.com/watch\?[^\s\)"']+"#,
            #"https?://(?:www\.)?youtu\.be/[^\s\)"']+"#,
            #"https?://(?:www\.)?youtube\.com/shorts/[^\s\)"']+"#,
            #"https?://(?:www\.)?youtube\.com/embed/[^\s\)"']+"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let range = Range(match.range, in: trimmed) {
                return String(trimmed[range])
            }
        }

        return trimmed.hasPrefix("http") ? trimmed : nil
    }

    private static func videoID(fromNormalizedURL urlString: String) -> String? {
        guard !urlString.isEmpty else { return nil }

        if let url = URL(string: urlString), let host = url.host?.lowercased() {
            if host.contains("youtu.be") {
                let id = url.pathComponents.dropFirst().first
                return sanitized(id)
            }

            if host.contains("youtube.com") {
                if url.pathComponents.contains("embed"), let id = url.pathComponents.last {
                    return sanitized(id)
                }

                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let id = components.queryItems?.first(where: { $0.name == "v" })?.value {
                    return sanitized(id)
                }

                if url.pathComponents.contains("shorts"), let id = url.pathComponents.last {
                    return sanitized(id)
                }
            }
        }

        if urlString.count == 11,
           urlString.range(of: #"^[a-zA-Z0-9_-]+$"#, options: .regularExpression) != nil {
            return urlString
        }

        return nil
    }

    static func embedURL(videoID: String, autoplayMuted: Bool) -> URL? {
        var components = URLComponents(string: "https://www.youtube-nocookie.com/embed/\(videoID)")
        components?.queryItems = [
            URLQueryItem(name: "autoplay", value: "1"),
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "controls", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "mute", value: autoplayMuted ? "1" : "0"),
            URLQueryItem(name: "origin", value: "https://cumulus.local")
        ]
        return components?.url
    }

    private static func sanitized(_ id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        return id
    }
}
