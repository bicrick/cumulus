import AppKit
import SwiftUI

enum ChromeDragMode: Equatable {
    case move
    case resize(ResizeCorner)
}

/// AppKit chrome layer for 1:1 screen-space drag and resize while Shift is held.
final class OverlayChromeNSView: NSView {
    weak var controller: OverlayController?

    private var dragMode: ChromeDragMode?
    private var startMouseLocation: NSPoint = .zero
    private var startFrame: NSRect = .zero

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard controller?.interactionMode == .interactive else { return nil }
        return region(for: point) != nil ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let panelFrame = controller?.panelFrame,
              let mode = region(for: convert(event.locationInWindow, from: nil)) else { return }

        startMouseLocation = NSEvent.mouseLocation
        startFrame = panelFrame
        dragMode = mode
    }

    override func mouseDragged(with event: NSEvent) {
        guard let controller, let dragMode else { return }

        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - startMouseLocation.x
        let dy = currentMouse.y - startMouseLocation.y

        let frame: NSRect
        switch dragMode {
        case .move:
            frame = NSRect(
                x: startFrame.origin.x + dx,
                y: startFrame.origin.y + dy,
                width: startFrame.width,
                height: startFrame.height
            )
        case .resize(let corner):
            frame = resizedFrame(from: startFrame, corner: corner, dx: dx, dy: dy)
        }

        controller.applyFrameDirectly(frame)
    }

    override func mouseUp(with event: NSEvent) {
        dragMode = nil
        controller?.persistFrame()
    }

    override func resetCursorRects() {
        guard controller?.interactionMode == .interactive else { return }

        let bounds = self.bounds
        let handle: CGFloat = 22
        let edge: CGFloat = 10
        let topBar: CGFloat = 28

        addCursorRect(NSRect(x: handle, y: topBar, width: bounds.width - handle * 2, height: bounds.height - handle - topBar), cursor: .arrow)
        addCursorRect(NSRect(x: 0, y: bounds.height - topBar, width: bounds.width, height: topBar), cursor: .openHand)

        addCursorRect(NSRect(x: 0, y: bounds.height - handle, width: handle, height: handle), cursor: .crosshair)
        addCursorRect(NSRect(x: bounds.width - handle, y: bounds.height - handle, width: handle, height: handle), cursor: .crosshair)
        addCursorRect(NSRect(x: 0, y: 0, width: handle, height: handle), cursor: .crosshair)
        addCursorRect(NSRect(x: bounds.width - handle, y: 0, width: handle, height: handle), cursor: .crosshair)

        addCursorRect(NSRect(x: 0, y: handle, width: edge, height: bounds.height - handle * 2 - topBar), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: bounds.width - edge, y: handle, width: edge, height: bounds.height - handle * 2 - topBar), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: handle, y: 0, width: bounds.width - handle * 2, height: edge), cursor: .resizeUpDown)
    }

    private func region(for point: NSPoint) -> ChromeDragMode? {
        let handle: CGFloat = 22
        let edge: CGFloat = 10
        let topBar: CGFloat = 28
        let bounds = self.bounds

        if point.y >= bounds.height - topBar { return .move }

        if point.x <= handle && point.y >= bounds.height - handle { return .resize(.topLeft) }
        if point.x >= bounds.width - handle && point.y >= bounds.height - handle { return .resize(.topRight) }
        if point.x <= handle && point.y <= handle { return .resize(.bottomLeft) }
        if point.x >= bounds.width - handle && point.y <= handle { return .resize(.bottomRight) }

        if point.x <= edge { return .resize(.bottomLeft) }
        if point.x >= bounds.width - edge { return .resize(.bottomRight) }
        if point.y <= edge { return .resize(.bottomRight) }

        return nil
    }

    private func resizedFrame(from start: NSRect, corner: ResizeCorner, dx: CGFloat, dy: CGFloat) -> NSRect {
        let minSize = NSSize(width: 320, height: 180)
        var frame = start

        switch corner {
        case .bottomRight:
            frame.size.width = max(minSize.width, start.width + dx)
            frame.size.height = max(minSize.height, start.height + dy)
        case .bottomLeft:
            let newWidth = max(minSize.width, start.width - dx)
            frame.origin.x = start.origin.x + (start.width - newWidth)
            frame.size.width = newWidth
            frame.size.height = max(minSize.height, start.height + dy)
        case .topRight:
            frame.size.width = max(minSize.width, start.width + dx)
            let newHeight = max(minSize.height, start.height + dy)
            frame.origin.y = start.origin.y + (start.height - newHeight)
            frame.size.height = newHeight
        case .topLeft:
            let newWidth = max(minSize.width, start.width - dx)
            let newHeight = max(minSize.height, start.height + dy)
            frame.origin.x = start.origin.x + (start.width - newWidth)
            frame.origin.y = start.origin.y + (start.height - newHeight)
            frame.size.width = newWidth
            frame.size.height = newHeight
        }

        return frame
    }
}

struct OverlayInteractiveChrome: NSViewRepresentable {
    @ObservedObject var controller: OverlayController

    func makeNSView(context: Context) -> OverlayChromeNSView {
        let view = OverlayChromeNSView()
        view.controller = controller
        return view
    }

    func updateNSView(_ nsView: OverlayChromeNSView, context: Context) {
        nsView.controller = controller
        nsView.isHidden = controller.interactionMode != .interactive
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

struct OverlayInteractiveChromeVisual: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 28)
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 36, height: 4)
                }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
