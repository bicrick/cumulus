import SwiftUI

enum CumulusTheme {
    static let accent = Color(red: 0.24, green: 0.35, blue: 0.50)
    static let accentMuted = Color(red: 0.24, green: 0.35, blue: 0.50).opacity(0.15)
    static let cornerRadius: CGFloat = 10
    static let popoverWidth: CGFloat = 300
    static let popoverPadding: CGFloat = 16
}

struct CumulusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(CumulusTheme.accent.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CumulusSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.05))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct CumulusCloudMark: View {
    var color: Color = CumulusTheme.accent

    var body: some View {
        Image("MenuBarIcon")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(color)
    }
}
