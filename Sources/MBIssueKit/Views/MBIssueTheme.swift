#if canImport(UIKit)
import SwiftUI
import UIKit

enum MBIssueTheme {
    static let accent = Color(red: 0.96, green: 0.58, blue: 0.08)
    static let accentPressed = Color(red: 0.82, green: 0.42, blue: 0.03)
    static let success = Color(red: 0.20, green: 0.78, blue: 0.51)
    static let failure = Color(red: 0.96, green: 0.38, blue: 0.48)
    static let pending = Color(red: 0.38, green: 0.62, blue: 0.96)

    static let background = adaptive(
        light: UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1),
        dark: UIColor(red: 0.045, green: 0.042, blue: 0.038, alpha: 1)
    )
    static let surface = adaptive(
        light: UIColor(red: 1, green: 0.995, blue: 0.985, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.083, blue: 0.075, alpha: 1)
    )
    static let elevatedSurface = adaptive(
        light: UIColor(red: 0.93, green: 0.91, blue: 0.88, alpha: 1),
        dark: UIColor(red: 0.125, green: 0.11, blue: 0.095, alpha: 1)
    )
    static let primaryText = adaptive(light: .black, dark: .white)
    static let secondaryText = adaptive(
        light: UIColor.black.withAlphaComponent(0.62),
        dark: UIColor.white.withAlphaComponent(0.62)
    )
    static let tertiaryText = adaptive(
        light: UIColor.black.withAlphaComponent(0.42),
        dark: UIColor.white.withAlphaComponent(0.42)
    )
    static let border = adaptive(
        light: UIColor(red: 0.57, green: 0.37, blue: 0.15, alpha: 0.18),
        dark: UIColor(red: 0.98, green: 0.58, blue: 0.12, alpha: 0.16)
    )

    static let cardRadius: CGFloat = 18

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct MBIssueCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(MBIssueTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: MBIssueTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MBIssueTheme.cardRadius, style: .continuous)
                    .stroke(MBIssueTheme.border, lineWidth: 1)
            }
    }
}
#endif
