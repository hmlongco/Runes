//
//  Color+luminance.swift
//  Runes
//
//  Created by Michael Long on 11/7/24.
//

import SwiftUI

extension Color {
    public init(hex: String, opacity: Double = 1.0) {
        let hex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        let value = UInt64(hex, radix: 16) ?? 0

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value         & 0xFF) / 255

        self.init(red: r, green: g, blue: b, opacity: opacity)
    }

    public func luminance() -> Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }
}

extension Color {
    public func isLight() -> Bool {
        return luminance() > 0.5
    }
}

extension Color {
    /// Function returns black if background color is light, or white if background color is dark.
    /// ```swift
    ///    Text(team.name)
    ///        .font(.largeTitle)
    ///        .background(team.color)
    ///        .foregroundStyle(team.color.adaptedTextColor())
    /// ```
    public func adaptiveTextColor() -> Color {
        return isLight() ? Color.black : Color.white
    }
}
