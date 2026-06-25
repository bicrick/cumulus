import AppKit

/// Chrome margins drawn outside the video content area (screen coordinates).
enum OverlayChromeLayout {
    static let topBarHeight: CGFloat = 8
    static let bottomBarHeight: CGFloat = 28
    static let rightExtension: CGFloat = 12
    static let videoCornerRadius: CGFloat = 10
    static let grabLineWidth: CGFloat = 48
    static let grabLineHeight: CGFloat = 3
    static let grabLineOffsetBelowVideo: CGFloat = 10
    static let dragHitWidth: CGFloat = 80
    static let dragHitHeight: CGFloat = 24
    static let resizeHitSize: CGFloat = 48
    static let cornerArcOutwardGap: CGFloat = 5

    /// Shared visual weight for grab line and corner arc.
    static var chromeStrokeWidth: CGFloat { grabLineHeight }

    static var totalVerticalChrome: CGFloat { topBarHeight + bottomBarHeight }

    static func windowFrame(forContentRect content: NSRect) -> NSRect {
        NSRect(
            x: content.origin.x,
            y: content.origin.y - bottomBarHeight,
            width: content.width + rightExtension,
            height: content.height + totalVerticalChrome
        )
    }

    static func contentFrame(from windowFrame: NSRect) -> NSRect {
        NSRect(
            x: windowFrame.origin.x,
            y: windowFrame.origin.y + bottomBarHeight,
            width: windowFrame.width - rightExtension,
            height: windowFrame.height - totalVerticalChrome
        )
    }

    /// Video rect inside a flipped content view when chrome is visible.
    static func videoRect(in bounds: NSRect) -> NSRect {
        NSRect(
            x: 0,
            y: topBarHeight,
            width: bounds.width - rightExtension,
            height: bounds.height - totalVerticalChrome
        )
    }

    /// Visual frame of the grab line below the video.
    static func grabLineRect(for videoRect: NSRect) -> NSRect {
        NSRect(
            x: videoRect.midX - grabLineWidth / 2,
            y: videoRect.maxY + grabLineOffsetBelowVideo,
            width: grabLineWidth,
            height: grabLineHeight
        )
    }
}

struct ChromeInteractionRegions {
    let dragRegion: NSRect
    let resizeRegion: NSRect

    static func make(videoRect: NSRect) -> ChromeInteractionRegions {
        let grabLine = OverlayChromeLayout.grabLineRect(for: videoRect)
        let dragRegion = NSRect(
            x: grabLine.midX - OverlayChromeLayout.dragHitWidth / 2,
            y: grabLine.midY - OverlayChromeLayout.dragHitHeight / 2,
            width: OverlayChromeLayout.dragHitWidth,
            height: OverlayChromeLayout.dragHitHeight
        )
        let resizeRegion = NSRect(
            x: videoRect.maxX - OverlayChromeLayout.resizeHitSize,
            y: videoRect.maxY - OverlayChromeLayout.resizeHitSize,
            width: OverlayChromeLayout.resizeHitSize + OverlayChromeLayout.rightExtension,
            height: OverlayChromeLayout.resizeHitSize
        )
        return ChromeInteractionRegions(dragRegion: dragRegion, resizeRegion: resizeRegion)
    }

    func region(at point: NSPoint) -> ChromeHitRegion? {
        if resizeRegion.contains(point) { return .resize }
        if dragRegion.contains(point) { return .drag }
        return nil
    }
}

enum ChromeHitRegion {
    case drag
    case resize
}
