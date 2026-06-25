import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var controller: OverlayController
    @ObservedObject var settings: OverlaySettings

    private var isInteractive: Bool {
        controller.interactionMode == .interactive
    }

    var body: some View {
        Group {
            if isInteractive {
                interactiveLayout
            } else {
                passiveLayout
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Passive / hover: video fills the entire window

    private var passiveLayout: some View {
        ZStack {
            Color.black

            videoContent

            errorLayer
        }
    }

    // MARK: - Interactive: external chrome border around video

    private var interactiveLayout: some View {
        ZStack {
            ExternalChromeVisual()

            VStack(spacing: 0) {
                ZStack {
                    Color.clear
                    ChromeDragBar(controller: controller)
                }
                .frame(height: OverlayChromeLayout.topBarHeight)

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: OverlayChromeLayout.sideInset)
                    videoContent
                    Color.clear
                        .frame(width: OverlayChromeLayout.sideInset)
                }

                ZStack {
                    HStack {
                        ChromeResizeCorner(controller: controller, corner: .bottomLeft)
                            .frame(width: OverlayChromeLayout.cornerHandleSize, height: OverlayChromeLayout.bottomBarHeight)
                        Spacer()
                        ChromeResizeCorner(controller: controller, corner: .bottomRight)
                            .frame(width: OverlayChromeLayout.cornerHandleSize, height: OverlayChromeLayout.bottomBarHeight)
                    }
                }
                .frame(height: OverlayChromeLayout.bottomBarHeight)
            }

            errorLayer
        }
    }

    @ViewBuilder
    private var videoContent: some View {
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
    }

    @ViewBuilder
    private var errorLayer: some View {
        if let error = controller.loadError {
            VStack {
                Spacer()
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.red.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(8)
            }
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
}
