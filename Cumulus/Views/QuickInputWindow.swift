import AppKit

@MainActor
final class QuickInputWindowController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    static let shared = QuickInputWindowController()

    private var panel: NSPanel?
    private var textField: NSTextField?
    private var chromeView: QuickInputChromeView?
    private weak var controller: OverlayController?

    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    private let panelSize = NSSize(width: 480, height: 52)

    private override init() {
        super.init()
    }

    func open(controller: OverlayController) {
        self.controller = controller

        if panel == nil {
            createPanel()
        }

        guard let panel, let textField else { return }

        textField.stringValue = ""
        positionPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        installClickOutsideMonitors()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }

        focusTextField()
    }

    func close() {
        removeClickOutsideMonitors()
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        chromeView?.setFocused(false)
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let chrome = QuickInputChromeView(frame: NSRect(origin: .zero, size: panelSize))
        chrome.autoresizingMask = [.width, .height]

        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: "play.rectangle.fill",
            accessibilityDescription: "YouTube"
        )
        icon.contentTintColor = NSColor(red: 0.24, green: 0.35, blue: 0.50, alpha: 1)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let field = NSTextField()
        field.placeholderString = "Paste YouTube URL…"
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        field.textColor = .labelColor
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self

        chrome.addSubview(icon)
        chrome.addSubview(field)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: chrome.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -16),
            field.centerYAnchor.constraint(equalTo: chrome.centerYAnchor)
        ])

        panel.contentView = chrome
        self.panel = panel
        self.textField = field
        self.chromeView = chrome
    }

    private func positionPanel(_ panel: NSPanel) {
        let screen = screenForOverlay() ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        // Center on screen, upper third — not anchored to the overlay.
        let origin = NSPoint(
            x: visible.midX - panelSize.width / 2,
            y: visible.minY + visible.height * 0.68 - panelSize.height / 2
        )

        let clamped = NSPoint(
            x: max(visible.minX + 12, min(origin.x, visible.maxX - panelSize.width - 12)),
            y: max(visible.minY + 12, min(origin.y, visible.maxY - panelSize.height - 12))
        )
        panel.setFrameOrigin(clamped)
    }

    private func screenForOverlay() -> NSScreen? {
        guard let frame = controller?.panelFrame else { return NSScreen.main }
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }

    private func focusTextField() {
        guard let panel, let textField else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, let textField = self.textField else { return }
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(textField)

            if let editor = textField.currentEditor() as? NSTextView {
                editor.insertionPointColor = NSColor.controlAccentColor
                editor.selectedRange = NSRange(location: 0, length: 0)
            }

            self.chromeView?.setFocused(true)
        }
    }

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        controller?.loadVideo(from: trimmed)
        close()
    }

    private func installClickOutsideMonitors() {
        removeClickOutsideMonitors()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closeIfClickOutside()
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.closeIfClickOutside()
            }
            return event
        }
    }

    private func removeClickOutsideMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    private func closeIfClickOutside() {
        guard let panel, panel.isVisible else { return }
        let location = NSEvent.mouseLocation
        if !panel.frame.contains(location) {
            close()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submit(textField?.stringValue ?? "")
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            close()
            return true
        }
        return false
    }

    func windowDidBecomeKey(_ notification: Notification) {
        chromeView?.setFocused(true)
        focusTextField()
    }

    func windowDidResignKey(_ notification: Notification) {
        chromeView?.setFocused(false)
    }

    func windowWillClose(_ notification: Notification) {
        removeClickOutsideMonitors()
        textField?.stringValue = ""
    }
}

// MARK: - Chrome

private final class QuickInputChromeView: NSVisualEffectView {
    private let borderLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        state = .active
        blendingMode = .behindWindow
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        borderLayer.borderWidth = 1
        borderLayer.cornerRadius = 14
        borderLayer.cornerCurve = .continuous
        borderLayer.masksToBounds = true
        layer?.addSublayer(borderLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not implemented")
    }

    override func layout() {
        super.layout()
        borderLayer.frame = bounds
    }

    override func updateLayer() {
        super.updateLayer()
        let focused = window?.isKeyWindow == true
        borderLayer.borderColor = focused
            ? NSColor.controlAccentColor.withAlphaComponent(0.55).cgColor
            : NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    }

    func setFocused(_ focused: Bool) {
        needsDisplay = true
        layer?.borderWidth = 0
        borderLayer.borderColor = focused
            ? NSColor.controlAccentColor.withAlphaComponent(0.55).cgColor
            : NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    }
}
