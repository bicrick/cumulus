import AppKit

/// Rounded clip + shadow wrapper for the YouTube web view.
final class VideoContainerView: NSView {
    let clipView = NSView()

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.cornerRadius = OverlayChromeLayout.videoCornerRadius
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 10
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        layer?.masksToBounds = false

        clipView.wantsLayer = true
        clipView.layer?.cornerRadius = OverlayChromeLayout.videoCornerRadius
        clipView.layer?.masksToBounds = true
        clipView.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(clipView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        clipView.frame = bounds
    }
}

/// Pure AppKit container for the overlay window.
final class OverlayContentView: NSView {
    let videoContainer = VideoContainerView()
    let chromeLayer: OverlayChromeLayer

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    init(controller: OverlayController) {
        chromeLayer = OverlayChromeLayer(controller: controller)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false

        addSubview(videoContainer)
        addSubview(chromeLayer)
        chromeLayer.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        chromeLayer.frame = bounds
    }

    func syncLayout(interactive: Bool, videoRect: NSRect, placement: ChromePlacement, insets: ChromeInsets) {
        videoContainer.frame = videoRect
        chromeLayer.layoutChrome(videoRect: videoRect, in: bounds, placement: placement, insets: insets)
    }
}
