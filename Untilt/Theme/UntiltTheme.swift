import SwiftUI

// MARK: - Untilt Design Tokens
// Single source of truth for all colours, typography, spacing and radii.
// Maps directly to the Figma style guide v1.1.

enum UntiltTheme {

    // MARK: Colors
    enum Color {
        // Brand — Lavender
        static let lavender700   = SwiftUI.Color(hex: "5B4F8A")
        static let lavender500   = SwiftUI.Color(hex: "7C6FAE")
        static let lavender100   = SwiftUI.Color(hex: "F4F2FB")
        static let lavender50    = SwiftUI.Color(hex: "EAE6F7")

        // Brand — Sage
        static let sage700       = SwiftUI.Color(hex: "3D6B5A")
        static let sage500       = SwiftUI.Color(hex: "5C9178")
        static let sage50        = SwiftUI.Color(hex: "E4F0EB")

        // Neutrals
        static let warmWhite     = SwiftUI.Color(hex: "FAF9F6")
        static let warmGray      = SwiftUI.Color(hex: "F0EDE8")
        static let slate         = SwiftUI.Color(hex: "4A4558")
        static let muted         = SwiftUI.Color(hex: "8A8399")
        static let border        = SwiftUI.Color(hex: "D5D0E8")
        static let white         = SwiftUI.Color.white

        // Semantic
        static let error         = SwiftUI.Color(hex: "C0392B")
        static let warning       = SwiftUI.Color(hex: "B7751A")
        static let warningBg     = SwiftUI.Color(hex: "FFF8ED")
        static let warningBorder = SwiftUI.Color(hex: "EDD99A")
    }

    // MARK: Typography
    enum Font {
        static let display     = SwiftUI.Font.system(size: 34, weight: .medium, design: .default)
        static let heading1    = SwiftUI.Font.system(size: 28, weight: .medium, design: .default)
        static let heading2    = SwiftUI.Font.system(size: 22, weight: .medium, design: .default)
        static let heading3    = SwiftUI.Font.system(size: 17, weight: .medium, design: .default)
        static let body        = SwiftUI.Font.system(size: 16, weight: .regular, design: .default)
        static let bodySmall   = SwiftUI.Font.system(size: 14, weight: .regular, design: .default)
        static let caption     = SwiftUI.Font.system(size: 12, weight: .medium, design: .default)
        static let overline    = SwiftUI.Font.system(size: 11, weight: .medium, design: .default)
        static let micro       = SwiftUI.Font.system(size: 10, weight: .medium, design: .default)
    }

    // MARK: Spacing (8pt base grid)
    enum Spacing {
        static let s1: CGFloat  = 4
        static let s2: CGFloat  = 8
        static let s3: CGFloat  = 12
        static let s4: CGFloat  = 16
        static let s5: CGFloat  = 20
        static let s6: CGFloat  = 24
        static let s8: CGFloat  = 32
        static let s10: CGFloat = 40
    }

    // MARK: Border Radius
    enum Radius {
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 16
        static let xl: CGFloat   = 20
        static let xxl: CGFloat  = 24
        static let full: CGFloat = 9999
    }

    // MARK: Sizing
    enum Size {
        static let iconSm: CGFloat          = 16
        static let iconMd: CGFloat          = 20
        static let iconLg: CGFloat          = 24
        static let avatar: CGFloat          = 36
        static let iconContainerSm: CGFloat = 32
        static let iconContainerMd: CGFloat = 36
        static let buttonHeight: CGFloat    = 52
        static let inputHeight: CGFloat     = 52
        static let navBarHeight: CGFloat    = 68
        static let videoCardWidth: CGFloat  = 148
        static let videoThumbHeight: CGFloat = 88
    }
}

// MARK: - Color hex initialiser
extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
