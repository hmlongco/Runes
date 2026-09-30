//
//  HomeView.swift
//  RunesDemo
//
//  Created by Michael Long on 11/1/25.
//

import Combine
import Observation
import Runes
import SwiftUI

enum Destinations: Hashable {
    case async(Int)
    case toasts
    case scene
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: Destinations.async(1)) {
                    demo("Async Demo", "Using the SharedAsyncStream datasource.")
                }
                NavigationLink(value: Destinations.scene) {
                    demo("Scene Demo", "Using the sceneGeometry environment variable.")
                }
                NavigationLink(value: Destinations.toasts) {
                    demo("Toasts Demo", "Presenting toasts and other overlays.")
                }
            }
            .navigationDestination(for: Destinations.self) { d in
                switch d {
                case .async(let index):
                    AsyncDemoView(index: index)
                case .toasts:
                    ToastsDemoView()
                case .scene:
                    SceneDemoView()
                }
            }
            .navigationTitle("Runes")
        }
    }

    func demo(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
