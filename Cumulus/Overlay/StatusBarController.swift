import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private weak var appModel: AppModel?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        setupPopover()
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            button.image = image
        }
        button.title = ""
        button.imagePosition = .imageOnly
        button.action = #selector(statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        self.popover = popover
    }

    func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover(relativeTo: button.bounds, of: button)
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        showPopover(relativeTo: button.bounds, of: button)
    }

    func openSettings() {
        guard let appModel else { return }
        closePopover()
        DispatchQueue.main.async { [statusItem] in
            SettingsWindowController.shared.open(appModel: appModel, anchorTo: statusItem)
        }
    }

    private func showPopover(relativeTo rect: NSRect, of view: NSView) {
        guard let appModel, let popover else { return }

        popover.contentViewController = NSHostingController(
            rootView: ControlPopoverView(appModel: appModel)
        )
        popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
        startEventMonitor()
    }

    private func closePopover() {
        popover?.performClose(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, self.popover?.isShown == true else { return }
                if self.isMouseInsidePopover(event) {
                    return
                }
                self.closePopover()
            }
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func isMouseInsidePopover(_ event: NSEvent) -> Bool {
        guard let popoverWindow = popover?.contentViewController?.view.window else { return false }
        return popoverWindow.frame.contains(NSEvent.mouseLocation)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        togglePopover()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let quitItem = NSMenuItem(
            title: "Quit Cumulus",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func quit() {
        appModel?.controller.persistFrame()
        NSApplication.shared.terminate(nil)
    }
}
