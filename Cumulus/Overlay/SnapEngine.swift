import AppKit

enum SnapAnchor: String, CaseIterable, Codable, Identifiable {
    case topLeft
    case topCenter
    case topRight
    case centerLeft
    case center
    case centerRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .centerLeft: return "Center Left"
        case .center: return "Center"
        case .centerRight: return "Center Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        }
    }

    static var defaultCorners: Set<SnapAnchor> {
        [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }
}

struct SnapEngine {
    func snapFrames(
        for contentSize: NSSize,
        in visibleFrame: NSRect,
        margin: CGFloat,
        enabled: Set<SnapAnchor>
    ) -> [SnapAnchor: NSRect] {
        let w = contentSize.width
        let h = contentSize.height
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - margin - w
        let minY = visibleFrame.minY + margin
        let maxY = visibleFrame.maxY - margin - h
        let midX = visibleFrame.midX - w / 2
        let midY = visibleFrame.midY - h / 2

        var result: [SnapAnchor: NSRect] = [:]
        for anchor in enabled {
            let origin: NSPoint
            switch anchor {
            case .topLeft: origin = NSPoint(x: minX, y: maxY)
            case .topCenter: origin = NSPoint(x: midX, y: maxY)
            case .topRight: origin = NSPoint(x: maxX, y: maxY)
            case .centerLeft: origin = NSPoint(x: minX, y: midY)
            case .center: origin = NSPoint(x: midX, y: midY)
            case .centerRight: origin = NSPoint(x: maxX, y: midY)
            case .bottomLeft: origin = NSPoint(x: minX, y: minY)
            case .bottomCenter: origin = NSPoint(x: midX, y: minY)
            case .bottomRight: origin = NSPoint(x: maxX, y: minY)
            }
            result[anchor] = NSRect(origin: origin, size: contentSize)
        }
        return result
    }

    func nearestAnchor(
        to contentFrame: NSRect,
        candidates: [SnapAnchor: NSRect],
        threshold: CGFloat
    ) -> SnapAnchor? {
        let center = NSPoint(x: contentFrame.midX, y: contentFrame.midY)
        var best: (SnapAnchor, CGFloat)?

        for (anchor, frame) in candidates {
            let snapCenter = NSPoint(x: frame.midX, y: frame.midY)
            let dx = center.x - snapCenter.x
            let dy = center.y - snapCenter.y
            let distance = hypot(dx, dy)
            if distance <= threshold {
                if best == nil || distance < best!.1 {
                    best = (anchor, distance)
                }
            }
        }
        return best?.0
    }

    /// Returns the nearest snap anchor regardless of threshold (for chrome placement).
    func closestAnchor(to contentFrame: NSRect, candidates: [SnapAnchor: NSRect]) -> SnapAnchor {
        let center = NSPoint(x: contentFrame.midX, y: contentFrame.midY)
        var best: (SnapAnchor, CGFloat)?

        for (anchor, frame) in candidates {
            let snapCenter = NSPoint(x: frame.midX, y: frame.midY)
            let dx = center.x - snapCenter.x
            let dy = center.y - snapCenter.y
            let distance = hypot(dx, dy)
            if best == nil || distance < best!.1 {
                best = (anchor, distance)
            }
        }

        return best?.0 ?? .center
    }
}
