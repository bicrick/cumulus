import AppKit
import SwiftUI

@MainActor
final class OverlayController: ObservableObject {
    @Published private(set) var interactionMode: InteractionMode = .passive
    @Published private(set) var isVisible = false
    @Published var currentVideoID: String?
    @Published var loadError: String?
    @Published private(set) var playerGeneration = 0

    var onVisibilityChanged: (() -> Void)?
    private var panel: OverlayPanel?
    private var hostingView: NSHostingView<OverlayRootView>?
    private let inputPoller = InputPoller()
    private var settings: OverlaySettings
    private var settingsCancellables: [Any] = []

    init(settings: OverlaySettings) {
        self.settings = settings
        inputPoller.onTick = { [weak self] in
            self?.updateInteractionState()
        }
    }

    func bind(settings: OverlaySettings) {
        self.settings = settings
    }

    func showOverlay() {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        applyFrame(settings.overlayFrame)
        panel.orderFrontRegardless()
        panel.level = .statusBar
        isVisible = true
        onVisibilityChanged?()
        inputPoller.start()
        updateInteractionState()
    }

    func hideOverlay() {
        panel?.orderOut(nil)
        isVisible = false
        onVisibilityChanged?()
        inputPoller.stop()
    }

    func toggleOverlay() {
        if isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func closeOverlay() {
        persistFrame()
        hideOverlay()
        panel?.close()
        panel = nil
        hostingView = nil
        currentVideoID = nil
    }

    func loadVideo(from urlString: String) {
        DebugLog.write("loadVideo called with: \(urlString.prefix(120))")

        guard let videoID = YouTubeURLParser.videoID(from: urlString) else {
            loadError = "Could not parse YouTube URL."
            DebugLog.write("Failed to parse URL")
            return
        }

        loadError = nil
        currentVideoID = videoID
        settings.lastVideoURL = urlString

        let size = ScreenGeometry.sizeMatchingAspect(width: max(settings.overlayFrame.width, ScreenGeometry.minVideoWidth))
        settings.overlayFrame = OverlayFrame(from: ScreenGeometry.centeredFrame(size: size))

        if panel == nil {
            createPanel()
        } else {
            refreshHostingView()
        }

        playerGeneration += 1
        showOverlay()
        DebugLog.write("Showing overlay for videoID=\(videoID) frame=\(settings.overlayFrame)")
    }

    func pasteFromClipboard() {
        guard let clipboard = NSPasteboard.general.string(forType: .string) else {
            loadError = "Clipboard is empty."
            DebugLog.write("Clipboard empty")
            return
        }
        DebugLog.write("Clipboard: \(clipboard.prefix(120))")
        loadVideo(from: clipboard)
    }

    func restoreLastVideoIfNeeded() {
        guard !settings.lastVideoURL.isEmpty else { return }
        if let videoID = YouTubeURLParser.videoID(from: settings.lastVideoURL) {
            currentVideoID = videoID
            let size = ScreenGeometry.sizeMatchingAspect(width: 480)
            settings.overlayFrame = OverlayFrame(from: ScreenGeometry.centeredFrame(size: size))
            playerGeneration += 1
            createPanel()
            showOverlay()
            DebugLog.write("Restored last video \(videoID)")
        }
    }

    func persistFrame() {
        guard let panel else { return }
        let content = interactionMode == .interactive
            ? OverlayChromeLayout.contentFrame(from: panel.frame)
            : panel.frame
        settings.overlayFrame = OverlayFrame(from: ScreenGeometry.normalizedFrame(content))
    }

    var panelFrame: NSRect? {
        panel?.frame
    }

    func applyFrameDirectly(_ frame: NSRect) {
        applyContentFrameDirectly(frame)
    }

    func applyContentFrameDirectly(_ contentFrame: NSRect) {
        let normalized = ScreenGeometry.normalizedFrame(contentFrame)
        let windowFrame = interactionMode == .interactive
            ? OverlayChromeLayout.windowFrame(forContentRect: normalized)
            : normalized
        panel?.setFrame(windowFrame, display: true)
        settings.overlayFrame = OverlayFrame(from: normalized)
    }

    func reloadVideo() {
        guard currentVideoID != nil else { return }
        playerGeneration += 1
        refreshHostingView()
        if isVisible {
            panel?.orderFrontRegardless()
        }
        DebugLog.write("Reloaded video player")
    }

    func centerOverlay() {
        let size = ScreenGeometry.sizeMatchingAspect(width: max(settings.overlayFrame.width, ScreenGeometry.minVideoWidth))
        settings.overlayFrame = OverlayFrame(from: ScreenGeometry.centeredFrame(size: size))
        applyFrame(settings.overlayFrame)
        if isVisible {
            panel?.orderFrontRegardless()
        } else {
            showOverlay()
        }
        DebugLog.write("Centered overlay at \(settings.overlayFrame)")
    }

    private func createPanel() {
        let frame = settings.overlayFrame.cgRect
        let panel = OverlayPanel(contentRect: frame)

        let rootView = OverlayRootView(
            controller: self,
            settings: settings
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        panel.delegate = PanelDelegate.shared
        panel.alphaValue = CGFloat(settings.restingOpacity)
        panel.ignoresMouseEvents = settings.clickThroughWhenPassive

        self.panel = panel
        self.hostingView = hostingView
        DebugLog.write("Created overlay panel at \(frame)")
    }

    private func refreshHostingView() {
        guard let hostingView else { return }
        hostingView.rootView = OverlayRootView(controller: self, settings: settings)
    }

    private func reloadWebView() {
        refreshHostingView()
    }

    private func applyFrame(_ overlayFrame: OverlayFrame) {
        panel?.setFrame(ScreenGeometry.normalizedFrame(overlayFrame.cgRect), display: true)
    }

    func updateInteractionState() {
        guard let panel, isVisible else { return }

        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let isInside = frame.contains(mouse)
        let modifierHeld = NSEvent.modifierFlags.contains(settings.interactiveModifier)

        let newMode: InteractionMode
        if isInside && modifierHeld {
            newMode = .interactive
        } else if isInside {
            newMode = .hover
        } else {
            newMode = .passive
        }

        if newMode != interactionMode {
            let previousMode = interactionMode
            interactionMode = newMode
            applyMode(newMode, from: previousMode)
        }
    }

    private func applyMode(_ mode: InteractionMode, from previousMode: InteractionMode) {
        guard let panel else { return }

        // Expand / contract window so chrome sits outside the video
        if mode == .interactive && previousMode != .interactive {
            let content = ScreenGeometry.normalizedFrame(panel.frame)
            panel.setFrame(OverlayChromeLayout.windowFrame(forContentRect: content), display: true)
        } else if mode != .interactive && previousMode == .interactive {
            let content = ScreenGeometry.normalizedFrame(
                OverlayChromeLayout.contentFrame(from: panel.frame)
            )
            panel.setFrame(content, display: true)
            settings.overlayFrame = OverlayFrame(from: content)
        }

        let targetOpacity = settings.opacity(for: mode)
        let duration = settings.transitionMs / 1000.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel.animator().alphaValue = CGFloat(targetOpacity)
        }

        switch mode {
        case .passive, .hover:
            panel.ignoresMouseEvents = settings.clickThroughWhenPassive
        case .interactive:
            panel.ignoresMouseEvents = false
        }
    }

    func embedURL(for videoID: String) -> URL? {
        YouTubeURLParser.embedURL(videoID: videoID, autoplayMuted: settings.autoplayMuted)
    }

    func handleSettingsChanged() {
        if isVisible {
            applyMode(interactionMode, from: interactionMode)
        }
        if currentVideoID != nil {
            playerGeneration += 1
            refreshHostingView()
        }
    }
}

enum ResizeCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

private final class PanelDelegate: NSObject, NSWindowDelegate {
    static let shared = PanelDelegate()

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow else { return }
        panel.orderOut(nil)
    }

    func windowDidMove(_ notification: Notification) {
        // Frame persistence handled by controller drag/resize
    }

    func windowDidResize(_ notification: Notification) {
        // Frame persistence handled by controller drag/resize
    }
}
