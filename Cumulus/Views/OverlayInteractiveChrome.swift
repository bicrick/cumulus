import AppKit
import SwiftUI

// MARK: - Drag handle (top bar, outside video)

final class ChromeDragBarNSView: NSView {
    weak var controller: OverlayController?

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
        controller?.persistFrame()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

struct ChromeDragBar: NSViewRepresentable {
    @ObservedObject var controller: OverlayController

    func makeNSView(context: Context) -> ChromeDragBarNSView {
        let view = ChromeDragBarNSView()
        view.controller = controller
        return view
    }

    func updateNSView(_ nsView: ChromeDragBarNSView, context: Context) {
        nsView.controller = controller
    }
}

// MARK: - Resize handle (bottom corners, outside video)

final class ChromeResizeCornerNSView: NSView {
    weak var controller: OverlayController?
    var corner: ResizeCorner = .bottomRight

    private var startMouse = NSPoint.zero
    private var startContentFrame = NSRect.zero

    override func mouseDown(with event: NSEvent) {
        guard let panelFrame = controller?.panelFrame else { return }
        startMouse = NSEvent.mouseLocation
        startContentFrame = OverlayChromeLayout.contentFrame(from: panelFrame)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let controller else { return }

        let dx = NSEvent.mouseLocation.x - startMouse.x
        let dy = NSEvent.mouseLocation.y - startMouse.y
        let newContent = resizedContentFrame(from: startContentFrame, corner: corner, dx: dx, dy: dy)
        controller.applyContentFrameDirectly(newContent)
    }

    override func mouseUp(with event: NSEvent) {
        controller?.persistFrame()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private func resizedContentFrame(from start: NSRect, corner: ResizeCorner, dx: CGFloat, dy: CGFloat) -> NSRect {
        let minW = ScreenGeometry.minVideoWidth
        let aspect = ScreenGeometry.videoAspectRatio

        let widthDelta: CGFloat
        switch corner {
        case .bottomRight:
            widthDelta = abs(dx) >= abs(dy) ? dx : dy * aspect
            let newW = max(minW, start.width + widthDelta)
            return NSRect(x: start.origin.x, y: start.origin.y, width: newW, height: newW / aspect)

        case .bottomLeft:
            widthDelta = abs(dx) >= abs(dy) ? -dx : dy * aspect
            let newW = max(minW, start.width + widthDelta)
            return NSRect(x: start.origin.x + start.width - newW, y: start.origin.y, width: newW, height: newW / aspect)

        case .topRight, .topLeft:
            return start
        }
    }
}

struct ChromeResizeCorner: NSViewRepresentable {
    @ObservedObject var controller: OverlayController
    let corner: ResizeCorner

    func makeNSView(context: Context) -> ChromeResizeCornerNSView {
        let view = ChromeResizeCornerNSView()
        view.controller = controller
        view.corner = corner
        return view
    }

    func updateNSView(_ nsView: ChromeResizeCornerNSView, context: Context) {
        nsView.controller = controller
        nsView.corner = corner
    }
}

// MARK: - Visual chrome (white grab lines, outside video)

struct ExternalChromeVisual: View {
    var body: some View {
        VStack(spacing: 0) {
            topBarVisual
            HStack(spacing: 0) {
                sideVisual
                Rectangle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    .background(Color.black)
                sideVisual
            }
            bottomBarVisual
        }
        .allowsHitTesting(false)
    }

    private var topBarVisual: some View {
        ZStack {
            Color(white: 0.12)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.55))
                .frame(width: 48, height: 4)
        }
        .frame(height: OverlayChromeLayout.topBarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1)
        }
    }

    private var sideVisual: some View {
        Color(white: 0.12)
            .frame(width: OverlayChromeLayout.sideInset)
    }

    private var bottomBarVisual: some View {
        ZStack {
            Color(white: 0.12)
            HStack {
                cornerBracket(flipHorizontal: true)
                Spacer()
                cornerBracket(flipHorizontal: false)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: OverlayChromeLayout.bottomBarHeight)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1)
        }
    }

    private func cornerBracket(flipHorizontal: Bool) -> some View {
        let s = OverlayChromeLayout.cornerHandleSize
        return Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: s * 0.55))
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: s * 0.55, y: 0))
        }
        .stroke(Color.white.opacity(0.6), lineWidth: 2)
        .frame(width: s, height: s)
        .scaleEffect(x: flipHorizontal ? -1 : 1, y: 1)
    }
}
