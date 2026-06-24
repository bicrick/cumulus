import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var controller: OverlayController
    @ObservedObject var settings: OverlaySettings

    private var isInteractive: Bool {
        controller.interactionMode == .interactive
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.opacity(0.9)

                if let videoID = controller.currentVideoID {
                    YouTubeWebView(
                        videoID: videoID,
                        autoplayMuted: settings.autoplayMuted,
                        generation: controller.playerGeneration,
                        loadError: $controller.loadError
                    )
                } else {
                    placeholder
                }

                if isInteractive {
                    OverlayInteractiveChromeVisual()
                    OverlayInteractiveChrome(controller: controller)
                } else if controller.currentVideoID != nil {
                    VStack {
                        Text("Hold Shift — drag top bar to move, edges/corners to resize")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                }

                if let error = controller.loadError {
                    errorBanner(error)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isInteractive ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.black.opacity(0.6)
            Text("Paste a YouTube URL from the menu bar")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.red.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
        }
    }
}
