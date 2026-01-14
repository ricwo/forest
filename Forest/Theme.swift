import SwiftUI

// MARK: - Colors (Light, Minimal, Friendly)

extension Color {
    // Backgrounds - warm whites
    static let bg = Color(hex: "FAFAFA")
    static let bgElevated = Color.white
    static let bgHover = Color(hex: "F5F5F5")
    static let bgSelected = Color(hex: "EFEFEF")

    // Borders - soft grays
    static let border = Color.black.opacity(0.08)
    static let borderSubtle = Color.black.opacity(0.05)

    // Text hierarchy - warm grays
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "666666")
    static let textTertiary = Color(hex: "999999")
    static let textMuted = Color(hex: "CCCCCC")

    // Accent - friendly teal
    static let accent = Color(hex: "0D9488")
    static let accentLight = Color(hex: "0D9488").opacity(0.1)

    // Semantic
    static let destructive = Color(hex: "DC2626")
    static let destructiveLight = Color(hex: "DC2626").opacity(0.08)
    static let warning = Color(hex: "D97706")

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
    static let displayLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let displayMedium = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let bodyRegular = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .default)
    static let mono = Font.system(size: 12, weight: .regular, design: .monospaced)
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
}

// MARK: - Button Styles

struct SubtleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .foregroundColor(isEnabled ? .textPrimary : .textTertiary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(configuration.isPressed ? Color.bgSelected : Color.bgHover)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
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
            .background(isEnabled ? (configuration.isPressed ? Color.accent.opacity(0.85) : Color.accent) : Color.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .foregroundColor(.destructive)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(configuration.isPressed ? Color.destructiveLight.opacity(1.5) : Color.destructiveLight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 28

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .frame(width: size, height: size)
                .background(isHovering ? Color.bgHover : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(.textTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.bgHover)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 1)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(.textTertiary)
            .tracking(0.8)
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
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isFocused ? Color.accent.opacity(0.5) : Color.border, lineWidth: 1)
            )
            .focused($isFocused)
    }
}

// MARK: - Divider

struct SubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.border)
            .frame(height: 1)
    }
}
