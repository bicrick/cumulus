import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<SettingsView>?

    private init() {}

    func toggle(appModel: AppModel, anchorTo statusItem: NSStatusItem) {
        if window?.isVisible == true {
            window?.orderOut(nil)
            return
        }
        open(appModel: appModel, anchorTo: statusItem)
    }

    func open(appModel: AppModel, anchorTo statusItem: NSStatusItem) {
        let content = SettingsView(settings: appModel.settings, controller: appModel.controller)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 460, height: 560)

        if window == nil {
            let window = NSWindow(
                contentRect: hosting.frame,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Cumulus Settings"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            self.window = window
            self.hostingView = hosting
        } else {
            hostingView?.rootView = content
        }

        guard let window else { return }

        let windowSize = NSSize(width: 460, height: 560)
        var origin = defaultOrigin(for: windowSize, statusItem: statusItem)
        origin = clampOrigin(origin, windowSize: windowSize)
        window.setFrame(NSRect(origin: origin, size: windowSize), display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func defaultOrigin(for windowSize: NSSize, statusItem: NSStatusItem) -> NSPoint {
        if let button = statusItem.button,
           let buttonWindow = button.window {
            let screenFrame = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(screenFrame)
            return NSPoint(
                x: screenRect.maxX - windowSize.width,
                y: screenRect.minY - windowSize.height - 6
            )
        }

        guard let screen = NSScreen.main else {
            return NSPoint(x: 200, y: 200)
        }
        let visible = screen.visibleFrame
        return NSPoint(
            x: visible.maxX - windowSize.width - 16,
            y: visible.maxY - windowSize.height - 16
        )
    }

    private func clampOrigin(_ origin: NSPoint, windowSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(NSPoint(x: origin.x + windowSize.width / 2, y: origin.y + windowSize.height / 2))
        }) ?? NSScreen.main else {
            return origin
        }

        let visible = screen.visibleFrame
        let x = min(max(origin.x, visible.minX), visible.maxX - windowSize.width)
        let y = min(max(origin.y, visible.minY), visible.maxY - windowSize.height)
        return NSPoint(x: x, y: y)
    }
}
