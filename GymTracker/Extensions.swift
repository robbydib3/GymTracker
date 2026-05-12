import SwiftUI
import UIKit

// MARK: - UIColor hex helper

private extension UIColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - App color palette

extension Color {
    // Backgrounds
    static let appBackground   = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "0f0f0f") : UIColor(hex: "f5f5f5") })
    static let cardBackground  = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "1a1a1a") : UIColor(hex: "ffffff") })
    static let inputBackground = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "2a2a2a") : UIColor(hex: "ebebeb") })
    static let rowBackground   = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "222222") : UIColor(hex: "f0f0f0") })

    // Borders
    static let cardBorder      = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "2a2a2a") : UIColor(hex: "dddddd") })
    static let inputBorder     = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "3a3a3a") : UIColor(hex: "cccccc") })

    // Text
    static let textPrimary     = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "f5f5f5") : UIColor(hex: "111111") })
    static let textSecondary   = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "a0a0a0") : UIColor(hex: "555555") })
    static let textMuted       = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "666666") : UIColor(hex: "888888") })

    // Accent (same in both modes)
    static let gymOrange       = Color(hex: "f97316")
    static let gymOrangeLight  = Color(hex: "fb923c")

    // Semantic
    static let completedGreen  = Color(hex: "22c55e")
    static let completedBg     = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "0d2218") : UIColor(hex: "e8f5ee") })
    static let completedInput  = Color(uiColor: UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(hex: "1f2f1f") : UIColor(hex: "d4edd9") })
    static let destructiveRed  = Color(hex: "ef4444")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Formatting helpers

enum Fmt {
    /// Seconds → "1:30" or "45s"
    static func duration(_ totalSeconds: Int) -> String {
        let abs = Swift.abs(totalSeconds)
        let m   = abs / 60
        let s   = abs % 60
        let sign = totalSeconds < 0 ? "-" : ""
        if m > 0 {
            return "\(sign)\(m):\(String(format: "%02d", s))"
        }
        return "\(sign)\(s)s"
    }

    /// Milliseconds → "1h 5m" or "45m"
    static func workoutDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let h = m / 60
        if h > 0 { return "\(h)h \(m % 60)m" }
        return "\(m)m"
    }

    /// ISO date string → "Mon, May 3"
    static func date(_ iso: Date) -> String {
        iso.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - View modifiers

struct CardStyle: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(highlighted ? Color.completedBg : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(highlighted ? Color.completedGreen.opacity(0.2) : Color.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(highlighted: Bool = false) -> some View {
        modifier(CardStyle(highlighted: highlighted))
    }
}

// MARK: - Labeled input field

struct GymTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField(placeholder, text: $text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.inputBorder, lineWidth: 1)
                )
                .foregroundStyle(Color.textPrimary)
        }
    }
}

// MARK: - Number input cell (compact, for set rows)

struct NumberCell: View {
    let placeholder: String
    @Binding var value: Double
    let step: Double
    var disabled: Bool = false

    var body: some View {
        TextField(placeholder, value: $value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .padding(.vertical, 6)
            .background(disabled ? Color.completedInput : Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.inputBorder, lineWidth: 1)
            )
            .foregroundStyle(disabled ? Color.completedGreen : Color.textPrimary)
            .disabled(disabled)
    }
}

// MARK: - Category chip

struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.gymOrange : Color.inputBackground)
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .clipShape(Capsule())
        }
    }
}
