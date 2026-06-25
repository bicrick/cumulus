import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    private enum HotKeyID: UInt32 {
        case video = 1
        case shorts = 2
    }

    private var videoHotKeyRef: EventHotKeyRef?
    private var shortsHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private let onVideoSingleTap: () -> Void
    private let onVideoDoubleTap: () -> Void
    private let onShortsToggle: () -> Void

    private var lastVideoPressTime: Date?
    private var pendingVideoSingleTapTask: Task<Void, Never>?
    private let doubleTapWindow: TimeInterval = 0.3

    init(
        onVideoSingleTap: @escaping () -> Void,
        onVideoDoubleTap: @escaping () -> Void,
        onShortsToggle: @escaping () -> Void
    ) {
        self.onVideoSingleTap = onVideoSingleTap
        self.onVideoDoubleTap = onVideoDoubleTap
        self.onShortsToggle = onShortsToggle
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }

            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.handleHotKeyPress(id: hotKeyID.id)
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, &eventHandler)

        let videoHotKeyID = EventHotKeyID(signature: OSType(0x4355_4D4C), id: HotKeyID.video.rawValue)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Y),
            UInt32(cmdKey | shiftKey),
            videoHotKeyID,
            GetApplicationEventTarget(),
            0,
            &videoHotKeyRef
        )

        let shortsHotKeyID = EventHotKeyID(signature: OSType(0x4355_4D4C), id: HotKeyID.shorts.rawValue)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(cmdKey | shiftKey),
            shortsHotKeyID,
            GetApplicationEventTarget(),
            0,
            &shortsHotKeyRef
        )
    }

    func unregister() {
        pendingVideoSingleTapTask?.cancel()
        pendingVideoSingleTapTask = nil
        lastVideoPressTime = nil

        if let videoHotKeyRef {
            UnregisterEventHotKey(videoHotKeyRef)
            self.videoHotKeyRef = nil
        }
        if let shortsHotKeyRef {
            UnregisterEventHotKey(shortsHotKeyRef)
            self.shortsHotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func handleHotKeyPress(id: UInt32) {
        switch HotKeyID(rawValue: id) {
        case .video:
            handleVideoHotKeyPress()
        case .shorts:
            onShortsToggle()
        case .none:
            break
        }
    }

    private func handleVideoHotKeyPress() {
        let now = Date()

        if let last = lastVideoPressTime, now.timeIntervalSince(last) < doubleTapWindow {
            pendingVideoSingleTapTask?.cancel()
            pendingVideoSingleTapTask = nil
            lastVideoPressTime = nil
            onVideoDoubleTap()
            return
        }

        lastVideoPressTime = now
        pendingVideoSingleTapTask?.cancel()
        pendingVideoSingleTapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(doubleTapWindow * 1_000_000_000))
            guard !Task.isCancelled, lastVideoPressTime != nil else { return }
            lastVideoPressTime = nil
            onVideoSingleTap()
        }
    }
}
