import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private weak var appModel: AppModel?
    private var showHideItem: NSMenuItem?

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        statusItem.menu = buildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.image = nil
        button.title = "Cumulus"
        button.imagePosition = .noImage
    }

    func refreshMenu() {
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let pasteItem = NSMenuItem(
            title: "Paste URL & Open",
            action: #selector(pasteURL),
            keyEquivalent: "v"
        )
        pasteItem.keyEquivalentModifierMask = [.command, .shift]
        pasteItem.target = self
        menu.addItem(pasteItem)

        let visible = appModel?.controller.isVisible ?? false
        let showHide = NSMenuItem(
            title: visible ? "Hide Overlay" : "Show Overlay",
            action: #selector(toggleOverlay),
            keyEquivalent: ""
        )
        showHide.target = self
        showHideItem = showHide
        menu.addItem(showHide)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let closeItem = NSMenuItem(
            title: "Close Overlay",
            action: #selector(closeOverlay),
            keyEquivalent: ""
        )
        closeItem.target = self
        menu.addItem(closeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Cumulus",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func pasteURL() {
        appModel?.controller.pasteFromClipboard()
        refreshMenu()
    }

    @objc private func toggleOverlay() {
        appModel?.controller.toggleOverlay()
        refreshMenu()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeOverlay() {
        appModel?.controller.closeOverlay()
        refreshMenu()
    }

    @objc private func quit() {
        appModel?.controller.persistFrame()
        NSApplication.shared.terminate(nil)
    }
}
