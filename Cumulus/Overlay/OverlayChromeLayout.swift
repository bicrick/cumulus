import AppKit

enum VideoCorner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum DragEdge {
    case top
    case bottom
    case left
    case right
}

struct ChromePlacement: Equatable {
    let resizeCorner: VideoCorner
    let dragEdge: DragEdge

    static let `default` = ChromePlacement(resizeCorner: .bottomRight, dragEdge: .bottom)

    static func forSnapAnchor(_ anchor: SnapAnchor) -> ChromePlacement {
        switch anchor {
        case .bottomLeft:
            return ChromePlacement(resizeCorner: .topRight, dragEdge: .top)
        case .bottomRight, .bottomCenter:
            return ChromePlacement(resizeCorner: .topLeft, dragEdge: .top)
        case .topRight:
            return ChromePlacement(resizeCorner: .bottomLeft, dragEdge: .bottom)
        case .topLeft:
            return ChromePlacement(resizeCorner: .bottomRight, dragEdge: .bottom)
        case .topCenter:
            return ChromePlacement(resizeCorner: .bottomLeft, dragEdge: .bottom)
        case .centerLeft:
            return ChromePlacement(resizeCorner: .topRight, dragEdge: .right)
        case .centerRight:
            return ChromePlacement(resizeCorner: .topLeft, dragEdge: .left)
        case .center:
            return ChromePlacement(resizeCorner: .bottomRight, dragEdge: .bottom)
        }
    }
}

struct ChromeInsets: Equatable {
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat

    static let zero = ChromeInsets(top: 0, bottom: 0, left: 0, right: 0)

    var totalHorizontal: CGFloat { left + right }
    var totalVertical: CGFloat { top + bottom }
}

/// Chrome margins drawn outside the video content area (screen coordinates).
enum OverlayChromeLayout {
    static let minBreathingRoom: CGFloat = 8
    static let edgeExtension: CGFloat = 28
    static let cornerExtension: CGFloat = 12
    static let videoCornerRadius: CGFloat = 10
    static let grabLineWidth: CGFloat = 48
    static let grabLineHeight: CGFloat = 3
    static let grabLineOffsetFromVideo: CGFloat = 10
    static let resizeHitSize: CGFloat = 48
    static let cornerArcOutwardGap: CGFloat = 5

    static var chromeStrokeWidth: CGFloat { grabLineHeight }

    static func insets(for placement: ChromePlacement) -> ChromeInsets {
        var top = minBreathingRoom
        var bottom = minBreathingRoom
        var left = minBreathingRoom
        var right = minBreathingRoom

        switch placement.dragEdge {
        case .top: top = edgeExtension
        case .bottom: bottom = edgeExtension
        case .left: left = edgeExtension
        case .right: right = edgeExtension
        }

        switch placement.resizeCorner {
        case .topLeft:
            top = max(top, cornerExtension)
            left = max(left, cornerExtension)
        case .topRight:
            top = max(top, cornerExtension)
            right = max(right, cornerExtension)
        case .bottomLeft:
            bottom = max(bottom, cornerExtension)
            left = max(left, cornerExtension)
        case .bottomRight:
            bottom = max(bottom, cornerExtension)
            right = max(right, cornerExtension)
        }

        return ChromeInsets(top: top, bottom: bottom, left: left, right: right)
    }

    static func windowFrame(forContentRect content: NSRect, insets: ChromeInsets) -> NSRect {
        NSRect(
            x: content.origin.x - insets.left,
            y: content.origin.y - insets.bottom,
            width: content.width + insets.totalHorizontal,
            height: content.height + insets.totalVertical
        )
    }

    static func contentFrame(from windowFrame: NSRect, insets: ChromeInsets) -> NSRect {
        NSRect(
            x: windowFrame.origin.x + insets.left,
            y: windowFrame.origin.y + insets.bottom,
            width: windowFrame.width - insets.totalHorizontal,
            height: windowFrame.height - insets.totalVertical
        )
    }

    static func videoRect(in bounds: NSRect, insets: ChromeInsets) -> NSRect {
        NSRect(
            x: insets.left,
            y: insets.top,
            width: bounds.width - insets.totalHorizontal,
            height: bounds.height - insets.totalVertical
        )
    }

    static func grabLineRect(for videoRect: NSRect, dragEdge: DragEdge) -> NSRect {
        switch dragEdge {
        case .top:
            return NSRect(
                x: videoRect.midX - grabLineWidth / 2,
                y: videoRect.minY - grabLineOffsetFromVideo - grabLineHeight,
                width: grabLineWidth,
                height: grabLineHeight
            )
        case .bottom:
            return NSRect(
                x: videoRect.midX - grabLineWidth / 2,
                y: videoRect.maxY + grabLineOffsetFromVideo,
                width: grabLineWidth,
                height: grabLineHeight
            )
        case .left:
            return NSRect(
                x: videoRect.minX - grabLineOffsetFromVideo - grabLineHeight,
                y: videoRect.midY - grabLineWidth / 2,
                width: grabLineHeight,
                height: grabLineWidth
            )
        case .right:
            return NSRect(
                x: videoRect.maxX + grabLineOffsetFromVideo,
                y: videoRect.midY - grabLineWidth / 2,
                width: grabLineHeight,
                height: grabLineWidth
            )
        }
    }

    static func resizeHitZone(for videoRect: NSRect, corner: VideoCorner, insets: ChromeInsets) -> NSRect {
        let base: NSRect
        switch corner {
        case .topLeft:
            base = NSRect(x: videoRect.minX, y: videoRect.minY, width: resizeHitSize, height: resizeHitSize)
        case .topRight:
            base = NSRect(x: videoRect.maxX - resizeHitSize, y: videoRect.minY, width: resizeHitSize, height: resizeHitSize)
        case .bottomLeft:
            base = NSRect(x: videoRect.minX, y: videoRect.maxY - resizeHitSize, width: resizeHitSize, height: resizeHitSize)
        case .bottomRight:
            base = NSRect(x: videoRect.maxX - resizeHitSize, y: videoRect.maxY - resizeHitSize, width: resizeHitSize, height: resizeHitSize)
        }

        var zone = base
        switch corner {
        case .topLeft:
            zone.origin.x -= max(0, insets.left - minBreathingRoom)
            zone.origin.y -= max(0, insets.top - minBreathingRoom)
            zone.size.width += max(0, insets.left - minBreathingRoom)
            zone.size.height += max(0, insets.top - minBreathingRoom)
        case .topRight:
            zone.origin.y -= max(0, insets.top - minBreathingRoom)
            zone.size.width += max(0, insets.right - minBreathingRoom)
            zone.size.height += max(0, insets.top - minBreathingRoom)
        case .bottomLeft:
            zone.origin.x -= max(0, insets.left - minBreathingRoom)
            zone.size.height += max(0, insets.bottom - minBreathingRoom)
            zone.size.width += max(0, insets.left - minBreathingRoom)
        case .bottomRight:
            zone.size.width += max(0, insets.right - minBreathingRoom)
            zone.size.height += max(0, insets.bottom - minBreathingRoom)
        }
        return zone
    }
}

struct ChromeInteractionRegions {
    let dragRegion: NSRect
    let resizeRegion: NSRect

    static func make(videoRect: NSRect, bounds: NSRect, placement: ChromePlacement, insets: ChromeInsets) -> ChromeInteractionRegions {
        let resizeRegion = OverlayChromeLayout.resizeHitZone(for: videoRect, corner: placement.resizeCorner, insets: insets)
        var dragRegion = bounds
        dragRegion = dragRegion.insetBy(dx: 0, dy: 0)
        // Drag = entire bounds minus video and minus resize corner (resize takes priority)
        return ChromeInteractionRegions(dragRegion: dragRegion, resizeRegion: resizeRegion)
    }

    func region(at point: NSPoint, videoRect: NSRect, bounds: NSRect) -> ChromeHitRegion? {
        guard bounds.contains(point) else { return nil }
        if videoRect.contains(point) { return nil }
        if resizeRegion.contains(point) { return .resize }
        return .drag
    }
}

enum ChromeHitRegion {
    case drag
    case resize
}

enum ChromeResizeCursor {
    static func forCorner(_ corner: VideoCorner) -> NSCursor {
        switch corner {
        case .topLeft, .bottomRight:
            return northWestSouthEast
        case .topRight, .bottomLeft:
            return northEastSouthWest
        }
    }

    /// AppKit's internal window-resize cursors (same arrows with white outline as native windows).
    private static let northWestSouthEast: NSCursor =
        systemWindowResizeCursor(named: "_windowResizeNorthWestSouthEastCursor") ?? .crosshair
    private static let northEastSouthWest: NSCursor =
        systemWindowResizeCursor(named: "_windowResizeNorthEastSouthWestCursor") ?? .crosshair

    private static func systemWindowResizeCursor(named selectorName: String) -> NSCursor? {
        let sel = NSSelectorFromString(selectorName)
        guard NSCursor.responds(to: sel) else { return nil }
        return NSCursor.perform(sel)?.takeUnretainedValue() as? NSCursor
    }
}
