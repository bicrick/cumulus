import AppKit
import SwiftUI

@MainActor
final class ControlPanelController {
    private var panel: NSPanel?
    private weak var appModel: AppModel?

    func show(appModel: AppModel) {
        self.appModel = appModel

        if panel == nil {
            createPanel(appModel: appModel)
        } else if let hosting = panel?.contentView as? NSHostingView<ControlPanelView> {
            hosting.rootView = ControlPanelView(appModel: appModel)
        }

        positionPanel()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel(appModel: AppModel) {
        let content = ControlPanelView(appModel: appModel)
        let hostingView = NSHostingView(rootView: content)

        let size = NSSize(width: 280, height: 340)
        let origin = defaultOrigin(for: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Cumulus"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true

        self.panel = panel
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.origin.x = visible.maxX - frame.width - 20
        frame.origin.y = visible.minY + 20
        panel.setFrame(frame, display: true)
    }

    private func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let visible = screen.visibleFrame
        return NSPoint(
            x: visible.maxX - size.width - 20,
            y: visible.minY + 20
        )
    }
}

struct ControlPanelView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var controller: OverlayController

    init(appModel: AppModel) {
        self.appModel = appModel
        self.controller = appModel.controller
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cumulus")
                .font(.headline)

            statusSection

            Divider()

            Button("Paste URL & Open") {
                appModel.controller.pasteFromClipboard()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("Center Overlay on Screen") {
                appModel.controller.centerOverlay()
            }

            Button("Reload Video") {
                appModel.controller.reloadVideo()
            }

            Button(appModel.controller.isVisible ? "Hide Overlay" : "Show Overlay") {
                controller.toggleOverlay()
            }

            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button("Close Overlay") {
                appModel.controller.closeOverlay()
            }

            Divider()

            Text("Cmd+Shift+Y toggles overlay")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Hold Shift on overlay for YouTube controls")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minWidth: 260)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Overlay: \(controller.isVisible ? "visible" : "hidden")")
                .font(.caption)
                .foregroundStyle(controller.isVisible ? .green : .secondary)

            if let videoID = controller.currentVideoID {
                Text("Video: \(videoID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Video: none loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = controller.loadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
