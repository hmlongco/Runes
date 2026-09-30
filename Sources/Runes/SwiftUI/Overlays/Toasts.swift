//
//  Toasts.swift
//  Runes
//
//  Created by Michael Long on 11/30/25.
//

import SwiftUI

/// A custom view that can be presented as a toast. This allows for toast configurations and custom views.
///
/// Conform your toast views, typically an enum whose cases carry the content, to present them with
/// `toast(_:)` or the `toast(_:duration:)` binding modifier. The view must be `Hashable` and
/// `Equatable` so that changes to a bound toast value can be detected.
///
/// The following enum defines two toasts, built from the standard `Toast` view:
///
/// ```swift
/// enum MyToasts: ToastViews {
///     case message(String)
///     case error(String)
///
///     var body: some View {
///         switch self {
///         case .message(let message):
///             Toast(message)
///         case .error(let error):
///             Toast(error: error)
///         }
///     }
/// }
/// ```
///
/// Present them by assigning to a bound value, or by calling the `toasts` environment value directly:
///
/// ```swift
/// struct ToastsDemoView: View {
///     @Environment(\.toasts) private var toasts
///     @State private var toast: MyToasts?
///
///     var body: some View {
///         List {
///             Button("Bound message") {
///                 toast = .message("This was a bound toast message.")
///             }
///             Button("Bound error") {
///                 toast = .error("Something went wrong.")
///             }
///             Button("Direct call") {
///                 toasts.toast(MyToasts.message("This toast was presented directly."))
///             }
///         }
///         .toast($toast)
///     }
/// }
/// ```
///
/// Assigning to `toast` presents the toast and resets the value to `nil`, so the same case can be shown again.
@available(macOS, unavailable)
public protocol ToastViews: Hashable, Equatable, View {}

/// Presents and dismisses toasts in a scene.
///
/// Read the scene's instance from the `toasts` environment value. Toasts are queued and shown one at a time at
/// the top of the scene. A tap or a drag dismisses the toast that is showing.
@available(macOS, unavailable)
public protocol Toasts {
    /// Presents a toast built from a view builder.
    ///
    /// - Parameters:
    ///   - duration: How long the toast stays on screen, in seconds, before it is dismissed automatically.
    ///   - content: The view to show as the toast.
    @MainActor func toast(duration: TimeInterval, @ViewBuilder content: () -> some View)

    /// Presents a custom toast view.
    ///
    /// - Parameters:
    ///   - duration: How long the toast stays on screen, in seconds, before it is dismissed automatically.
    ///   - view: The toast view to show.
    @MainActor func toast(duration: TimeInterval, _ view: some ToastViews)

    /// Dismisses the toast that is currently showing.
    ///
    /// If other toasts are queued, the next one appears.
    @MainActor func dismiss()
}

@available(macOS, unavailable)
extension Toasts {
    /// Presents a toast built from a view builder for two seconds.
    ///
    /// - Parameter content: The view to show as the toast.
    @MainActor public func toast(@ViewBuilder content: () -> some View) {
        toast(duration: 2.0, content: content)
    }

    /// Presents a custom toast view for two seconds.
    ///
    /// - Parameter view: The toast view to show.
    @MainActor public func toast(_ view: some ToastViews) {
        toast(duration: 2.0, view)
    }

    /// Presents a standard toast with a message for two seconds.
    ///
    /// - Parameters:
    ///   - message: The text to show.
    ///   - icon: The name of an SF Symbol to show beside the message, or `nil` for no icon.
    ///   - foreground: The color of the text and icon. The default is `Toast.defaultForegroundColor`.
    ///   - background: The color of the toast. The default is `Toast.defaultBackgroundColor`.
    @MainActor public func toast(_ message: String, icon: String? = nil, foreground: Color? = nil, background: Color? = nil) {
        toast { Toast(message, icon: icon, foreground: foreground, background: background) }
    }

    /// Presents an error toast for three seconds, using the error's localized description.
    ///
    /// The toast has a warning icon and white text on a red background.
    ///
    /// - Parameter error: The error to show.
    @MainActor public func toast(error: Error) {
        toast(duration: 3.0) { Toast(error: error, icon: "exclamationmark.triangle.fill", foreground: .white, background: .red) }
    }

    /// Presents an error toast with a message for three seconds.
    ///
    /// The toast has a warning icon and white text on a red background.
    ///
    /// - Parameter error: The message to show.
    @MainActor public func toast(error: String) {
        toast(duration: 3.0) { Toast(error: error, icon: "exclamationmark.triangle.fill", foreground: .white, background: .red) }
    }
}

@available(macOS, unavailable)
extension EnvironmentValues {
    /// The toasts for the scene that contains the view.
    ///
    /// The value is provided by `overlayRoot()`. In a view hierarchy without one, calls do nothing.
    @Entry public var toasts: Toasts = MissingOverlays()
}

@available(macOS, unavailable)
extension View {
    /// Presents a custom toast whenever the bound value becomes non-nil.
    ///
    /// The binding is set back to `nil` as soon as the toast is presented, so assigning a new value presents
    /// another toast.
    ///
    /// - Parameters:
    ///   - view: A binding to the toast view to present.
    ///   - duration: How long the toast stays on screen, in seconds.
    public func toast<V: ToastViews>(_ view: Binding<V?>, duration: TimeInterval = 2.0) -> some View {
        self.modifier(ShowToastBindingModifier(view: view, duration: duration))
    }
}

@available(macOS, unavailable)
private struct ShowToastBindingModifier<V: ToastViews>: ViewModifier {
    @Environment(\.toasts) private var toasts
    var view: Binding<V?>
    var duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .onChange(of: view.wrappedValue) {
                if let view = view.wrappedValue {
                    toasts.toast(duration: duration, view)
                    self.view.wrappedValue = nil
                }
            }
    }
}


@available(macOS, unavailable)
extension View {
    /// Presents a standard toast whenever the bound message becomes non-nil.
    ///
    /// The binding is set back to `nil` as soon as the toast is presented, so assigning a new message presents
    /// another toast.
    ///
    /// - Parameters:
    ///   - text: A binding to the message to show.
    ///   - duration: How long the toast stays on screen, in seconds.
    public func toast(_ text: Binding<String?>, duration: TimeInterval = 2.0) -> some View {
        self.modifier(ShowStringBindingModifier(text: text, duration: duration))
    }


    /// Presents an error toast whenever the bound message becomes non-nil.
    ///
    /// The toast has a warning icon and white text on a red background. The binding is set back to `nil` as
    /// soon as the toast is presented, so assigning a new message presents another toast.
    ///
    /// - Parameters:
    ///   - text: A binding to the error message to show.
    ///   - duration: How long the toast stays on screen, in seconds.
    public func toast(error text: Binding<String?>, duration: TimeInterval = 3.0) -> some View {
        self.modifier(ShowErrorStringBindingModifier(text: text, duration: duration))
    }


    /// Presents an error toast whenever the bound error becomes non-nil.
    ///
    /// The toast shows the error's localized description, with a warning icon and white text on a red
    /// background. The binding is set back to `nil` as soon as the toast is presented, so assigning a new error
    /// presents another toast.
    ///
    /// - Parameters:
    ///   - error: A binding to the error to show.
    ///   - duration: How long the toast stays on screen, in seconds.
    public func toast(error: Binding<Error?>, duration: TimeInterval = 3.0) -> some View {
        self.modifier(ShowErrorBindingModifier(error: error, duration: duration))
    }
}

@available(macOS, unavailable)
private struct ShowStringBindingModifier: ViewModifier {
    @Environment(\.toasts) private var toasts
    var text: Binding<String?>
    var duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .onChange(of: text.wrappedValue) {
                if let text = text.wrappedValue {
                    toasts.toast(duration: duration, Toast(text))
                    self.text.wrappedValue = nil
                }
            }
    }
}

@available(macOS, unavailable)
private struct ShowErrorStringBindingModifier: ViewModifier {
    @Environment(\.toasts) private var toasts
    var text: Binding<String?>
    var duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .onChange(of: text.wrappedValue) {
                if let text = text.wrappedValue {
                    toasts.toast(duration: duration, Toast(error: text))
                    self.text.wrappedValue = nil
                }
            }
    }
}

@available(macOS, unavailable)
private struct ShowErrorBindingModifier: ViewModifier {
    @Environment(\.toasts) private var toasts
    var error: Binding<Error?>
    var duration: TimeInterval

    func body(content: Content) -> some View {
        content
            // `Error` isn't Equatable, so watch for a value appearing. The binding is cleared after each
            // presentation, so every new error is a fresh nil to non-nil transition.
            .onChange(of: error.wrappedValue != nil) {
                if let error = error.wrappedValue {
                    toasts.toast(duration: duration, Toast(error: error))
                    self.error.wrappedValue = nil
                }
            }
    }
}
