import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onSingleTap: () -> Void
    private let onDoubleTap: () -> Void

    private var lastPressTime: Date?
    private var pendingSingleTapTask: Task<Void, Never>?
    private let doubleTapWindow: TimeInterval = 0.3

    init(onSingleTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void) {
        self.onSingleTap = onSingleTap
        self.onDoubleTap = onDoubleTap
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.handleHotKeyPress()
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4355_4D4C), id: 1) // "CUML"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Y),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        pendingSingleTapTask?.cancel()
        pendingSingleTapTask = nil
        lastPressTime = nil

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func handleHotKeyPress() {
        let now = Date()

        if let last = lastPressTime, now.timeIntervalSince(last) < doubleTapWindow {
            pendingSingleTapTask?.cancel()
            pendingSingleTapTask = nil
            lastPressTime = nil
            onDoubleTap()
            return
        }

        lastPressTime = now
        pendingSingleTapTask?.cancel()
        pendingSingleTapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(doubleTapWindow * 1_000_000_000))
            guard !Task.isCancelled, lastPressTime != nil else { return }
            lastPressTime = nil
            onSingleTap()
        }
    }
}
