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
import UIKit

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
        .sceneGeometryRoot()
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

struct GeoLog: View {
    @Environment(\.sceneGeometry) private var g
    private func line(_ tag: String) -> String {
        "PROBE \(tag) size=\(Int(g.size.width))x\(Int(g.size.height)) safe=\(Int(g.safeAreaSize.width))x\(Int(g.safeAreaSize.height)) sizes=\(g.sizes.map { "\(Int($0.width))x\(Int($0.height))" }) insets t\(Int(g.safeAreaInsets.top)) b\(Int(g.safeAreaInsets.bottom)) l\(Int(g.safeAreaInsets.leading)) r\(Int(g.safeAreaInsets.trailing)) classes=\(String(describing: g.horizontalSizeClass))/\(String(describing: g.verticalSizeClass))"
    }
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .seconds(1)); NSLog("%@", line("initial"))
                try? await Task.sleep(for: .seconds(1))
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    NSLog("PROBE requesting landscape")
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { NSLog("PROBE geometry update error: \($0)") }
                }
                try? await Task.sleep(for: .seconds(2)); NSLog("%@", line("after rotation"))
            }
            .onChange(of: g.size) { NSLog("%@", line("CHANGED size")) }
            .onChange(of: g.safeAreaSize) { NSLog("%@", line("CHANGED safe")) }
    }
}
