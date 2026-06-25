import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: OverlaySettings
    @ObservedObject var controller: OverlayController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsHeader
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    opacityRow(title: "Resting", value: $settings.restingOpacity, range: 0.1...1.0)
                    opacityRow(title: "Hover", value: $settings.hoverOpacity, range: 0.05...1.0)
                    opacityRow(title: "Interactive", value: $settings.interactiveOpacity, range: 0.3...1.0)

                    HStack {
                        Text("Transition")
                        Spacer()
                        Text("\(Int(settings.transitionMs)) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.transitionMs, in: 0...500, step: 10)
                } header: {
                    Text("Opacity")
                }

                Section {
                    Picker("Interactive modifier", selection: $settings.interactiveModifier) {
                        ForEach(InteractiveModifier.allCases) { modifier in
                            Text(modifier.label).tag(modifier)
                        }
                    }

                    Toggle("Click-through when passive/hover", isOn: $settings.clickThroughWhenPassive)
                    Toggle("Start muted", isOn: $settings.autoplayMuted)
                } header: {
                    Text("Interaction")
                } footer: {
                    Text("Hold the modifier key while hovering to interact with YouTube controls.")
                        .font(.system(size: 11))
                }

                Section {
                    Toggle("Enable snap", isOn: $settings.snapEnabled)

                    snapAnchorGrid

                    HStack {
                        Text("Edge margin")
                        Spacer()
                        Text("\(Int(settings.snapEdgeMargin)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.snapEdgeMargin, in: 8...48, step: 2)

                    HStack {
                        Text("Snap distance")
                        Spacer()
                        Text("\(Int(settings.snapThreshold)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.snapThreshold, in: 40...160, step: 5)

                    HStack {
                        Text("Snap animation")
                        Spacer()
                        Text("\(Int(settings.snapAnimationMs)) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.snapAnimationMs, in: 80...400, step: 10)
                } header: {
                    Text("Positioning")
                } footer: {
                    Text("Hold Shift and drag the top handle to reposition. Release near a snap zone to settle.")
                        .font(.system(size: 11))
                }

                Section {
                    Button("Load URL") {
                        controller.loadVideo(from: settings.lastVideoURL)
                    }
                } header: {
                    Text("Video")
                } footer: {
                    Text("Paste a watch or youtu.be link, then load or use Paste URL from the menu bar.")
                        .font(.system(size: 11))
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 440, minHeight: 560)
        .onChange(of: settings.restingOpacity) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.hoverOpacity) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.interactiveOpacity) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.transitionMs) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.interactiveModifier) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.clickThroughWhenPassive) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.autoplayMuted) { _, _ in
            controller.handleSettingsChanged()
            controller.reloadVideo()
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 10) {
            CumulusCloudMark()
                .frame(width: 24, height: 24)
            Text("Cumulus Settings")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
        }
    }

    private func opacityRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: 0.05)
        }
    }

    private var snapAnchorGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SnapAnchor.allCases) { anchor in
                Toggle(isOn: snapBinding(for: anchor)) {
                    Text(shortLabel(for: anchor))
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private func snapBinding(for anchor: SnapAnchor) -> Binding<Bool> {
        Binding(
            get: { settings.enabledSnapAnchors.contains(anchor) },
            set: { enabled in
                if enabled {
                    settings.enabledSnapAnchors.insert(anchor)
                } else {
                    settings.enabledSnapAnchors.remove(anchor)
                }
            }
        )
    }

    private func shortLabel(for anchor: SnapAnchor) -> String {
        switch anchor {
        case .topLeft: return "TL"
        case .topCenter: return "TC"
        case .topRight: return "TR"
        case .centerLeft: return "CL"
        case .center: return "C"
        case .centerRight: return "CR"
        case .bottomLeft: return "BL"
        case .bottomCenter: return "BC"
        case .bottomRight: return "BR"
        }
    }
}
