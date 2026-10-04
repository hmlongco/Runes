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

    /// The safe area sizes of the scene in points, ordered leading to trailing, or top to bottom.
    ///
    /// When the device is folded so that the system divides the scene there is one safe area
    /// size for each side of the division, otherwise the array contains the single ``safeAreaSize``.
    public internal(set) var sizes: [CGSize] = [.zero]

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

    /// A Boolean value that indicates whether the horizontal size class is ``UserInterfaceSizeClass/regular``.
    public var isHorizontalRegular: Bool { horizontalSizeClass == .regular }

    /// A Boolean value that indicates whether the vertical size class is ``UserInterfaceSizeClass/compact``.
    public var isVerticalCompact: Bool { verticalSizeClass == .compact }

    /// A Boolean value that indicates whether the vertical size class is ``UserInterfaceSizeClass/regular``.
    public var isVerticalRegular: Bool { verticalSizeClass == .regular }

    // orientation

    /// A Boolean value that indicates if the general layout orientation is portrait.
    ///
    /// Note this doesn't necessarily mean the device is rotated. For example, the general layout orientation could appear to be
    /// portrait when running side by side in a split view.
    public var isPortrait: Bool { size.height > size.width }

    /// A Boolean value that indicates if the general layout orientation is landscape.
    ///
    /// Note this doesn't necessarily mean the device is rotated. For example, the general layout orientation could appear to be
    /// landscape when running folded on a Duo.
    public var isLandscape: Bool { size.width > size.height }

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
            .onGeometryChange(for: Measurement.self, of: Measurement.init(proxy:)) { new in
                sceneGeometry.size = CGSize(
                    width: new.safeSize.width + new.insets.leading + new.insets.trailing,
                    height: new.safeSize.height + new.insets.top + new.insets.bottom
                )
                sceneGeometry.safeAreaSize = new.safeSize
                sceneGeometry.sizes = SceneGeometry.sizes(dividing: new.safeSize, by: new.dividers)
                sceneGeometry.safeAreaInsets = new.insets
            }
            .onChange(of: horizontalSizeClass, initial: true) { _, newValue in
                sceneGeometry.horizontalSizeClass = newValue
            }
            .onChange(of: verticalSizeClass, initial: true) { _, newValue in
                sceneGeometry.verticalSizeClass = newValue
            }
    }
}

extension SceneGeometry {

    /// Splits `size` around the frames of the regions that divide it.
    ///
    /// A divider that spans the full height splits the width into a leading and a trailing size. If there are none,
    /// a divider that spans the full width splits the height instead. Dividers that span neither are ignored.
    static func sizes(dividing size: CGSize, by dividers: [CGRect]) -> [CGSize] {
        let tolerance: CGFloat = 1
        let vertical = dividers
            .filter { $0.height >= size.height - tolerance && $0.width < size.width }
            .sorted { $0.minX < $1.minX }
        let horizontal = dividers
            .filter { $0.width >= size.width - tolerance && $0.height < size.height }
            .sorted { $0.minY < $1.minY }

        var sizes: [CGSize] = []
        var start: CGFloat = 0
        if !vertical.isEmpty {
            for divider in vertical {
                sizes.append(CGSize(width: divider.minX - start, height: size.height))
                start = max(start, divider.maxX)
            }
            sizes.append(CGSize(width: size.width - start, height: size.height))
            sizes = sizes.filter { $0.width > 0 }
        } else if !horizontal.isEmpty {
            for divider in horizontal {
                sizes.append(CGSize(width: size.width, height: divider.minY - start))
                start = max(start, divider.maxY)
            }
            sizes.append(CGSize(width: size.width, height: size.height - start))
            sizes = sizes.filter { $0.height > 0 }
        }
        return sizes.isEmpty ? [size] : sizes
    }
}

private struct Measurement: Equatable, Sendable {
    let safeSize: CGSize
    let insets: EdgeInsets
    let dividers: [CGRect]

    init(proxy: GeometryProxy) {
        // The frames of the regions the system uses to divide the scene, in the coordinate space of the proxy.
        var dividers: [CGRect] = []
        #if canImport(SwiftUICore, _version: 8.0.85)
        if #available(anyAppleOS 27.1, *) {
            dividers = proxy.reservedRegions(kind: .division).map(\.frame)
        }
        #endif
        self.dividers = dividers

        // temp shim for iPhone Duo and iOS 27.1 when app is located in leading split view
        var needDuoInsetShim = false
        if #available(anyAppleOS 27.1, *) {
            let badDuoSplitViewWidth = 469
            needDuoInsetShim = Int(proxy.size.width) == badDuoSplitViewWidth && proxy.safeAreaInsets.trailing == 0
        }

        if needDuoInsetShim {
            self.safeSize = CGSize(width: 385, height: 635)
            self.insets = EdgeInsets(top: 0, leading: 84, bottom: 34, trailing: 0)
        } else {
            self.safeSize = proxy.size
            self.insets = proxy.safeAreaInsets
        }
    }
}
