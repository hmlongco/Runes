//
//  Blocking.swift
//  Runes
//
//  Created by Michael Long on 11/30/25.
//

import SwiftUI

public protocol Blocking {
    @MainActor func showBlocking(_ isPresented: Bool)
}

@available(macOS, unavailable)
extension EnvironmentValues {
    @Entry public var blocking: Blocking = Overlays.shared
}

extension View {
    public func blocking(isPresented: Bool) -> some View {
        self.modifier(BlockingOverlayModifier(isPresented: isPresented))
    }
}

@available(macOS, unavailable)
private struct BlockingOverlayModifier: ViewModifier {
    var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) {
                Overlays.shared.showBlocking(isPresented)
            }
    }
}
