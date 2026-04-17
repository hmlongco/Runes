//
//  UIColor+Extensions.swift
//  Runes
//
//  Created by Michael Long on 4/11/26.
//

import UIKit

extension UIColor {
    public convenience init(_ hexString: String, alpha: CGFloat = 1.0) {
        let hex = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        let color = UInt64(hex, radix: 16) ?? 0
        
        let r = Int(color >> 16) & 0xFF
        let g = Int(color >> 8) & 0xFF
        let b = Int(color) & 0xFF
        
        let red = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue = CGFloat(b) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
