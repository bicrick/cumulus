import AppKit
import Foundation
import QuartzCore

@MainActor
final class OverlayController: ObservableObject {
    @Published private(set) var interactionMode: InteractionMode = .passive
    @Published private(set) var isVisible = false
    @Published var currentVideoID: String?
    @Published var loadError: String?
    @Published private(set) var playerGeneration = 0

    var onVisibilityChanged: (() -> Void)?

    private var panel: OverlayPanel?
    private var contentView: OverlayContentView?
    private let playerController = YouTubePlayerController()
    private let inputPoller = InputPoller()
    private let snapEngine = SnapEngine()
    private let snapOverlay = SnapOverlayController()
    private var settings: OverlaySettings
    private var isWindowBeingManipulated = false
    private var isDragging = false
    private var pendingExitMode: InteractionMode?
    private var exitModeStreak = 0
    private var currentChromeInsets = ChromeInsets.zero
    private var currentChromePlacement = ChromePlacement.default

    init(settings: OverlaySettings) {
        self.settings = settings
        inputPoller.onTick = { [weak self] in
            self?.updateInteractionState()
        }
        playerController.onLoadError = { [weak self] error in
            self?.loadError = error
        }
    }

    func bind(settings: OverlaySettings) {
        self.settings = settings
    }

    func beginWindowManipulation() {
        isWindowBeingManipulated = true
    }

    func endWindowManipulation() {
        isWindowBeingManipulated = false
    }

    func beginDrag() {
        isDragging = true
        beginWindowManipulation()
        DebugLog.write("Drag started")
    }

    func finishDrag() {
        guard isDragging else { return }

        let content = currentContentFrame()
        if settings.snapEnabled {
            let visible = visibleFrame(for: content)
            let candidates = snapEngine.snapFrames(
                for: content.size,
                in: visible,
                margin: CGFloat(settings.snapEdgeMargin),
                enabled: settings.enabledSnapAnchors
            )
            if let anchor = snapEngine.nearestAnchor(
                to: content,
                candidates: candidates,
                threshold: CGFloat(settings.snapThreshold)
            ), let target = candidates[anchor] {
                DebugLog.write("Snapping to \(anchor.rawValue)")
                animateToContentFrame(target) { [weak self] in
                    self?.completeDrag()
                }
                return
            }
        }

        completeDrag()
    }

    private func completeDrag() {
        persistFrame()
        snapOverlay.hide()
        isDragging = false
        endWindowManipulation()
        DebugLog.write("Drag ended")
    }

    func updateSnapPreview(for contentFrame: NSRect) {
        guard settings.snapEnabled else {
            snapOverlay.hide()
            return
        }

        let visible = visibleFrame(for: contentFrame)
        let candidates = snapEngine.snapFrames(
            for: contentFrame.size,
            in: visible,
            margin: CGFloat(settings.snapEdgeMargin),
            enabled: settings.enabledSnapAnchors
        )
        let highlighted = snapEngine.nearestAnchor(
            to: contentFrame,
            candidates: candidates,
            threshold: CGFloat(settings.snapThreshold)
        )
        snapOverlay.show(on: ScreenGeometry.screen(for: contentFrame), candidates: candidates, highlighted: highlighted)
    }

    func clampContentFrame(_ frame: NSRect) -> NSRect {
        ScreenGeometry.clampContentFrame(frame, in: visibleFrame(for: frame))
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
        snapOverlay.hide()
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
        contentView = nil
        currentVideoID = nil
    }

    func loadVideo(from urlString: String) {
        DebugLog.write("loadVideo called with: \(urlString.prefix(120))")

        guard let videoID = YouTubeURLParser.videoID(from: urlString) else {
            loadError = "Could not parse YouTube URL."
            return
        }

        loadError = nil
        currentVideoID = videoID
        settings.lastVideoURL = urlString

        let size = ScreenGeometry.sizeMatchingAspect(width: max(settings.overlayFrame.width, ScreenGeometry.minVideoWidth))
        settings.overlayFrame = OverlayFrame(from: ScreenGeometry.centeredFrame(size: size))

        if panel == nil {
            createPanel()
        }

        playerGeneration += 1
        playerController.load(
            videoID: videoID,
            autoplayMuted: settings.autoplayMuted,
            generation: playerGeneration
        )
        showOverlay()
    }

    func pasteFromClipboard() {
        guard let clipboard = NSPasteboard.general.string(forType: .string) else {
            loadError = "Clipboard is empty."
            return
        }
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
            playerController.load(
                videoID: videoID,
                autoplayMuted: settings.autoplayMuted,
                generation: playerGeneration
            )
            showOverlay()
        }
    }

    func persistFrame() {
        guard let panel else { return }
        let content = currentContentFrame()
        let normalized = ScreenGeometry.normalizedFrame(content)
        let targetWindow = windowFrame(forContent: normalized)

        if panel.frame != targetWindow {
            panel.setFrame(targetWindow, display: true)
        }

        settings.overlayFrame = OverlayFrame(from: normalized)
        syncVideoLayout()
    }

    var panelFrame: NSRect? {
        panel?.frame
    }

    func contentFrame(from windowFrame: NSRect) -> NSRect {
        if interactionMode == .interactive || isDragging {
            return ScreenGeometry.normalizedFrame(
                OverlayChromeLayout.contentFrame(from: windowFrame, insets: currentChromeInsets)
            )
        }
        return ScreenGeometry.normalizedFrame(windowFrame)
    }

    func applyFrameDirectly(_ frame: NSRect) {
        applyContentFrameDirectly(frame)
    }

    func applyContentFrameDirectly(_ contentFrame: NSRect, persist: Bool = true) {
        let normalized = ScreenGeometry.normalizedFrame(clampContentFrame(contentFrame))
        let windowFrame = windowFrame(forContent: normalized)
        panel?.setFrame(windowFrame, display: true)
        syncVideoLayout()
        if persist {
            settings.overlayFrame = OverlayFrame(from: normalized)
        }
    }

    func notifyPlayerResized() {
        guard let contentView else { return }
        let frame = contentView.videoContainer.bounds
        playerController.notifyResized(
            width: Int(frame.width),
            height: Int(frame.height)
        )
    }

    func reloadVideo() {
        guard let videoID = currentVideoID else { return }
        playerGeneration += 1
        playerController.load(
            videoID: videoID,
            autoplayMuted: settings.autoplayMuted,
            generation: playerGeneration
        )
        panel?.orderFrontRegardless()
    }

    func centerOverlay() {
        let size = ScreenGeometry.sizeMatchingAspect(width: max(settings.overlayFrame.width, ScreenGeometry.minVideoWidth))
        settings.overlayFrame = OverlayFrame(from: ScreenGeometry.centeredFrame(size: size))
        applyFrame(settings.overlayFrame)
        panel?.orderFrontRegardless()
    }

    private func createPanel() {
        let frame = settings.overlayFrame.cgRect
        let panel = OverlayPanel(contentRect: frame)

        let contentView = OverlayContentView(controller: self)
        contentView.frame = panel.contentView?.bounds ?? .zero
        contentView.autoresizingMask = [.width, .height]

        playerController.attach(to: contentView.videoContainer)

        panel.contentView = contentView
        panel.delegate = PanelDelegate.shared
        panel.alphaValue = CGFloat(settings.restingOpacity)
        panel.ignoresMouseEvents = settings.clickThroughWhenPassive
        OverlayPanel.configureTransparency(for: panel)

        self.panel = panel
        self.contentView = contentView
        contentView.chromeLayer.isHidden = true
        syncVideoLayout()
    }

    private func applyFrame(_ overlayFrame: OverlayFrame) {
        panel?.setFrame(ScreenGeometry.normalizedFrame(overlayFrame.cgRect), display: true)
        syncVideoLayout()
    }

    private func currentContentFrame() -> NSRect {
        guard let panel else { return .zero }
        return contentFrame(from: panel.frame)
    }

    private func windowFrame(forContent content: NSRect) -> NSRect {
        if interactionMode == .interactive || isDragging {
            let layout = chromeLayout(for: content)
            currentChromePlacement = layout.placement
            currentChromeInsets = layout.insets
            return OverlayChromeLayout.windowFrame(forContentRect: content, insets: layout.insets)
        }
        return content
    }

    private func chromeLayout(for contentFrame: NSRect) -> (placement: ChromePlacement, insets: ChromeInsets) {
        let candidates = snapEngine.snapFrames(
            for: contentFrame.size,
            in: visibleFrame(for: contentFrame),
            margin: CGFloat(settings.snapEdgeMargin),
            enabled: settings.enabledSnapAnchors
        )
        let anchor = snapEngine.closestAnchor(to: contentFrame, candidates: candidates)
        let placement = ChromePlacement.forSnapAnchor(anchor)
        let insets = OverlayChromeLayout.insets(for: placement)
        return (placement, insets)
    }

    private func visibleFrame(for contentFrame: NSRect) -> NSRect {
        ScreenGeometry.screen(for: contentFrame)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    }

    private func syncVideoLayout() {
        guard let contentView else { return }
        let interactive = interactionMode == .interactive || isDragging

        if interactive {
            let videoRect = OverlayChromeLayout.videoRect(in: contentView.bounds, insets: currentChromeInsets)
            contentView.syncLayout(
                interactive: true,
                videoRect: videoRect,
                placement: currentChromePlacement,
                insets: currentChromeInsets
            )
        } else {
            currentChromeInsets = .zero
            currentChromePlacement = .default
            contentView.syncLayout(
                interactive: false,
                videoRect: contentView.bounds,
                placement: .default,
                insets: .zero
            )
        }
        playerController.layoutInContainer(contentView.videoContainer)
    }

    private func animateToContentFrame(_ contentFrame: NSRect, completion: @escaping () -> Void) {
        guard let panel else {
            completion()
            return
        }

        let targetWindow = windowFrame(forContent: contentFrame)
        let duration = settings.snapAnimationMs / 1000.0

        beginWindowManipulation()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(targetWindow, display: true)
        } completionHandler: { [weak self] in
            self?.syncVideoLayout()
            completion()
        }
    }

    func updateInteractionState() {
        guard let panel, isVisible, !isWindowBeingManipulated else { return }

        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let isInside = frame.contains(mouse)
        let modifierHeld = NSEvent.modifierFlags.contains(settings.interactiveModifier)

        let rawMode: InteractionMode
        if isInside && modifierHeld {
            rawMode = .interactive
        } else if isInside {
            rawMode = .hover
        } else {
            rawMode = .passive
        }

        let newMode = debouncedMode(rawMode)

        if newMode != interactionMode {
            let previousMode = interactionMode
            interactionMode = newMode
            DebugLog.write("Interaction mode: \(previousMode) -> \(newMode)")
            applyMode(newMode, from: previousMode)
        }
    }

    private func debouncedMode(_ rawMode: InteractionMode) -> InteractionMode {
        if interactionMode == .interactive && rawMode != .interactive {
            if pendingExitMode == rawMode {
                exitModeStreak += 1
            } else {
                pendingExitMode = rawMode
                exitModeStreak = 1
            }
            return exitModeStreak >= 2 ? rawMode : .interactive
        }

        pendingExitMode = nil
        exitModeStreak = 0
        return rawMode
    }

    private func applyMode(_ mode: InteractionMode, from previousMode: InteractionMode) {
        guard let panel, let contentView else { return }

        if mode == .interactive && previousMode != .interactive {
            let content = ScreenGeometry.normalizedFrame(
                previousMode == .interactive
                    ? OverlayChromeLayout.contentFrame(from: panel.frame, insets: currentChromeInsets)
                    : panel.frame
            )
            let layout = chromeLayout(for: content)
            currentChromePlacement = layout.placement
            currentChromeInsets = layout.insets
            panel.setFrame(
                OverlayChromeLayout.windowFrame(forContentRect: content, insets: layout.insets),
                display: true
            )
        } else if mode != .interactive && previousMode == .interactive {
            let content = ScreenGeometry.normalizedFrame(
                OverlayChromeLayout.contentFrame(from: panel.frame, insets: currentChromeInsets)
            )
            currentChromeInsets = .zero
            currentChromePlacement = .default
            panel.setFrame(content, display: true)
            settings.overlayFrame = OverlayFrame(from: content)
        }

        syncVideoLayout()
        OverlayPanel.configureTransparency(for: panel)

        let targetOpacity = settings.opacity(for: mode)
        let duration = settings.transitionMs / 1000.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel.animator().alphaValue = CGFloat(targetOpacity)
        }

        panel.ignoresMouseEvents = mode != .interactive && settings.clickThroughWhenPassive
        panel.acceptsMouseMovedEvents = mode == .interactive
        contentView.chromeLayer.isHidden = mode != .interactive
        if mode == .interactive {
            contentView.window?.invalidateCursorRects(for: contentView.chromeLayer)
        }
    }

    func handleSettingsChanged() {
        if isVisible {
            applyMode(interactionMode, from: interactionMode)
        }
    }

    func embedURL(for videoID: String) -> URL? {
        YouTubeURLParser.embedURL(videoID: videoID, autoplayMuted: settings.autoplayMuted)
    }
}

private final class PanelDelegate: NSObject, NSWindowDelegate {
    static let shared = PanelDelegate()

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow else { return }
        panel.orderOut(nil)
    }
}
