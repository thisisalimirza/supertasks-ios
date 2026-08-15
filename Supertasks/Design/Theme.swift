import SwiftUI

enum AppTheme: String, CaseIterable, Hashable {
    case dark
    case light
}

/// Exact port of the `--c-*` custom properties in the Mac app's global.css.
/// Kept as an explicit in-app toggle (not tied to system appearance), same as the Mac app.
struct ThemeColors {
    // Backgrounds
    let bg: Color
    let panel: Color
    let surface: Color
    let elevated: Color
    let hover: Color
    let sel: Color
    let creator: Color
    let btn: Color
    let btnHover: Color
    let cmdRow: Color

    // Borders
    let b0: Color
    let b1: Color
    let b2: Color
    let b3: Color

    // Text
    let t1: Color
    let t2: Color
    let t3: Color
    let t4: Color
    let t5: Color
    let t6: Color
    let t7: Color
    let t8: Color

    // Semantic
    let accent: Color
    let success: Color
    let warn: Color
    let danger: Color

    static let dark = ThemeColors(
        bg: Color(hex: 0x0A0A0A), panel: Color(hex: 0x0D0D0D), surface: Color(hex: 0x111111),
        elevated: Color(hex: 0x161616), hover: Color(hex: 0x0F0F0F), sel: Color(hex: 0x161620),
        creator: Color(hex: 0x0E0E16), btn: Color(hex: 0x1A1A1A), btnHover: Color(hex: 0x222222),
        cmdRow: Color(hex: 0x141414),
        b0: Color(hex: 0x111111), b1: Color(hex: 0x1A1A1A), b2: Color(hex: 0x1F1F1F), b3: Color(hex: 0x2A2A2A),
        t1: Color(hex: 0xF5F5F5), t2: Color(hex: 0xE0E0E0), t3: Color(hex: 0xC0C0C0), t4: Color(hex: 0x888888),
        t5: Color(hex: 0x666666), t6: Color(hex: 0x555555), t7: Color(hex: 0x444444), t8: Color(hex: 0x333333),
        accent: Color(hex: 0x5B6AFF), success: Color(hex: 0x1DB954), warn: Color(hex: 0xFFB800), danger: Color(hex: 0xFF4444)
    )

    static let light = ThemeColors(
        bg: Color(hex: 0xFAFAF8), panel: Color(hex: 0xF5F5F3), surface: Color(hex: 0xEFEFED),
        elevated: Color(hex: 0xE8E8E6), hover: Color(hex: 0xF2F2F0), sel: Color(hex: 0xECEEFF),
        creator: Color(hex: 0xF0F1FF), btn: Color(hex: 0xE5E5E3), btnHover: Color(hex: 0xDADADD),
        cmdRow: Color(hex: 0xF2F2F0),
        b0: Color(hex: 0xEBEBEB), b1: Color(hex: 0xE5E5E5), b2: Color(hex: 0xDADADD), b3: Color(hex: 0xCCCCCC),
        t1: Color(hex: 0x1A1A1A), t2: Color(hex: 0x2A2A2A), t3: Color(hex: 0x3D3D3D), t4: Color(hex: 0x666666),
        t5: Color(hex: 0x777777), t6: Color(hex: 0x888888), t7: Color(hex: 0x999999), t8: Color(hex: 0xAAAAAA),
        accent: Color(hex: 0x5B6AFF), success: Color(hex: 0x18A048), warn: Color(hex: 0xC08000), danger: Color(hex: 0xD93333)
    )

    static func resolve(_ theme: AppTheme) -> ThemeColors {
        theme == .dark ? .dark : .light
    }

    /// Colors used for the priority pill/dot in the detail header. Matches TaskDetail.tsx's
    /// PRIORITY_COLORS (the `none` case uses the theme's `t6` faint text color).
    func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .none: return t6
        case .low: return Color(hex: 0x5B6AFF)
        case .medium: return Color(hex: 0xC4920A)
        case .high: return Color(hex: 0xFF8C00)
        case .urgent: return Color(hex: 0xFF4444)
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Parses a "#RRGGBB" string (as stored on Project.color); falls back to gray on failure.
    init(hexString: String) {
        var s = hexString
        if s.hasPrefix("#") { s.removeFirst() }
        guard let value = UInt32(s, radix: 16) else {
            self = .gray
            return
        }
        self.init(hex: value)
    }
}

/// The rotating palette used to assign a color to projects that don't have an explicit
/// one set. Order matches PROJECT_COLORS in taskStore.ts exactly.
let projectColorPalette: [String] = [
    "#5E81F4", // indigo
    "#E9507E", // rose
    "#44BBA4", // teal
    "#F5A623", // amber
    "#8B5CF6", // violet
    "#3ABFF8", // sky
    "#F97316", // orange
    "#22C55E", // green
    "#EC4899", // pink
    "#06B6D4", // cyan
]
