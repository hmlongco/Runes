//
//  ScreenEnvironmentModifier.swift
//  Runes
//
//  Created by Michael Long on 11/1/25.
//

import SwiftUI
import Observation

@Observable
public final class ScreenEnvironment: @unchecked Sendable {
    var screenSize: CGSize = .zero
    var safeAreaScreenSize: CGSize = .zero
    var safeAreaInsets: EdgeInsets = .init()
}

extension EnvironmentValues {
    public var screen: ScreenEnvironment {
        get { self[ScreenEnvironmentKey.self] }
        set { self[ScreenEnvironmentKey.self] = newValue }
    }
}

private struct ScreenEnvironmentKey: EnvironmentKey {
    static let defaultValue = ScreenEnvironment()
}

extension View {
    /// Injects a live-updating `ScreenEnvironment` into the environment hierarchy.
    public func screenEnvironmentRoot() -> some View {
        self.modifier(ScreenEnvironmentModifier())
    }
}

struct ScreenEnvironmentModifier: ViewModifier {
    @State private var screenEnv = ScreenEnvironment()

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let fullSize = proxy.size
            #if os(iOS) || os(visionOS)
            let insets = proxy.safeAreaInsets
            #else
            let insets = EdgeInsets()
            #endif

            let safeSize = CGSize(
                width: fullSize.width - (insets.leading + insets.trailing),
                height: fullSize.height - (insets.top + insets.bottom)
            )

            ZStack {
                Color.clear
                    .onAppear {
                        updateEnv(fullSize, insets, safeSize)
                    }
                    .onChange(of: fullSize) { _, newValue in
                        let newSafe = CGSize(
                            width: newValue.width - (insets.leading + insets.trailing),
                            height: newValue.height - (insets.top + insets.bottom)
                        )
                        updateEnv(newValue, insets, newSafe)
                    }
                    .onChange(of: insets) { _, newInsets in
                        let newSafe = CGSize(
                            width: fullSize.width - (newInsets.leading + newInsets.trailing),
                            height: fullSize.height - (newInsets.top + newInsets.bottom)
                        )
                        updateEnv(fullSize, newInsets, newSafe)
                    }
                content
                    .environment(\.screen, screenEnv)
                    .ignoresSafeArea()
            }
        }
        #if DEBUG
        .task {
            // Stable defaults for Xcode previews
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil {
                screenEnv.screenSize = CGSize(width: 393, height: 852)
                screenEnv.safeAreaInsets = EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0)
                screenEnv.safeAreaScreenSize = CGSize(width: 393, height: 774)
            }
        }
        #endif
    }

    private func updateEnv(_ full: CGSize, _ insets: EdgeInsets, _ safe: CGSize) {
        screenEnv.screenSize = full
        screenEnv.safeAreaInsets = insets
        screenEnv.safeAreaScreenSize = safe
    }
}
