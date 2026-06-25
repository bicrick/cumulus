import AppKit

/// External chrome border drawn outside the video embed when Shift is held.
enum OverlayChromeLayout {
    static let topBarHeight: CGFloat = 30
    static let bottomBarHeight: CGFloat = 24
    static let sideInset: CGFloat = 12
    static let cornerHandleSize: CGFloat = 24

    static var totalVerticalChrome: CGFloat { topBarHeight + bottomBarHeight }
    static var totalHorizontalChrome: CGFloat { sideInset * 2 }

    /// Wrap a content (video) rect with external chrome in screen coordinates.
    static func windowFrame(forContentRect content: NSRect) -> NSRect {
        NSRect(
            x: content.origin.x - sideInset,
            y: content.origin.y - bottomBarHeight,
            width: content.width + totalHorizontalChrome,
            height: content.height + totalVerticalChrome
        )
    }

    /// Extract the video content rect from a window frame that includes chrome.
    static func contentFrame(from windowFrame: NSRect) -> NSRect {
        NSRect(
            x: windowFrame.origin.x + sideInset,
            y: windowFrame.origin.y + bottomBarHeight,
            width: windowFrame.width - totalHorizontalChrome,
            height: windowFrame.height - totalVerticalChrome
        )
    }
}
