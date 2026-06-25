import AppKit

/// Unified chrome layer: draws grab line + corner arc, routes mouse to drag/resize regions.
final class OverlayChromeLayer: NSView {
    private weak var controller: OverlayController?
    private var videoRect = NSRect.zero
    private var placement = ChromePlacement.default
    private var insets = ChromeInsets.zero
    private var regions = ChromeInteractionRegions.make(
        videoRect: .zero,
        bounds: .zero,
        placement: .default,
        insets: .zero
    )

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

    func layoutChrome(videoRect: NSRect, in bounds: NSRect, placement: ChromePlacement, insets: ChromeInsets) {
        self.videoRect = videoRect
        self.placement = placement
        self.insets = insets
        self.regions = ChromeInteractionRegions.make(
            videoRect: videoRect,
            bounds: bounds,
            placement: placement,
            insets: insets
        )
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
        let lineRect = OverlayChromeLayout.grabLineRect(for: videoRect, dragEdge: placement.dragEdge)
        NSColor.white.withAlphaComponent(0.92).setFill()
        let radius = min(lineRect.width, lineRect.height) / 2
        NSBezierPath(roundedRect: lineRect, xRadius: radius, yRadius: radius).fill()
    }

    private func drawCornerArc() {
        let stroke = NSColor.white.withAlphaComponent(0.92)
        stroke.setStroke()

        let lineWidth = OverlayChromeLayout.chromeStrokeWidth
        let outwardGap = OverlayChromeLayout.cornerArcOutwardGap
        let r = OverlayChromeLayout.videoCornerRadius
        let arcRadius = r + outwardGap + lineWidth / 2

        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round

        switch placement.resizeCorner {
        case .bottomRight:
            let center = NSPoint(x: videoRect.maxX - r, y: videoRect.maxY - r)
            path.appendArc(withCenter: center, radius: arcRadius, startAngle: 0, endAngle: 90, clockwise: false)
        case .bottomLeft:
            let center = NSPoint(x: videoRect.minX + r, y: videoRect.maxY - r)
            path.appendArc(withCenter: center, radius: arcRadius, startAngle: 90, endAngle: 180, clockwise: false)
        case .topLeft:
            let center = NSPoint(x: videoRect.minX + r, y: videoRect.minY + r)
            path.appendArc(withCenter: center, radius: arcRadius, startAngle: 180, endAngle: 270, clockwise: false)
        case .topRight:
            let center = NSPoint(x: videoRect.maxX - r, y: videoRect.minY + r)
            path.appendArc(withCenter: center, radius: arcRadius, startAngle: 270, endAngle: 360, clockwise: false)
        }

        path.stroke()
    }

    // MARK: - Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, bounds.contains(point) else { return nil }
        if regions.region(at: point, videoRect: videoRect, bounds: bounds) != nil {
            return self
        }
        return nil
    }

    // MARK: - Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }

        let marginArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(marginArea)

        let resizeArea = NSTrackingArea(
            rect: regions.resizeRegion,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(resizeArea)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard activeInteraction == .none else { return }

        var dragRects = bounds
        if dragRects.width > 0, dragRects.height > 0 {
            // Exclude video and resize zone from open-hand rects by adding margin strips
            addCursorRectForMargins(cursor: .openHand)
        }
        addCursorRect(regions.resizeRegion, cursor: ChromeResizeCursor.forCorner(placement.resizeCorner))
    }

    private func addCursorRectForMargins(cursor: NSCursor) {
        let v = videoRect
        let b = bounds

        if v.minY > b.minY {
            addCursorRect(NSRect(x: b.minX, y: b.minY, width: b.width, height: v.minY - b.minY), cursor: cursor)
        }
        if v.maxY < b.maxY {
            addCursorRect(NSRect(x: b.minX, y: v.maxY, width: b.width, height: b.maxY - v.maxY), cursor: cursor)
        }
        if v.minX > b.minX {
            addCursorRect(NSRect(x: b.minX, y: v.minY, width: v.minX - b.minX, height: v.height), cursor: cursor)
        }
        if v.maxX < b.maxX {
            addCursorRect(NSRect(x: v.maxX, y: v.minY, width: b.maxX - v.maxX, height: v.height), cursor: cursor)
        }
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
        let resizeCursor = ChromeResizeCursor.forCorner(placement.resizeCorner)
        switch activeInteraction {
        case .dragging:
            NSCursor.closedHand.set()
        case .resizing:
            resizeCursor.set()
        case .none:
            switch regions.region(at: point, videoRect: videoRect, bounds: bounds) {
            case .drag:
                NSCursor.openHand.set()
            case .resize:
                resizeCursor.set()
            case nil:
                NSCursor.arrow.set()
            }
        }
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let region = regions.region(at: point, videoRect: videoRect, bounds: bounds),
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
            ChromeResizeCursor.forCorner(placement.resizeCorner).set()
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
            ChromeResizeCursor.forCorner(placement.resizeCorner).set()
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

    private func resizedContentFrame(from start: NSRect, dx: CGFloat, dy: CGFloat) -> NSRect {
        let minW = ScreenGeometry.minVideoWidth
        let aspect = controller?.contentAspectRatio ?? ScreenGeometry.videoAspectRatio

        switch placement.resizeCorner {
        case .bottomRight:
            let fixedTopY = start.origin.y + start.height
            let widthDelta = abs(dx) >= abs(dy) ? dx : -dy * aspect
            let newW = max(minW, start.width + widthDelta)
            let newH = newW / aspect
            return NSRect(x: start.origin.x, y: fixedTopY - newH, width: newW, height: newH)

        case .topLeft:
            let fixedBottomY = start.origin.y
            let widthDelta = abs(dx) >= abs(dy) ? -dx : dy * aspect
            let newW = max(minW, start.width + widthDelta)
            let newH = newW / aspect
            return NSRect(x: start.maxX - newW, y: fixedBottomY, width: newW, height: newH)

        case .bottomLeft:
            let fixedTopY = start.origin.y + start.height
            let fixedRightX = start.maxX
            let widthDelta = abs(dx) >= abs(dy) ? -dx : -dy * aspect
            let newW = max(minW, start.width + widthDelta)
            let newH = newW / aspect
            return NSRect(x: fixedRightX - newW, y: fixedTopY - newH, width: newW, height: newH)

        case .topRight:
            let fixedBottomY = start.origin.y
            let fixedLeftX = start.origin.x
            let widthDelta = abs(dx) >= abs(dy) ? dx : dy * aspect
            let newW = max(minW, start.width + widthDelta)
            let newH = newW / aspect
            return NSRect(x: fixedLeftX, y: fixedBottomY, width: newW, height: newH)
        }
    }
}

private enum ActiveInteraction {
    case none
    case dragging
    case resizing
}
