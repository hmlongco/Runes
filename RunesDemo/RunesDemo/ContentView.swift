//
//  ContentView.swift
//  RunesDemo
//
//  Created by Michael Long on 11/1/25.
//

import Combine
import Observation
import Runes
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .overlayRoot()
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
    }
}

#Preview {
    ContentView()
}
