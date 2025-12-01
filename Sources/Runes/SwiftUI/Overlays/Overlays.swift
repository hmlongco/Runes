//
//  Overlays.swift
//  Runes
//
//  Created by Michael Long on 11/30/25.
//

import SwiftUI

@available(macOS, unavailable)
public final class Overlays: ObservableObject, Toasts, Blocking, @unchecked Sendable {

    public static let shared = Overlays()

    @MainActor @Published var items: [Item] = []

    // MARK: Toast queue state
    private var toastQueue: [Configuration] = []
    private var currentToastToken: UUID? = nil

    private init() {}

    // MARK: Public API

    @MainActor public func showBlocking(_ isPresented: Bool) {
        if isPresented {
            Overlays.shared.show(.blocking(true))
        } else {
            Overlays.shared.hide(.blocking(false))
        }
    }

    @MainActor public func show(duration: TimeInterval = 2.0, _ view: some ToastViews)  {
        show(.init(id: UUID(), duration: duration, content: AnyView(view)))
    }

    @MainActor public func show<V: View>(duration: TimeInterval = 2.0, @ViewBuilder content: () -> V) {
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

@available(macOS, unavailable)
extension View {
    public func overlayRoot() -> some View {
        let _ = OverlayWindowManager.shared // ensure window created
        return self
    }
}
