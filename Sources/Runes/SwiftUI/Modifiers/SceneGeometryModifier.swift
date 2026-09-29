//
//  SceneGeometryModifier.swift
//  Runes
//
//  Created by Michael Long on 11/1/25.
//

import SwiftUI
import Observation

@Observable
public final class SceneGeometry: @unchecked Sendable {
    public internal(set) var size: CGSize = .zero
    public internal(set) var safeAreaSize: CGSize = .zero
    public internal(set) var safeAreaInsets: EdgeInsets = .init()
    public internal(set) var horizontalSizeClass: UserInterfaceSizeClass?
    public internal(set) var verticalSizeClass: UserInterfaceSizeClass?
}

extension EnvironmentValues {
    public var sceneGeometry: SceneGeometry {
        get { self[SceneGeometryKey.self] }
        set { self[SceneGeometryKey.self] = newValue }
    }
}

private struct SceneGeometryKey: EnvironmentKey {
    static let defaultValue = SceneGeometry()
}

extension View {
    /// Injects a live-updating `SceneGeometry` into the environment hierarchy.
    public func sceneGeometryRoot() -> some View {
        self.modifier(SceneGeometryModifier())
    }
}

struct SceneGeometryModifier: ViewModifier {
    @State private var sceneGeometry = SceneGeometry()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        content
            .environment(\.sceneGeometry, sceneGeometry)
            .background {
                // A reader that respects the safe area reports the safe size plus the real insets, without touching content layout.
                GeometryReader { proxy in
                    #if os(iOS) || os(visionOS)
                    let insets = proxy.safeAreaInsets
                    #else
                    let insets = EdgeInsets()
                    #endif
                    Color.clear
                        .onChange(of: Measurement(safeSize: proxy.size, insets: insets), initial: true) { _, new in
                            updateEnv(new)
                        }
                }
            }
            .onChange(of: horizontalSizeClass, initial: true) { _, newValue in
                sceneGeometry.horizontalSizeClass = newValue
            }
            .onChange(of: verticalSizeClass, initial: true) { _, newValue in
                sceneGeometry.verticalSizeClass = newValue
            }
            #if DEBUG
            .task {
                // Stable defaults for Xcode previews
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil {
                    sceneGeometry.size = CGSize(width: 393, height: 852)
                    sceneGeometry.safeAreaInsets = EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0)
                    sceneGeometry.safeAreaSize = CGSize(width: 393, height: 774)
                }
            }
            #endif
    }

    private struct Measurement: Equatable {
        let safeSize: CGSize
        let insets: EdgeInsets
    }

    private func updateEnv(_ new: Measurement) {
        sceneGeometry.safeAreaSize = new.safeSize
        sceneGeometry.safeAreaInsets = new.insets
        sceneGeometry.size = CGSize(
            width: new.safeSize.width + new.insets.leading + new.insets.trailing,
            height: new.safeSize.height + new.insets.top + new.insets.bottom
        )
    }
}
