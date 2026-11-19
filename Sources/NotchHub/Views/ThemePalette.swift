import NotchHubCore
import SwiftUI

struct NotchThemePalette {
    let theme: NotchTheme
    let accent: Color
    let accentSecondary: Color
    let shellFill: Color
    let cardFill: Color
    let cardBorder: Color
    let shellGlowBorder: Color

    static func palette(for theme: NotchTheme) -> NotchThemePalette {
        switch theme {
        case .obsidian:
            return NotchThemePalette(
                theme: theme,
                accent: Color(red: 0.16, green: 0.85, blue: 0.96),
                accentSecondary: Color(red: 0.25, green: 0.92, blue: 0.56),
                shellFill: Color(red: 0.02, green: 0.02, blue: 0.03),
                cardFill: Color(red: 0.085, green: 0.088, blue: 0.104),
                cardBorder: Color.white.opacity(0.095),
                shellGlowBorder: Color.white.opacity(0.13)
            )
        case .midnight:
            return NotchThemePalette(
                theme: theme,
                accent: Color(red: 0.54, green: 0.56, blue: 1.0),
                accentSecondary: Color(red: 0.72, green: 0.48, blue: 1.0),
                shellFill: Color(red: 0.03, green: 0.035, blue: 0.075),
                cardFill: Color(red: 0.085, green: 0.092, blue: 0.155),
                cardBorder: Color(red: 0.54, green: 0.56, blue: 1.0).opacity(0.18),
                shellGlowBorder: Color(red: 0.54, green: 0.56, blue: 1.0).opacity(0.28)
            )
        case .emerald:
            return NotchThemePalette(
                theme: theme,
                accent: Color(red: 0.20, green: 0.88, blue: 0.56),
                accentSecondary: Color(red: 0.14, green: 0.80, blue: 0.74),
                shellFill: Color(red: 0.02, green: 0.04, blue: 0.03),
                cardFill: Color(red: 0.075, green: 0.11, blue: 0.092),
                cardBorder: Color(red: 0.20, green: 0.88, blue: 0.56).opacity(0.18),
                shellGlowBorder: Color(red: 0.20, green: 0.88, blue: 0.56).opacity(0.28)
            )
        case .sunset:
            return NotchThemePalette(
                theme: theme,
                accent: Color(red: 0.99, green: 0.56, blue: 0.22),
                accentSecondary: Color(red: 0.99, green: 0.74, blue: 0.28),
                shellFill: Color(red: 0.045, green: 0.028, blue: 0.022),
                cardFill: Color(red: 0.12, green: 0.09, blue: 0.075),
                cardBorder: Color(red: 0.99, green: 0.56, blue: 0.22).opacity(0.19),
                shellGlowBorder: Color(red: 0.99, green: 0.56, blue: 0.22).opacity(0.30)
            )
        case .rose:
            return NotchThemePalette(
                theme: theme,
                accent: Color(red: 0.96, green: 0.45, blue: 0.72),
                accentSecondary: Color(red: 0.84, green: 0.46, blue: 0.98),
                shellFill: Color(red: 0.045, green: 0.022, blue: 0.04),
                cardFill: Color(red: 0.12, green: 0.08, blue: 0.11),
                cardBorder: Color(red: 0.96, green: 0.45, blue: 0.72).opacity(0.19),
                shellGlowBorder: Color(red: 0.96, green: 0.45, blue: 0.72).opacity(0.30)
            )
        case .graphite:
            return NotchThemePalette(
                theme: theme,
                accent: Color(red: 0.88, green: 0.90, blue: 0.93),
                accentSecondary: Color(red: 0.68, green: 0.72, blue: 0.78),
                shellFill: Color(red: 0.04, green: 0.04, blue: 0.045),
                cardFill: Color(red: 0.105, green: 0.108, blue: 0.116),
                cardBorder: Color.white.opacity(0.13),
                shellGlowBorder: Color.white.opacity(0.22)
            )
        }
    }
}
