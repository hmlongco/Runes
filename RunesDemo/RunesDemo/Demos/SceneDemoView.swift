//
//  SceneDemoView.swift
//  RunesDemo
//
//  Created by Michael Long on 9/29/26.
//

import Runes
import SwiftUI

struct SceneDemoView: View {
    @Environment(\.sceneGeometry) private var sceneGeometry

    var body: some View {
        List {
            Section("Size") {
                row("Size", sceneGeometry.size.formatted)
                row("Safe Area Size", sceneGeometry.safeAreaSize.formatted)
            }
            Section("Safe Area Insets") {
                row("Top", sceneGeometry.safeAreaInsets.top)
                row("Leading", sceneGeometry.safeAreaInsets.leading)
                row("Bottom", sceneGeometry.safeAreaInsets.bottom)
                row("Trailing", sceneGeometry.safeAreaInsets.trailing)
            }
            Section("Size Classes") {
                row("Horizontal", sceneGeometry.horizontalSizeClass.formatted)
                row("Vertical", sceneGeometry.verticalSizeClass.formatted)
            }
        }
        .navigationTitle("Scene Demo")
    }

    private func row(_ title: String, _ value: CGFloat) -> some View {
        row(title, format(value))
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
            .monospacedDigit()
    }
}

private func format(_ value: CGFloat) -> String {
    Double(value).formatted(.number.precision(.fractionLength(0...1)))
}

private extension CGSize {
    var formatted: String {
        "\(format(width)) x \(format(height))"
    }
}

private extension Optional<UserInterfaceSizeClass> {
    var formatted: String {
        switch self {
        case .compact: "compact"
        case .regular: "regular"
        default: "none"
        }
    }
}

#Preview {
    NavigationStack {
        SceneDemoView()
    }
    .sceneGeometryRoot()
}
