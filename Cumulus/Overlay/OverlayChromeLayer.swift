import AppKit

/// Unified chrome layer: draws grab line + corner arc, routes mouse to drag/resize regions.
final class OverlayChromeLayer: NSView {
    private weak var controller: OverlayController?
    private var videoRect = NSRect.zero
    private var regions = ChromeInteractionRegions.make(videoRect: .zero)

    private var activeInteraction: ActiveInteraction = .none
    private var startMouse = NSPoint.zero
    private var startContentFrame = NSRect.zero

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    init(controller: OverlayController) {
        self.controller = controller
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layoutChrome(videoRect: NSRect, in bounds: NSRect) {
        self.videoRect = videoRect
        self.regions = ChromeInteractionRegions.make(videoRect: videoRect)
        frame = bounds
        needsDisplay = true
        updateTrackingAreas()
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        drawGrabLine()
        drawCornerArc()
    }

    private func drawGrabLine() {
        let lineRect = OverlayChromeLayout.grabLineRect(for: videoRect)
        NSColor.white.withAlphaComponent(0.92).setFill()
        let radius = lineRect.height / 2
        NSBezierPath(roundedRect: lineRect, xRadius: radius, yRadius: radius).fill()
    }

    private func drawCornerArc() {
        let stroke = NSColor.white.withAlphaComponent(0.92)
        stroke.setStroke()

        let lineWidth = OverlayChromeLayout.chromeStrokeWidth
        let outwardGap = OverlayChromeLayout.cornerArcOutwardGap

        let cornerCenter = NSPoint(
            x: videoRect.maxX - OverlayChromeLayout.videoCornerRadius,
            y: videoRect.maxY - OverlayChromeLayout.videoCornerRadius
        )
        let arcRadius = OverlayChromeLayout.videoCornerRadius + outwardGap + lineWidth / 2

        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.appendArc(withCenter: cornerCenter, radius: arcRadius, startAngle: 0, endAngle: 90, clockwise: false)
        path.stroke()
    }

    // MARK: - Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, bounds.contains(point) else { return nil }
        if regions.region(at: point) != nil {
            return self
        }
        return nil
    }

    // MARK: - Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }

        for rect in [regions.dragRegion, regions.resizeRegion] {
            let area = NSTrackingArea(
                rect: rect,
                options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard activeInteraction == .none else { return }
        addCursorRect(regions.dragRegion, cursor: .openHand)
        addCursorRect(regions.resizeRegion, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        applyCursor(for: point)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        applyCursor(for: point)
    }

    private func applyCursor(for point: NSPoint) {
        switch activeInteraction {
        case .dragging:
            NSCursor.closedHand.set()
        case .resizing:
            NSCursor.crosshair.set()
        case .none:
            switch regions.region(at: point) {
            case .drag:
                NSCursor.openHand.set()
            case .resize:
                NSCursor.crosshair.set()
            case nil:
                NSCursor.arrow.set()
            }
        }
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let region = regions.region(at: point),
              let panelFrame = controller?.panelFrame else { return }

        startMouse = NSEvent.mouseLocation
        startContentFrame = controller?.contentFrame(from: panelFrame) ?? panelFrame

        switch region {
        case .drag:
            activeInteraction = .dragging
            controller?.beginDrag()
            NSCursor.closedHand.set()
        case .resize:
            activeInteraction = .resizing
            controller?.beginWindowManipulation()
            NSCursor.crosshair.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let controller else { return }

        let dx = NSEvent.mouseLocation.x - startMouse.x
        let dy = NSEvent.mouseLocation.y - startMouse.y

        switch activeInteraction {
        case .dragging:
            var newContent = startContentFrame.offsetBy(dx: dx, dy: dy)
            newContent = controller.clampContentFrame(newContent)
            controller.applyContentFrameDirectly(newContent, persist: false)
            controller.updateSnapPreview(for: newContent)
            NSCursor.closedHand.set()
        case .resizing:
            let newContent = resizedContentFrame(from: startContentFrame, dx: dx, dy: dy)
            let clamped = controller.clampContentFrame(newContent)
            controller.applyContentFrameDirectly(clamped, persist: false)
            NSCursor.crosshair.set()
        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch activeInteraction {
        case .dragging:
            controller?.finishDrag()
        case .resizing:
            controller?.endWindowManipulation()
            controller?.persistFrame()
            controller?.notifyPlayerResized()
        case .none:
            break
        }

        activeInteraction = .none
        window?.invalidateCursorRects(for: self)
        applyCursor(for: point)
    }

    /// Top-left anchor fixed; drag bottom-right to resize while preserving 16:9.
    private func resizedContentFrame(from start: NSRect, dx: CGFloat, dy: CGFloat) -> NSRect {
        let minW = ScreenGeometry.minVideoWidth
        let aspect = ScreenGeometry.videoAspectRatio
        let fixedTopY = start.origin.y + start.height
        let widthDelta = abs(dx) >= abs(dy) ? dx : -dy * aspect
        let newW = max(minW, start.width + widthDelta)
        let newH = newW / aspect
        return NSRect(x: start.origin.x, y: fixedTopY - newH, width: newW, height: newH)
    }
}

private enum ActiveInteraction {
    case none
    case dragging
    case resizing
}
