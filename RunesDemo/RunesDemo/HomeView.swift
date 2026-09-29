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
                    Text("Async Demo")
                }
                NavigationLink(value: Destinations.toasts) {
                    Text("Toasts Demo")
                }
                NavigationLink(value: Destinations.scene) {
                    Text("Scene Demo")
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
}

#Preview {
    ContentView()
}
