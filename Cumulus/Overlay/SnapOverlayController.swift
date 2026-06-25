import AppKit

@MainActor
final class SnapOverlayController {
    private var panel: NSPanel?
    private var drawView: SnapOverlayDrawView?

    func show(on screen: NSScreen?, candidates: [SnapAnchor: NSRect], highlighted: SnapAnchor?) {
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen else { return }

        if panel == nil {
            let frame = targetScreen.frame
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let drawView = SnapOverlayDrawView(frame: frame)
            panel.contentView = drawView
            self.panel = panel
            self.drawView = drawView
        }

        let frame = targetScreen.frame
        panel?.setFrame(frame, display: true)
        drawView?.frame = frame

        drawView?.update(candidates: candidates, highlighted: highlighted)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        drawView?.update(candidates: [:], highlighted: nil)
    }
}

private final class SnapOverlayDrawView: NSView {
    private var candidates: [SnapAnchor: NSRect] = [:]
    private var highlighted: SnapAnchor?

    override var isFlipped: Bool { false }

    func update(candidates: [SnapAnchor: NSRect], highlighted: SnapAnchor?) {
        self.candidates = candidates
        self.highlighted = highlighted
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        for (anchor, frame) in candidates {
            let isHighlighted = anchor == highlighted
            let color = NSColor.white.withAlphaComponent(isHighlighted ? 0.85 : 0.4)
            color.setStroke()

            let path = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
            path.lineWidth = isHighlighted ? 2.5 : 1.5
            let dash: [CGFloat] = isHighlighted ? [] : [6, 4]
            path.setLineDash(dash, count: dash.count, phase: 0)
            path.stroke()
        }
    }
}
