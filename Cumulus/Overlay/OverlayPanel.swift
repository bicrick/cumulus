import AppKit

final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.85)
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum ScreenGeometry {
    static let videoAspectRatio: CGFloat = 16.0 / 9.0
    static let minVideoWidth: CGFloat = 320
    static var minVideoHeight: CGFloat { minVideoWidth / videoAspectRatio }

    static func sizeMatchingAspect(width: CGFloat) -> NSSize {
        let w = max(minVideoWidth, width)
        return NSSize(width: w, height: w / videoAspectRatio)
    }

    static func frameMatchingAspect(origin: NSPoint, width: CGFloat) -> NSRect {
        let size = sizeMatchingAspect(width: width)
        return NSRect(origin: origin, size: size)
    }

    static func normalizedFrame(_ frame: NSRect) -> NSRect {
        let size = sizeMatchingAspect(width: frame.width)
        return NSRect(x: frame.origin.x, y: frame.origin.y, width: size.width, height: size.height)
    }

    static func centeredFrame(size: NSSize) -> CGRect {
        guard let screen = NSScreen.main else {
            return CGRect(x: 200, y: 200, width: size.width, height: size.height)
        }
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func isOnScreen(_ frame: CGRect) -> Bool {
        guard frame.width > 0, frame.height > 0 else { return false }
        return NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
    }
}
