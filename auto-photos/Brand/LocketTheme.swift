import SwiftUI

enum LocketTheme {
    enum hex {
        static let background = 0xFFF8F7
        static let accent = 0xFF7597
        static let ink = 0x23191A
        static let inkSoft = 0x534344
        static let surface = 0xFFF0F1
        static let border = 0xF4E4E6
        static let roseBorder = 0xDDBFC3
    }

    static let background = Color(hex: hex.background)
    static let accent = Color(hex: hex.accent)
    static let ink = Color(hex: hex.ink)
    static let inkSoft = Color(hex: hex.inkSoft)
    static let surface = Color(hex: hex.surface)
    static let border = Color(hex: hex.border)
    static let roseBorder = Color(hex: hex.roseBorder)
    static let card = Color.white
    static let shadow = Color.black.opacity(0.10)

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 8
    static let previewRadius: CGFloat = 32

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
