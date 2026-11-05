//
//  HidesOnVerticalScroll.swift
//  Runes
//
//  Created by Michael Long on 11/5/26.
//

import SwiftUI

extension View {
    /// Drives a visibility flag from the vertical scroll direction of the scroll view this modifier is applied to.
    ///
    /// The flag becomes `false` after a short scroll down and `true` again after a deliberate scroll up,
    /// from anywhere in the content, not just at the top. The modifier only updates the binding.
    /// You decide what the flag controls, such as the tab bar, a navigation bar, or a floating button.
    ///
    /// The behavior is tuned to avoid flicker:
    /// - Within the top 50 points of the content the flag is always `true`.
    /// - Scrolling down 10 points hides.
    /// - Scrolling up 60 points shows. The larger distance keeps small reversals and finger jitter from
    ///   bringing the element back.
    /// - Distance is accumulated per direction and resets when the direction reverses.
    /// - Changes are animated with `.easeInOut`.
    ///
    /// Apply the modifier to the `ScrollView` itself (or a container that wraps it), since it observes
    /// that scroll view's geometry.
    ///
    /// ```swift
    /// struct DetailView: View {
    ///     @State private var tabBarVisible = true
    ///
    ///     var body: some View {
    ///         ScrollView {
    ///             content
    ///         }
    ///         .hidesOnVerticalScroll($tabBarVisible)
    ///         .toolbarVisibility(tabBarVisible ? .visible : .hidden, for: .tabBar)
    ///     }
    /// }
    /// ```
    ///
    /// Any view can be driven by the flag, for example a floating button:
    ///
    /// ```swift
    /// ScrollView { content }
    ///     .hidesOnVerticalScroll($showsButton)
    ///     .overlay(alignment: .bottomTrailing) {
    ///         if showsButton {
    ///             Button("Add", systemImage: "plus", action: add)
    ///                 .transition(.scale)
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameter isVisible: A binding that receives `false` while the user scrolls down and `true`
    ///   while they scroll up or are near the top. Start it at `true`.
    /// - Returns: A view that updates `isVisible` as its scroll view moves.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func hidesOnVerticalScroll(_ isVisible: Binding<Bool>) -> some View {
        modifier(HidesOnVerticalScroll(isVisible: isVisible))
    }

    /// Hides a toolbar element on vertical scroll down and restores it on scroll up, with no state to manage.
    ///
    /// This is the self-contained variant of ``hidesOnVerticalScroll(_:)``. It owns the visibility flag
    /// and applies `toolbarVisibility(_:for:)` to the placement you give it. The scroll behavior and
    /// thresholds are identical.
    ///
    /// ```swift
    /// ScrollView {
    ///     content
    /// }
    /// .hidesOnVerticalScroll(for: .tabBar)
    /// ```
    ///
    /// Any placement that supports `toolbarVisibility(_:for:)` works:
    ///
    /// ```swift
    /// List(items) { item in
    ///     Text(item.name)
    /// }
    /// .hidesOnVerticalScroll(for: .navigationBar)
    /// ```
    ///
    /// If you need the flag for anything else, or want to drive several elements from it, use
    /// ``hidesOnVerticalScroll(_:)`` and manage the state yourself.
    ///
    /// - Parameter placement: The toolbar element to hide and show, such as `.tabBar` or `.navigationBar`.
    /// - Returns: A view that hides and shows `placement` as its scroll view moves.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func hidesOnVerticalScroll(for placement: ToolbarPlacement) -> some View {
        modifier(HidesToolbarOnVerticalScroll(placement: placement))
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
private struct HidesToolbarOnVerticalScroll: ViewModifier {
    let placement: ToolbarPlacement
    @State private var isVisible = true

    func body(content: Content) -> some View {
        content
            .hidesOnVerticalScroll($isVisible)
            .toolbarVisibility(isVisible ? .visible : .hidden, for: placement)
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
private struct HidesOnVerticalScroll: ViewModifier {
    @Binding var isVisible: Bool

    /// Signed distance scrolled since the last change of direction.
    @State private var travel: CGFloat = 0

    private let topZone: CGFloat = 50
    private let hideThreshold: CGFloat = 10
    /// Larger than the hide distance so small reversals and finger jitter don't bring the bar back.
    private let showThreshold: CGFloat = 60

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldOffset, newOffset in
                // Always visible near the top.
                guard newOffset > topZone else {
                    travel = 0
                    update(visible: true)
                    return
                }

                // Per-frame deltas are only a few points, so accumulate within a direction
                // and start over when the direction reverses.
                let delta = newOffset - oldOffset
                travel = delta * travel < 0 ? delta : travel + delta

                if travel > hideThreshold {
                    update(visible: false)
                } else if travel < -showThreshold {
                    update(visible: true)
                }
            }
    }

    private func update(visible: Bool) {
        guard isVisible != visible else {
            return
        }
        withAnimation(.easeInOut(duration: 0.4)) {
            isVisible = visible
        }
    }
}
