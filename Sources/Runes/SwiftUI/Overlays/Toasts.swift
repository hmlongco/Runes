//
//  Toasts.swift
//  Runes
//
//  Created by Michael Long on 11/30/25.
//

import SwiftUI

@available(macOS, unavailable)
public protocol ToastViews: Hashable, Equatable, View {}

@available(macOS, unavailable)
public protocol Toasts {
    @MainActor func show(duration: TimeInterval, @ViewBuilder content: () -> some View)
    @MainActor func show(duration: TimeInterval, _ view: some ToastViews)
    @MainActor func dismiss()
}

@available(macOS, unavailable)
extension Toasts {
    @MainActor public func show(@ViewBuilder content: () -> some View) {
        show(duration: 2.0, content: content)
    }
    @MainActor public func show(_ view: some ToastViews) {
        show(duration: 2.0, view)
    }
    @MainActor public func show(message: String, icon: String? = nil, foreground: Color? = nil, background: Color? = nil) {
        show { StandardTextToast(message: message, icon: icon, foreground: foreground, background: background) }
    }
    @MainActor public func show(error: Error) {
        show(duration: 3.0) { StandardTextToast(error: error, icon: "exclamationmark.triangle.fill", foreground: .white, background: .red) }
    }
    @MainActor public func show(error: String) {
        show(duration: 3.0) { StandardTextToast(error: error, icon: "exclamationmark.triangle.fill", foreground: .white, background: .red) }
    }
}

@available(macOS, unavailable)
extension EnvironmentValues {
    @Entry public var toasts: Toasts = Overlays.shared
}

@available(macOS, unavailable)
extension View {
    public func showToast<V: ToastViews>(_ view: Binding<V?>, duration: TimeInterval = 2.0) -> some View {
        self.modifier(ShowToastBindingModifier(view: view, duration: duration))
    }
}

@available(macOS, unavailable)
private struct ShowToastBindingModifier<V: ToastViews>: ViewModifier {
    var view: Binding<V?>
    var duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .onChange(of: view.wrappedValue) {
                if let view = view.wrappedValue {
                    let configuration: Overlays.Configuration = .init(id: UUID(), duration: duration, content: AnyView(view)) 
                    Overlays.shared.show(.toast(configuration))
                    self.view.wrappedValue = nil
                }
            }
    }
}

@available(macOS, unavailable)
public struct StandardTextToast: View {

    public static var defaultBackgroundColor: Color = .blue
    public static var defaultForegroundColor: Color = .white

    private let message: String
    private let icon: String?
    private let foreground: Color
    private let background: Color

    public init(message: String, icon: String? = nil, foreground: Color? = nil, background: Color? = nil) {
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
