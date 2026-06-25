import Foundation

enum PlaybackMode: String, Codable, CaseIterable {
    case embedded
    case shortsFeed

    var label: String {
        switch self {
        case .embedded: return "Embedded"
        case .shortsFeed: return "Shorts"
        }
    }
}
