import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: OverlaySettings
    @ObservedObject var controller: OverlayController

    var body: some View {
        Form {
            Section("Opacity") {
                opacitySlider(title: "Resting", value: $settings.restingOpacity, range: 0.1...1.0)
                opacitySlider(title: "Hover", value: $settings.hoverOpacity, range: 0.05...1.0)
                opacitySlider(title: "Interactive", value: $settings.interactiveOpacity, range: 0.3...1.0)

                VStack(alignment: .leading) {
                    Text("Transition: \(Int(settings.transitionMs)) ms")
                    Slider(value: $settings.transitionMs, in: 0...500, step: 10)
                }
            }

            Section("Interaction") {
                Picker("Interactive modifier", selection: $settings.interactiveModifier) {
                    ForEach(InteractiveModifier.allCases) { modifier in
                        Text(modifier.label).tag(modifier)
                    }
                }

                Toggle("Click-through when passive/hover", isOn: $settings.clickThroughWhenPassive)
                Toggle("Start muted", isOn: $settings.autoplayMuted)
            }

            Section("Video") {
                TextField("YouTube URL", text: $settings.lastVideoURL)
                Button("Load URL") {
                    controller.loadVideo(from: settings.lastVideoURL)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 420)
        .onChange(of: settings.restingOpacity) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.hoverOpacity) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.interactiveOpacity) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.transitionMs) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.interactiveModifier) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.clickThroughWhenPassive) { _, _ in controller.handleSettingsChanged() }
        .onChange(of: settings.autoplayMuted) { _, _ in controller.handleSettingsChanged() }
    }

    private func opacitySlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(Int(value.wrappedValue * 100))%")
            Slider(value: value, in: range, step: 0.05)
        }
    }
}
