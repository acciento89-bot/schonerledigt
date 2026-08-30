import SwiftUI

enum Brand {
    static let ink = Color(hex: "151821")
    static let secondaryInk = Color(hex: "68707F")
    static let background = Color(hex: "F4F5F8")
    static let card = Color.white
    static let primary = Color(hex: "6C63FF")
    static let success = Color(hex: "28BFA3")
    static let border = Color(hex: "E5E7EC")
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let red, green, blue: UInt64
        if clean.count == 6 {
            red = value >> 16
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        } else {
            red = 108; green = 99; blue = 255
        }
        self.init(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: 1)
    }
}

extension Date {
    var relativeCompletionText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

