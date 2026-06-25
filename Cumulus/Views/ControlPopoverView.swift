import SwiftUI

struct ControlPopoverView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var controller: OverlayController
    @ObservedObject var settings: OverlaySettings

    @State private var urlDraft = ""

    init(appModel: AppModel) {
        self.appModel = appModel
        self.controller = appModel.controller
        self.settings = appModel.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            urlSection
            actionRow
            statusSection
            Divider()
            settingsButton
        }
        .padding(CumulusTheme.popoverPadding)
        .frame(width: CumulusTheme.popoverWidth)
        .background(.regularMaterial)
        .onAppear {
            urlDraft = settings.lastVideoURL
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            CumulusCloudMark()
                .frame(width: 22, height: 22)

            Text("Cumulus")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(controller.isVisible ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(controller.isVisible ? "Live" : "Hidden")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(controller.isVisible ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(CumulusTheme.accentMuted)
        .clipShape(Capsule())
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Paste URL & Open") {
                controller.pasteFromClipboard()
                urlDraft = settings.lastVideoURL
            }
            .buttonStyle(CumulusPrimaryButtonStyle())
            .keyboardShortcut("v", modifiers: [.command, .shift])

            TextField("YouTube URL", text: $urlDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onSubmit {
                    guard !urlDraft.isEmpty else { return }
                    controller.loadVideo(from: urlDraft)
                }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(controller.isVisible ? "Hide" : "Show") {
                controller.toggleOverlay()
            }
            .buttonStyle(CumulusSecondaryButtonStyle())

            Button("Center") {
                controller.centerOverlay()
            }
            .buttonStyle(CumulusSecondaryButtonStyle())

            Button("Reload") {
                controller.reloadVideo()
            }
            .buttonStyle(CumulusSecondaryButtonStyle())
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let videoID = controller.currentVideoID {
                Text("Video: \(videoID)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Video: none loaded")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("Mode: \(modeLabel) · \(opacityPercent)%")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if let error = controller.loadError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var settingsButton: some View {
        Button("Settings…") {
            appModel.openSettings()
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(CumulusTheme.accent)
        .keyboardShortcut(",", modifiers: [.command])
    }

    private var modeLabel: String {
        switch controller.interactionMode {
        case .passive: return "passive"
        case .hover: return "hover"
        case .interactive: return "interactive"
        }
    }

    private var opacityPercent: Int {
        Int(settings.opacity(for: controller.interactionMode) * 100)
    }
}
