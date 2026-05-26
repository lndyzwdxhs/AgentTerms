import AppKit
import SwiftTerm

/// Terminal color theme definition
struct TerminalThemeColors {
    let foreground: NSColor
    let background: NSColor
    let cursor: NSColor
    let selection: NSColor
    let ansiColors: [NSColor] // 16 ANSI colors

    init(
        foreground: NSColor,
        background: NSColor,
        cursor: NSColor,
        selection: NSColor,
        ansiColors: [NSColor]
    ) {
        assert(ansiColors.count == 16, "Must provide exactly 16 ANSI colors")
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
        self.selection = selection
        self.ansiColors = ansiColors
    }
}

/// Built-in terminal themes
enum TerminalTheme: String, CaseIterable, Codable {
    case kittyLowContrast = "Kitty Low Contrast"
    case system = "System"
    case dracula = "Dracula"
    case oneDark = "One Dark"
    case solarizedDark = "Solarized Dark"
    case solarizedLight = "Solarized Light"
    case nord = "Nord"
    case monokai = "Monokai"

    var colors: TerminalThemeColors {
        switch self {
        case .kittyLowContrast: return Self.kittyLowContrastColors
        case .system: return Self.systemColors
        case .dracula: return Self.draculaColors
        case .oneDark: return Self.oneDarkColors
        case .solarizedDark: return Self.solarizedDarkColors
        case .solarizedLight: return Self.solarizedLightColors
        case .nord: return Self.nordColors
        case .monokai: return Self.monokaiColors
        }
    }

    // MARK: - Theme Definitions

    private static var kittyLowContrastColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: NSColor(hex: 0xFFFFFF),
            background: NSColor(hex: 0x333333),
            cursor: NSColor(hex: 0xCCCCCC),
            selection: NSColor(hex: 0x264F78),
            ansiColors: [
                NSColor(hex: 0x000000), NSColor(hex: 0xCC0403),
                NSColor(hex: 0x19CB00), NSColor(hex: 0xCECB00),
                NSColor(hex: 0x0D73CC), NSColor(hex: 0xCB1ED1),
                NSColor(hex: 0x0DCDCD), NSColor(hex: 0xDDDDDD),
                NSColor(hex: 0x767676), NSColor(hex: 0xF2201F),
                NSColor(hex: 0x23FD00), NSColor(hex: 0xFFFD00),
                NSColor(hex: 0x1A8FFF), NSColor(hex: 0xFD28FF),
                NSColor(hex: 0x14FFFF), NSColor(hex: 0xFFFFFF)
            ]
        )
    }

    private static var systemColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: .textColor,
            background: .textBackgroundColor,
            cursor: .textColor,
            selection: .selectedTextBackgroundColor,
            ansiColors: [
                .black, .systemRed, .systemGreen, .systemYellow,
                .systemBlue, .systemPurple, .systemTeal, .white,
                .darkGray, .systemRed, .systemGreen, .systemYellow,
                .systemBlue, .systemPurple, .systemTeal, .lightGray
            ]
        )
    }

    private static var draculaColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: NSColor(hex: 0xF8F8F2),
            background: NSColor(hex: 0x282A36),
            cursor: NSColor(hex: 0xF8F8F2),
            selection: NSColor(hex: 0x44475A),
            ansiColors: [
                NSColor(hex: 0x21222C), NSColor(hex: 0xFF5555),
                NSColor(hex: 0x50FA7B), NSColor(hex: 0xF1FA8C),
                NSColor(hex: 0xBD93F9), NSColor(hex: 0xFF79C6),
                NSColor(hex: 0x8BE9FD), NSColor(hex: 0xF8F8F2),
                NSColor(hex: 0x6272A4), NSColor(hex: 0xFF6E6E),
                NSColor(hex: 0x69FF94), NSColor(hex: 0xFFFFA5),
                NSColor(hex: 0xD6ACFF), NSColor(hex: 0xFF92DF),
                NSColor(hex: 0xA4FFFF), NSColor(hex: 0xFFFFFF)
            ]
        )
    }

    private static var oneDarkColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: NSColor(hex: 0xABB2BF),
            background: NSColor(hex: 0x282C34),
            cursor: NSColor(hex: 0x528BFF),
            selection: NSColor(hex: 0x3E4451),
            ansiColors: [
                NSColor(hex: 0x282C34), NSColor(hex: 0xE06C75),
                NSColor(hex: 0x98C379), NSColor(hex: 0xE5C07B),
                NSColor(hex: 0x61AFEF), NSColor(hex: 0xC678DD),
                NSColor(hex: 0x56B6C2), NSColor(hex: 0xABB2BF),
                NSColor(hex: 0x545862), NSColor(hex: 0xE06C75),
                NSColor(hex: 0x98C379), NSColor(hex: 0xE5C07B),
                NSColor(hex: 0x61AFEF), NSColor(hex: 0xC678DD),
                NSColor(hex: 0x56B6C2), NSColor(hex: 0xFFFFFF)
            ]
        )
    }

    private static var solarizedDarkColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: NSColor(hex: 0x839496),
            background: NSColor(hex: 0x002B36),
            cursor: NSColor(hex: 0x839496),
            selection: NSColor(hex: 0x073642),
            ansiColors: [
                NSColor(hex: 0x073642), NSColor(hex: 0xDC322F),
                NSColor(hex: 0x859900), NSColor(hex: 0xB58900),
                NSColor(hex: 0x268BD2), NSColor(hex: 0xD33682),
                NSColor(hex: 0x2AA198), NSColor(hex: 0xEEE8D5),
                NSColor(hex: 0x002B36), NSColor(hex: 0xCB4B16),
                NSColor(hex: 0x586E75), NSColor(hex: 0x657B83),
                NSColor(hex: 0x839496), NSColor(hex: 0x6C71C4),
                NSColor(hex: 0x93A1A1), NSColor(hex: 0xFDF6E3)
            ]
        )
    }

    private static var solarizedLightColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: NSColor(hex: 0x657B83),
            background: NSColor(hex: 0xFDF6E3),
            cursor: NSColor(hex: 0x657B83),
            selection: NSColor(hex: 0xEEE8D5),
            ansiColors: [
                NSColor(hex: 0xEEE8D5), NSColor(hex: 0xDC322F),
                NSColor(hex: 0x859900), NSColor(hex: 0xB58900),
                NSColor(hex: 0x268BD2), NSColor(hex: 0xD33682),
                NSColor(hex: 0x2AA198), NSColor(hex: 0x073642),
                NSColor(hex: 0xFDF6E3), NSColor(hex: 0xCB4B16),
                NSColor(hex: 0x93A1A1), NSColor(hex: 0x839496),
                NSColor(hex: 0x657B83), NSColor(hex: 0x6C71C4),
                NSColor(hex: 0x586E75), NSColor(hex: 0x002B36)
            ]
        )
    }

    private static var nordColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: NSColor(hex: 0xD8DEE9),
            background: NSColor(hex: 0x2E3440),
            cursor: NSColor(hex: 0xD8DEE9),
            selection: NSColor(hex: 0x434C5E),
            ansiColors: [
                NSColor(hex: 0x3B4252), NSColor(hex: 0xBF616A),
                NSColor(hex: 0xA3BE8C), NSColor(hex: 0xEBCB8B),
                NSColor(hex: 0x81A1C1), NSColor(hex: 0xB48EAD),
                NSColor(hex: 0x88C0D0), NSColor(hex: 0xE5E9F0),
                NSColor(hex: 0x4C566A), NSColor(hex: 0xBF616A),
                NSColor(hex: 0xA3BE8C), NSColor(hex: 0xEBCB8B),
                NSColor(hex: 0x81A1C1), NSColor(hex: 0xB48EAD),
                NSColor(hex: 0x8FBCBB), NSColor(hex: 0xECEFF4)
            ]
        )
    }

    private static var monokaiColors: TerminalThemeColors {
        TerminalThemeColors(
            foreground: NSColor(hex: 0xF8F8F2),
            background: NSColor(hex: 0x272822),
            cursor: NSColor(hex: 0xF8F8F0),
            selection: NSColor(hex: 0x49483E),
            ansiColors: [
                NSColor(hex: 0x272822), NSColor(hex: 0xF92672),
                NSColor(hex: 0xA6E22E), NSColor(hex: 0xF4BF75),
                NSColor(hex: 0x66D9EF), NSColor(hex: 0xAE81FF),
                NSColor(hex: 0xA1EFE4), NSColor(hex: 0xF8F8F2),
                NSColor(hex: 0x75715E), NSColor(hex: 0xF92672),
                NSColor(hex: 0xA6E22E), NSColor(hex: 0xF4BF75),
                NSColor(hex: 0x66D9EF), NSColor(hex: 0xAE81FF),
                NSColor(hex: 0xA1EFE4), NSColor(hex: 0xF9F8F5)
            ]
        )
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
