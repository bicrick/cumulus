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
    private var cancellables = Set<AnyCancellable>()

    init() {
        controller = OverlayController(settings: settings)
        hotKeyManager = HotKeyManager(
            onVideoSingleTap: { [weak controller] in
                controller?.toggleOverlay()
            },
            onVideoDoubleTap: {
                Task { @MainActor in
                    AppModelHolder.model?.openQuickInput()
                }
            },
            onShortsToggle: {
                Task { @MainActor in
                    AppModelHolder.model?.toggleShortsFeed()
                }
            }
        )

        controller.onVisibilityChanged = { [weak self] in
            self?.objectWillChange.send()
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

    func showControlPopover() {
        statusBar?.showPopover()
        NSApp.activate(ignoringOtherApps: true)
    }

    func openSettings() {
        statusBar?.openSettings()
    }

    func toggleShortsFeed() {
        NSApp.activate(ignoringOtherApps: true)
        controller.toggleShortsFeed()
    }

    func openQuickInput() {
        NSApp.activate(ignoringOtherApps: true)

        if QuickInputWindowController.shared.isVisible {
            QuickInputWindowController.shared.close()
            return
        }

        if let clipboard = NSPasteboard.general.string(forType: .string),
           YouTubeURLParser.videoID(from: clipboard) != nil {
            controller.loadVideo(from: clipboard)
            return
        }

        QuickInputWindowController.shared.open(controller: controller)
    }
}

@main
struct CumulusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApp.windows where window.canBecomeMain {
            window.orderOut(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            AppModelHolder.model?.showControlPopover()
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
