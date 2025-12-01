//
//  OverlayWindow.swift
//  Runes
//
//  Created by Michael Long on 11/30/25.
//

import Combine
import SwiftUI

@available(macOS, unavailable)
@MainActor internal final class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    private var window: OverlayWindow?
    private var cancellable: AnyCancellable?

    private init() {
        createPersistentWindow()

        // Observe overlay items and choose interaction mode
        cancellable = Overlays.shared.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self, let window = self.window else { return }

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

    private func createPersistentWindow() {
        guard window == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        let host = UIHostingController(
            rootView: OverlayWindowHost()
                .environmentObject(Overlays.shared)
        )
        host.view.backgroundColor = .clear

        let overlayWindow = OverlayWindow(windowScene: scene)
        overlayWindow.frame = scene.screen.bounds
        overlayWindow.rootViewController = host
        overlayWindow.backgroundColor = .clear
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.isHidden = false
        overlayWindow.makeKeyAndVisible()

        overlayWindow.interactionMode = .passthrough

        self.window = overlayWindow
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
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: state.items)
    }
}

@available(macOS, unavailable)
internal struct OverlayWindowToastView: View {
    @State private var dragging: CGFloat = 0
    let config: Overlays.Configuration

    var body: some View {
        VStack {
            config.content
                .padding(.top, 80)
                .padding(.horizontal)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged({ value in
                            dragging = CGFloat(value.location.y)
                        })
                        .onEnded { value in
                            if abs(dragging) > 20 {
                                Overlays.shared.dismissToast(id: config.id)
                            }
                        }
                )
                .onTapGesture {
                    Overlays.shared.dismissToast(id: config.id)
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
