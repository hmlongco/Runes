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
            }
            .navigationDestination(for: Destinations.self) { d in
                switch d {
                case .async(let index):
                    AsyncDemoView(index: index)
                case .toasts:
                    ToastsDemoView()
                }
            }
            .navigationTitle("Runes")
        }
    }
}

#Preview {
    ContentView()
}
