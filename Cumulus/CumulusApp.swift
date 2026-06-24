import SwiftUI
import Combine

enum AppModelHolder {
    @MainActor static weak var model: AppModel?
}

@MainActor
final class AppModel: ObservableObject {
    let settings = OverlaySettings()
    let controller: OverlayController
    let hotKeyManager: HotKeyManager
    private var statusBar: StatusBarController?
    private let controlPanel = ControlPanelController()
    private var cancellables = Set<AnyCancellable>()

    init() {
        controller = OverlayController(settings: settings)
        hotKeyManager = HotKeyManager { [weak controller] in
            Task { @MainActor in
                controller?.toggleOverlay()
            }
        }

        controller.onVisibilityChanged = { [weak self] in
            self?.objectWillChange.send()
            self?.statusBar?.refreshMenu()
        }

        controller.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        AppModelHolder.model = self

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            setupUI()
        }
    }

    func setupUI() {
        NSApp.setActivationPolicy(.regular)
        statusBar = StatusBarController(appModel: self)
        controlPanel.show(appModel: self)
        hotKeyManager.register()

        Task { @MainActor in
            do {
                try await LoopbackWebServer.shared.start()
            } catch {
                DebugLog.write("Loopback server pre-start failed: \(error.localizedDescription)")
            }
            controller.restoreLastVideoIfNeeded()
        }
    }

    func showControlPanel() {
        controlPanel.show(appModel: self)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct CumulusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        Settings {
            SettingsView(settings: appModel.settings, controller: appModel.controller)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            AppModelHolder.model?.showControlPanel()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            AppModelHolder.model?.controller.persistFrame()
            AppModelHolder.model?.hotKeyManager.unregister()
        }
    }
}
