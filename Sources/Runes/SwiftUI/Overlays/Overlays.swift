//
//  Overlays.swift
//  Runes
//
//  Created by Michael Long on 11/30/25.
//

import SwiftUI

@available(macOS, unavailable)
public final class Overlays: ObservableObject, Toasts, Blocking, @unchecked Sendable {

    @MainActor @Published var items: [Item] = []

    // MARK: Toast queue state
    private var toastQueue: [Configuration] = []
    private var currentToastToken: UUID? = nil

    internal init() {}

    // MARK: Public API

    @MainActor public func blocking(_ isPresented: Bool) {
        if isPresented {
            show(.blocking(true))
        } else {
            hide(.blocking(false))
        }
    }

    @MainActor public func toast(duration: TimeInterval = 2.0, _ view: some ToastViews)  {
        show(.init(id: UUID(), duration: duration, content: AnyView(view)))
    }

    @MainActor public func toast<V: View>(duration: TimeInterval = 2.0, @ViewBuilder content: () -> V) {
        show(.init(id: UUID(), duration: duration, content: AnyView(content())))
    }

    @MainActor public func dismiss() {
        dismissToast(id: currentToastToken)
    }

    // MARK: - Private Toast queue logic

    @MainActor internal func show(_ configuration: Configuration) {
        toastQueue.append(configuration)
        processNextToastIfNeeded()
    }

    @MainActor internal func show(_ item: Item) {
        switch item {
        case .toast(let configuration):
            show(configuration)
        case .blocking:
            if !items.contains(item) {
                items.append(item)
            }
        }
    }

    @MainActor internal func dismissToast(id: UUID?) {
        guard let current = toastQueue.first, current.id == currentToastToken else { return }
        currentToastToken = nil
        finishToast(config: current)
    }

    @MainActor internal func hide(_ item: Item) {
        items.removeAll { $0 == item }
    }

    @MainActor internal func processNextToastIfNeeded() {
        guard currentToastToken == nil, let next = toastQueue.first else { return }

        currentToastToken = next.id
        items.append(.toast(next))

        // Auto-dismiss based on per-toast duration
        DispatchQueue.main.asyncAfter(deadline: .now() + next.duration) {
            guard self.currentToastToken == next.id else { return }
            self.finishToast(config: next)
        }
    }

    @MainActor internal func finishToast(config: Configuration) {
        items.removeAll {
            if case .toast(let c) = $0 { return c.id == config.id } else { return false }
        }

        if !toastQueue.isEmpty {
            toastQueue.removeFirst()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.currentToastToken = nil
            self.processNextToastIfNeeded()
        }
    }
}

@available(macOS, unavailable)
extension Overlays {
    internal struct Configuration: Identifiable, Equatable {
        internal let id: UUID
        internal let duration: TimeInterval
        internal let content: AnyView

        internal init(id: UUID, duration: TimeInterval, content: AnyView) {
            self.id = id
            self.duration = duration
            self.content = content
        }

        internal static func == (lhs: Configuration, rhs: Configuration) -> Bool {
            lhs.id == rhs.id
        }
    }

    internal enum Item: Identifiable, Equatable {
        case toast(Configuration)
        case blocking(Bool)

        internal var id: String {
            switch self {
            case .toast(let config):
                return "toast-\(config.id.uuidString)"
            case .blocking:
                return "blocking"
            }
        }

        internal static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case (.blocking, .blocking):
                return true
            case (.toast(let c1), .toast(let c2)):
                return c1 == c2
            default:
                return false
            }
        }
    }
}

/// Stands in for `Overlays` when a view has no `overlayRoot()` above it. Calls do nothing.
@available(macOS, unavailable)
internal struct MissingOverlays: Toasts, Blocking {
    @MainActor func toast(duration: TimeInterval, content: () -> some View) { warn() }
    @MainActor func toast(duration: TimeInterval, _ view: some ToastViews) { warn() }
    @MainActor func dismiss() { warn() }
    @MainActor func blocking(_ isPresented: Bool) { warn() }

    private func warn() {
        #if DEBUG
        print("Runes: overlays used without an overlayRoot() above the view; nothing will be shown.")
        #endif
    }
}

@available(macOS, unavailable)
extension View {
    /// Gives the scene this view is in its own toast and blocking overlays.
    ///
    /// Apply this modifier once, at the root of each scene. Each scene gets its own overlay window and its own
    /// state, so a toast triggered from one scene never appears in another. Descendants present overlays through
    /// the `toasts` and `blocking` environment values, or the `toast(_:duration:)` and `blocking(_:)` modifiers.
    public func overlayRoot() -> some View {
        self.modifier(OverlayRootModifier())
    }
}

@available(macOS, unavailable)
private struct OverlayRootModifier: ViewModifier {
    @State private var controller = SceneOverlayController()

    func body(content: Content) -> some View {
        content
            .environment(\.toasts, controller.overlays)
            .environment(\.blocking, controller.overlays)
            .background(OverlaySceneReader(controller: controller))
    }
}
