import AppKit
import Foundation

enum InteractionMode: Equatable {
    case passive
    case hover
    case interactive
}

enum InteractiveModifier: String, CaseIterable, Identifiable {
    case shift
    case option
    case control
    case command

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shift: return "Shift"
        case .option: return "Option"
        case .control: return "Control"
        case .command: return "Command"
        }
    }

    var nsEventFlags: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .option: return .option
        case .control: return .control
        case .command: return .command
        }
    }
}

extension NSEvent.ModifierFlags {
    func contains(_ modifier: InteractiveModifier) -> Bool {
        contains(modifier.nsEventFlags)
    }
}

struct OverlayFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let `default` = OverlayFrame(x: 100, y: 100, width: 480, height: 270)

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(from rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }
}

@MainActor
final class OverlaySettings: ObservableObject {
    private enum Keys {
        static let restingOpacity = "restingOpacity"
        static let hoverOpacity = "hoverOpacity"
        static let interactiveOpacity = "interactiveOpacity"
        static let interactiveModifier = "interactiveModifier"
        static let transitionMs = "transitionMs"
        static let clickThroughWhenPassive = "clickThroughWhenPassive"
        static let autoplayMuted = "autoplayMuted"
        static let lastVideoURL = "lastVideoURL"
        static let overlayFrame = "overlayFrame"
        static let shortsOverlayFrame = "shortsOverlayFrame"
        static let lastPlaybackMode = "lastPlaybackMode"
        static let snapEnabled = "snapEnabled"
        static let enabledSnapAnchors = "enabledSnapAnchors"
        static let snapEdgeMargin = "snapEdgeMargin"
        static let snapThreshold = "snapThreshold"
        static let snapAnimationMs = "snapAnimationMs"
    }

    @Published var restingOpacity: Double {
        didSet { save(restingOpacity, forKey: Keys.restingOpacity) }
    }

    @Published var hoverOpacity: Double {
        didSet { save(hoverOpacity, forKey: Keys.hoverOpacity) }
    }

    @Published var interactiveOpacity: Double {
        didSet { save(interactiveOpacity, forKey: Keys.interactiveOpacity) }
    }

    @Published var interactiveModifier: InteractiveModifier {
        didSet { defaults.set(interactiveModifier.rawValue, forKey: Keys.interactiveModifier) }
    }

    @Published var transitionMs: Double {
        didSet { save(transitionMs, forKey: Keys.transitionMs) }
    }

    @Published var clickThroughWhenPassive: Bool {
        didSet { defaults.set(clickThroughWhenPassive, forKey: Keys.clickThroughWhenPassive) }
    }

    @Published var autoplayMuted: Bool {
        didSet { defaults.set(autoplayMuted, forKey: Keys.autoplayMuted) }
    }

    @Published var lastVideoURL: String {
        didSet { defaults.set(lastVideoURL, forKey: Keys.lastVideoURL) }
    }

    @Published var overlayFrame: OverlayFrame {
        didSet { saveFrame(overlayFrame, forKey: Keys.overlayFrame) }
    }

    @Published var shortsOverlayFrame: OverlayFrame {
        didSet { saveFrame(shortsOverlayFrame, forKey: Keys.shortsOverlayFrame) }
    }

    @Published var lastPlaybackMode: PlaybackMode {
        didSet { defaults.set(lastPlaybackMode.rawValue, forKey: Keys.lastPlaybackMode) }
    }

    @Published var snapEnabled: Bool {
        didSet { defaults.set(snapEnabled, forKey: Keys.snapEnabled) }
    }

    @Published var enabledSnapAnchors: Set<SnapAnchor> {
        didSet { saveSnapAnchors() }
    }

    @Published var snapEdgeMargin: Double {
        didSet { save(snapEdgeMargin, forKey: Keys.snapEdgeMargin) }
    }

    @Published var snapThreshold: Double {
        didSet { save(snapThreshold, forKey: Keys.snapThreshold) }
    }

    @Published var snapAnimationMs: Double {
        didSet { save(snapAnimationMs, forKey: Keys.snapAnimationMs) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restingOpacity = defaults.object(forKey: Keys.restingOpacity) as? Double ?? 1.0
        hoverOpacity = defaults.object(forKey: Keys.hoverOpacity) as? Double ?? 0.2
        interactiveOpacity = defaults.object(forKey: Keys.interactiveOpacity) as? Double ?? 1.0
        let modifierRaw = defaults.string(forKey: Keys.interactiveModifier) ?? InteractiveModifier.shift.rawValue
        interactiveModifier = InteractiveModifier(rawValue: modifierRaw) ?? .shift
        transitionMs = defaults.object(forKey: Keys.transitionMs) as? Double ?? 150
        clickThroughWhenPassive = defaults.object(forKey: Keys.clickThroughWhenPassive) as? Bool ?? true
        autoplayMuted = defaults.object(forKey: Keys.autoplayMuted) as? Bool ?? false
        lastVideoURL = defaults.string(forKey: Keys.lastVideoURL) ?? ""
        if let data = defaults.data(forKey: Keys.overlayFrame),
           let frame = try? JSONDecoder().decode(OverlayFrame.self, from: data) {
            overlayFrame = frame
        } else {
            overlayFrame = .default
        }
        if let data = defaults.data(forKey: Keys.shortsOverlayFrame),
           let frame = try? JSONDecoder().decode(OverlayFrame.self, from: data) {
            shortsOverlayFrame = frame
        } else {
            let size = ScreenGeometry.shortsSizeMatchingAspect(width: 320)
            shortsOverlayFrame = OverlayFrame(from: ScreenGeometry.centeredFrame(size: size))
        }
        let modeRaw = defaults.string(forKey: Keys.lastPlaybackMode) ?? PlaybackMode.embedded.rawValue
        lastPlaybackMode = PlaybackMode(rawValue: modeRaw) ?? .embedded
        snapEnabled = defaults.object(forKey: Keys.snapEnabled) as? Bool ?? true
        if let rawAnchors = defaults.stringArray(forKey: Keys.enabledSnapAnchors) {
            enabledSnapAnchors = Set(rawAnchors.compactMap(SnapAnchor.init(rawValue:)))
        } else {
            enabledSnapAnchors = SnapAnchor.defaultCorners
        }
        snapEdgeMargin = defaults.object(forKey: Keys.snapEdgeMargin) as? Double ?? 16
        snapThreshold = defaults.object(forKey: Keys.snapThreshold) as? Double ?? 80
        snapAnimationMs = defaults.object(forKey: Keys.snapAnimationMs) as? Double ?? 180
    }

    func opacity(for mode: InteractionMode) -> Double {
        switch mode {
        case .passive: return restingOpacity
        case .hover: return hoverOpacity
        case .interactive: return interactiveOpacity
        }
    }

    private func save(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func saveFrame(_ frame: OverlayFrame, forKey key: String) {
        if let data = try? JSONEncoder().encode(frame) {
            defaults.set(data, forKey: key)
        }
    }

    private func saveSnapAnchors() {
        defaults.set(enabledSnapAnchors.map(\.rawValue), forKey: Keys.enabledSnapAnchors)
    }
}
