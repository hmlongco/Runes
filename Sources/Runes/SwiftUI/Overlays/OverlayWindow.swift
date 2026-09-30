//
//  OverlayWindow.swift
//  Runes
//
//  Created by Michael Long on 11/30/25.
//

import Combine
import SwiftUI

/// Owns the overlay state and the overlay window for one scene. Each `overlayRoot()` creates one.
@available(macOS, unavailable)
@MainActor internal final class SceneOverlayController {
    let overlays = Overlays()
    private var window: OverlayWindow?
    private var cancellable: AnyCancellable?

    // Kept cheap on purpose: SwiftUI can run `@State` initializers on every body evaluation.
    init() {}

    /// Creates the overlay window in `scene`, or removes it when `scene` is `nil`.
    func attach(to scene: UIWindowScene?) {
        guard scene !== window?.windowScene else { return }
        detach()
        guard let scene else { return }

        let host = UIHostingController(
            rootView: OverlayWindowHost()
                .environmentObject(overlays)
                .sceneGeometryRoot()
        )
        host.view.backgroundColor = .clear

        // No explicit frame: a window created with a scene tracks that scene's bounds, including
        // resizing and moving between screens, which a fixed `scene.screen.bounds` would not.
        let overlayWindow = OverlayWindow(windowScene: scene)
        overlayWindow.rootViewController = host
        overlayWindow.backgroundColor = .clear
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.isHidden = false
        overlayWindow.makeKeyAndVisible()

        self.window = overlayWindow
        updateInteractionMode(overlays.items)

        // Observe overlay items and choose interaction mode
        cancellable = overlays.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.updateInteractionMode(items)
            }
    }

    func detach() {
        cancellable = nil
        window?.isHidden = true
        window = nil
    }

    private func updateInteractionMode(_ items: [Overlays.Item]) {
        guard let window else { return }

        let hasBlocking = items.contains {
            if case .blocking(true) = $0 { return true } else { return false }
        }
        let hasToast = items.contains {
            if case .toast = $0 { return true } else { return false }
        }

        if hasBlocking {
            window.interactionMode = .blockAll
        } else if hasToast {
            window.interactionMode = .overlaysOnly
        } else {
            window.interactionMode = .passthrough
        }
    }
}

/// Reports the window scene that hosts the view it is attached to, so each root gets its own overlay window.
@available(macOS, unavailable)
internal struct OverlaySceneReader: UIViewRepresentable {
    let controller: SceneOverlayController

    func makeUIView(context: Context) -> SceneReaderView {
        SceneReaderView(controller: controller)
    }

    func updateUIView(_ uiView: SceneReaderView, context: Context) {}

    static func dismantleUIView(_ uiView: SceneReaderView, coordinator: ()) {
        uiView.controller.detach()
    }

    @MainActor internal final class SceneReaderView: UIView {
        let controller: SceneOverlayController

        init(controller: SceneOverlayController) {
            self.controller = controller
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            controller.attach(to: window?.windowScene)
        }
    }
}

@available(macOS, unavailable)
@MainActor internal final class OverlayWindow: UIWindow {
    enum InteractionMode {
        case passthrough        // no overlays – let everything go to app below
        case blockAll           // blocking overlay – intercept everything
        case overlaysOnly       // toast only – intercept only where overlays have gestures/controls
    }

    var interactionMode: InteractionMode = .passthrough

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        switch interactionMode {
        case .passthrough:
            // Pretend this window doesn't exist
            return nil

        case .blockAll:
            // Normal behavior – full-screen blocking overlay
            return super.hitTest(point, with: event)

        case .overlaysOnly:
            // Ask UIKit what view in this window would handle the touch
            guard let view = super.hitTest(point, with: event) else {
                return nil
            }

            // Walk up the view hierarchy; if we find a UIControl or any view with gesture recognizers,
            // we treat it as part of an interactive overlay (toast etc.).
            var current: UIView? = view
            while let c = current {
                if c is UIControl { return view }
                if let grs = c.gestureRecognizers, !grs.isEmpty {
                    return view
                }
                current = c.superview
            }

            // Otherwise, let the touch fall through to the app underneath
            return nil
        }
    }
}

@available(macOS, unavailable)
internal struct OverlayWindowHost: View {
    @EnvironmentObject private var state: Overlays

    var body: some View {
        ZStack {
            ForEach(state.items, id: \.id) { item in
                switch item {
                case .toast(let config):
                    OverlayWindowToastView(config: config)
                        .zIndex(2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(config.id)

                case .blocking:
                    OverlayWindowBlockingView()
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.4), value: state.items)
    }
}

@available(macOS, unavailable)
internal struct OverlayWindowToastView: View {
    @EnvironmentObject private var overlays: Overlays
    @Environment(\.sceneGeometry) var scene
    @State private var dragging: CGFloat = 0
    let config: Overlays.Configuration

    var body: some View {
        VStack {
            config.content
                .frame(maxWidth: 500)
                .padding(.top, scene.hasTop ? 0 : 16)
                .padding(.leading, 16)
                .padding(.trailing, scene.hasTrailing ? 0 : 16)
                .padding(.bottom, scene.hasBottom ? 0 : 16)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged({ value in
                            dragging = CGFloat(value.location.y)
                        })
                        .onEnded { value in
                            if abs(dragging) > 20 {
                                overlays.dismissToast(id: config.id)
                            }
                        }
                )
                .onTapGesture {
                    overlays.dismissToast(id: config.id)
                }
               .offset(y: -dragging)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

@available(macOS, unavailable)
internal struct OverlayWindowBlockingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(2.0)
                .tint(Color.primary)
        }
    }
}
