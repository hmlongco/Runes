//
//  SceneGeometryModifier.swift
//  Runes
//
//  Created by Michael Long on 11/1/25.
//

import SwiftUI
import Observation

/// A live-updating snapshot of the geometry of the scene: its size, safe area, and size classes.
///
/// Apply `sceneGeometryRoot()` once at the root of your scene, then read the values from any descendant view
/// through the `sceneGeometry` environment value.
///
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         RootView()
///             .sceneGeometryRoot()
///     }
/// }
///
/// struct DetailView: View {
///     @Environment(\.sceneGeometry) private var sceneGeometry
///     @State var viewModel = DetailViewModel()
///
///     var body: some View {
///         if sceneGeometry.isHorizontalCompact {
///             CompactLayout(viewModel: viewModel)
///         } else {
///             RegularLayout(viewModel: viewModel)
///         }
///     }
/// }
/// ```
///
/// The class is `@Observable`, so a view that reads a property re-evaluates its body when that property changes,
/// for example when the device rotates or the scene is resized. The properties are read-only outside of Runes.
@Observable
public final class SceneGeometry: @unchecked Sendable {
    /// The full size of the scene in points, including the safe area.
    ///
    /// Equal to ``safeAreaSize`` plus ``safeAreaInsets``. This is `.zero` until the first layout pass.
    public internal(set) var size: CGSize = .zero

    /// The size of the scene in points with the safe area removed.
    ///
    /// This is the space the system considers safe for content, and it is `.zero` until the first layout pass.
    public internal(set) var safeAreaSize: CGSize = .zero

    /// The safe area insets of the scene, in points.
    ///
    /// The values are always zero on platforms other than iOS and visionOS.
    public internal(set) var safeAreaInsets: EdgeInsets = .init()

    /// The horizontal size class of the view hierarchy that `sceneGeometryRoot()` was applied to.
    ///
    /// This reflects the root of the scene. A sheet or popover can have a different size class than the one reported here.
    /// The value is `nil` on platforms that don't provide size classes.
    public internal(set) var horizontalSizeClass: UserInterfaceSizeClass?

    /// The vertical size class of the view hierarchy that `sceneGeometryRoot()` was applied to.
    ///
    /// This reflects the root of the scene. A sheet or popover can have a different size class than the one reported here.
    /// The value is `nil` on platforms that don't provide size classes.
    public internal(set) var verticalSizeClass: UserInterfaceSizeClass?
}

extension SceneGeometry {

    // safe areas

    /// A Boolean value that indicates whether the safe area has a leading inset.
    public var hasLeading: Bool { safeAreaInsets.leading > 0 }

    /// A Boolean value that indicates whether the safe area has a trailing inset.
    public var hasTrailing: Bool { safeAreaInsets.trailing > 0 }

    /// A Boolean value that indicates whether the safe area has a top inset.
    public var hasTop: Bool { safeAreaInsets.top > 0 }

    /// A Boolean value that indicates whether the safe area has a bottom inset.
    public var hasBottom: Bool { safeAreaInsets.bottom > 0 }

    /// A Boolean value that indicates whether or not we have any safe area insets.
    public var hasSafeAreas: Bool { hasLeading || hasTrailing || hasTop  || hasBottom }

    // size classes

    /// A Boolean value that indicates whether the horizontal size class is ``UserInterfaceSizeClass/compact``.
    public var isHorizontalCompact: Bool { horizontalSizeClass == .compact }

    /// A Boolean value that indicates whether the vertical size class is ``UserInterfaceSizeClass/compact``.
    public var isVerticalCompact: Bool { verticalSizeClass == .compact }
}

extension EnvironmentValues {
    /// The geometry of the scene that contains the view.
    ///
    /// The value is provided by `sceneGeometryRoot()`. Without it, the environment returns a
    /// shared default instance that is never updated, so every size is `.zero`, the insets are empty, and the size
    /// classes are `nil`.
    public var sceneGeometry: SceneGeometry {
        get { self[SceneGeometryKey.self] }
        set { self[SceneGeometryKey.self] = newValue }
    }
}

private struct SceneGeometryKey: EnvironmentKey {
    static let defaultValue = SceneGeometry()
}

extension View {
    /// Measures the scene and injects a live-updating ``SceneGeometry`` into the environment of this view and its
    /// descendants.
    ///
    /// Apply this modifier once, at the root of the scene. Descendants read the values with
    /// `@Environment(\.sceneGeometry)`.
    ///
    /// The measurement is taken from a reader placed in the view's background, so the modifier doesn't change the
    /// layout or the safe area behavior of the content it wraps. In Xcode previews the sizes and insets are fixed
    /// to iPhone-sized defaults.
    ///
    /// - Returns: A view that publishes the scene geometry to its descendants.
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
                            sceneGeometry.size = CGSize(
                                width: new.safeSize.width + new.insets.leading + new.insets.trailing,
                                height: new.safeSize.height + new.insets.top + new.insets.bottom
                            )
                            sceneGeometry.safeAreaSize = new.safeSize
                            sceneGeometry.safeAreaInsets = new.insets
                        }
                }
            }
            .onChange(of: horizontalSizeClass, initial: true) { _, newValue in
                sceneGeometry.horizontalSizeClass = newValue
            }
            .onChange(of: verticalSizeClass, initial: true) { _, newValue in
                sceneGeometry.verticalSizeClass = newValue
            }
    }

    private struct Measurement: Equatable {
        let safeSize: CGSize
        let insets: EdgeInsets
    }
}
