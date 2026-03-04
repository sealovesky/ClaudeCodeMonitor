import Foundation

enum TokenFormatter {
    static func format(_ value: Int) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000_000 {
            let billions = Double(value) / 1_000_000_000
            return String(format: "%.1fB", billions)
        } else if absValue >= 1_000_000 {
            let millions = Double(value) / 1_000_000
            return String(format: "%.1fM", millions)
        } else if absValue >= 1_000 {
            let thousands = Double(value) / 1_000
            return String(format: "%.1fK", thousands)
        }
        return "\(value)"
    }

    static func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
