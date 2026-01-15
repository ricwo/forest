import SwiftUI
import AppKit

// MARK: - Adaptive Color Helper

extension Color {
    private static var isDarkMode: Bool {
        SettingsService.shared.isDarkModeActive
    }

    /// Creates an adaptive color that switches between light and dark variants
    static func adaptive(light: String, dark: String) -> Color {
        isDarkMode ? Color(hex: dark) : Color(hex: light)
    }

    /// Creates an adaptive color from two Color values
    static func adaptive(light: Color, dark: Color) -> Color {
        isDarkMode ? dark : light
    }
}

// MARK: - Colors (Organic Minimalism with Dark Mode)

extension Color {
    // Backgrounds - warm cream tints (light) / dark charcoal (dark)
    static var bg: Color { .adaptive(light: "FAF9F7", dark: "1C1C1E") }
    static var bgElevated: Color { .adaptive(light: "FFFFFF", dark: "2C2C2E") }
    static var bgHover: Color { .adaptive(light: "F5F4F1", dark: "3A3A3C") }
    static var bgSelected: Color { .adaptive(light: "EFEEEB", dark: "48484A") }
    static var bgSubtle: Color { .adaptive(light: "F8F7F5", dark: "252527") }

    // Borders - warm with subtle green tint
    static var border: Color { .adaptive(light: "E8E6E1", dark: "3D3D3F") }
    static var borderSubtle: Color { .adaptive(light: "F0EEE9", dark: "323234") }
    static var borderFocus: Color { .adaptive(light: Color(hex: "2D6A4F").opacity(0.3), dark: Color(hex: "52B788").opacity(0.4)) }

    // Text hierarchy - warm charcoal (light) / light tones (dark)
    static var textPrimary: Color { .adaptive(light: "1B1B18", dark: "F5F5F5") }
    static var textSecondary: Color { .adaptive(light: "5C5C52", dark: "A8A8A8") }
    static var textTertiary: Color { .adaptive(light: "8A8A7A", dark: "7A7A7A") }
    static var textMuted: Color { .adaptive(light: "C4C4B8", dark: "5A5A5A") }

    // Accent - forest green (warmer, more organic)
    static var accent: Color { .adaptive(light: "2D6A4F", dark: "52B788") }
    static var accentLight: Color { .adaptive(light: Color(hex: "2D6A4F").opacity(0.08), dark: Color(hex: "52B788").opacity(0.15)) }
    static var accentSoft: Color { .adaptive(light: "D8F3DC", dark: "1B4332") }

    // Secondary accent - warm amber for highlights
    static var accentWarm: Color { .adaptive(light: "B68D40", dark: "D4A855") }
    static var accentWarmLight: Color { .adaptive(light: Color(hex: "B68D40").opacity(0.1), dark: Color(hex: "D4A855").opacity(0.15)) }

    // Semantic
    static var destructive: Color { .adaptive(light: "C1292E", dark: "FF6B6B") }
    static var destructiveLight: Color { .adaptive(light: Color(hex: "C1292E").opacity(0.08), dark: Color(hex: "FF6B6B").opacity(0.15)) }
    static var warning: Color { .adaptive(light: "CC7722", dark: "FFB347") }
    static var success: Color { .adaptive(light: "40916C", dark: "52B788") }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Typography

extension Font {
    // Display fonts - refined and characterful
    static let displayLarge = Font.system(size: 24, weight: .medium, design: .default)
    static let displayMedium = Font.system(size: 18, weight: .medium, design: .default)

    // Headlines
    static let headline = Font.system(size: 14, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 12, weight: .semibold, design: .default)

    // Body
    static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let bodyRegular = Font.system(size: 13, weight: .regular, design: .default)

    // Captions
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .default)

    // Monospace - for code/paths
    static let mono = Font.system(size: 11.5, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 10.5, weight: .regular, design: .monospaced)

    // Special
    static let label = Font.system(size: 10, weight: .semibold, design: .rounded)
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Animation Presets

extension SwiftUI.Animation {
    static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let smooth = SwiftUI.Animation.easeInOut(duration: 0.2)
    static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
    static let gentle = SwiftUI.Animation.easeInOut(duration: 0.35)
}

// MARK: - Shadows

extension View {
    func softShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    func subtleShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Button Styles

struct SubtleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .foregroundColor(isEnabled ? .textPrimary : .textTertiary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.bgSelected : (isHovering ? Color.bgHover : Color.bgSubtle))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.quick, value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

struct AccentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isEnabled ? Color.accent : Color.textMuted)
                    .brightness(configuration.isPressed ? -0.05 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.quick, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var color: Color = .textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .foregroundColor(configuration.isPressed ? color.opacity(0.6) : color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.quick, value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .foregroundColor(.destructive)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.destructiveLight.opacity(1.5) : Color.destructiveLight)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.quick, value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 28

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isHovering ? .accent : .textSecondary)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering ? Color.accentLight : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1)
        .onHover { isHovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.snappy, value: isHovering)
        .animation(.quick, value: isPressed)
    }
}

// MARK: - Keyboard Shortcut Badge

struct ShortcutBadge: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.monoSmall)
            .foregroundColor(.textTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.bgSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 0.5)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.textMuted)
            }

            Text(title.uppercased())
                .font(.label)
                .foregroundColor(.textTertiary)
                .tracking(1.0)
        }
    }
}

// MARK: - Minimal Text Field

struct MinimalTextField: View {
    let placeholder: String
    @Binding var text: String
    var isMonospace: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(isMonospace ? .mono : .bodyRegular)
            .foregroundColor(.textPrimary)
            .textFieldStyle(.plain)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isFocused ? Color.accent.opacity(0.4) : Color.border, lineWidth: isFocused ? 1.5 : 1)
            )
            .focused($isFocused)
            .animation(.quick, value: isFocused)
    }
}

// MARK: - Divider

struct SubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.border.opacity(0.5))
            .frame(height: 1)
    }
}

// MARK: - Card Container

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.bgSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 0.5)
            )
    }
}

// MARK: - Forest Branding

struct ForestBranding: View {
    var body: some View {
        Text("forest")
            .font(.custom("Sacramento", size: 24))
            .foregroundColor(.textSecondary)
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    var style: BadgeStyle = .default

    enum BadgeStyle {
        case `default`, accent, muted
    }

    var body: some View {
        Text(text)
            .font(.label)
            .tracking(0.5)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }

    private var foregroundColor: Color {
        switch style {
        case .default: return .textTertiary
        case .accent: return .accent
        case .muted: return .textMuted
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .default: return .bgHover
        case .accent: return .accentLight
        case .muted: return .bgSubtle
        }
    }
}
