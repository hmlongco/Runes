//
//  StandardToast.swift
//  Runes
//
//  Created by Michael Long on 12/1/25.
//

import SwiftUI

@available(macOS, unavailable)
public struct Toast: ToastViews {

    public static var defaultBackgroundColor: Color = .blue
    public static var defaultForegroundColor: Color = .white

    private let message: String
    private let icon: String?
    private let foreground: Color
    private let background: Color

    public init(_ message: String, icon: String? = nil, foreground: Color? = nil, background: Color? = nil) {
        self.message = message
        self.icon = icon
        self.foreground = foreground ?? Self.defaultForegroundColor
        self.background = background ?? Self.defaultBackgroundColor
    }

    public init(error: Error, icon: String? = "exclamationmark.triangle.fill", foreground: Color = .white, background: Color = .red) {
        self.message = error.localizedDescription
        self.icon = icon
        self.foreground = foreground
        self.background = background
    }

    public init(error: String, icon: String? = "exclamationmark.triangle.fill", foreground: Color = .white, background: Color = .red) {
        self.message = error
        self.icon = icon
        self.foreground = foreground
        self.background = background
    }

    public var body: some View {
        HStack(alignment: .top) {
            if let icon {
                Image(systemName: icon)
            }
            Text(message)
                .font(.body.bold())
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(16)
        .foregroundStyle(foreground)
        .background(background)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}
