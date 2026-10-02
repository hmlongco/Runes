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

    private let PADDING: CGFloat = 16

    var body: some View {
        ScrollView {
            if sceneGeometry.isHorizontalRegular && sceneGeometry.isLandscape {
                HStack(alignment: .top, spacing: PADDING) {
                    VStack(spacing: PADDING) {
                        orientationCard
                        sizeCard
                        sizesCard
                        widthCard
                    }
                    .frame(width: firstColumnWidth)
                    .layoutPriority(1)

                    VStack(spacing: PADDING) {
                        sizeClassesCard
                        insetsCard
                        widthCard
                    }
                }
                .padding(PADDING)
            } else {
                VStack(spacing: PADDING) {
                    orientationCard
                    sizeClassesCard
                    sizeCard
                    sizesCard
                    insetsCard
                    widthCard
                }
                .padding(PADDING)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scene Demo")
    }

    private var firstColumnWidth: CGFloat {
        if sceneGeometry.sizes.count > 1 {
            // first safe area width
            (sceneGeometry.sizes.first?.width ?? 0) - (PADDING / 2)
        } else {
            // divide in half after subtracting padding
            (sceneGeometry.safeAreaSize.width - (PADDING * 3)) / 2
        }
    }

    private var widthCard: some View {
        GeometryReader { proxy in
            SceneCard("Width", rows: [
                ("Actual", proxy.size.width.description),
            ])
        }
    }

    private var sizeCard: some View {
        SceneCard("Size", rows: [
            ("Size", sceneGeometry.size.formatted),
            ("Safe Area Size", sceneGeometry.safeAreaSize.formatted),
        ])
    }

    private var sizesCard: some View {
        let sizes = sceneGeometry.sizes
        return SceneCard("Sizes", rows: sizes.enumerated().map { index, size in
            (sizes.count == 1 ? "Safe Area" : "Safe Area \(index + 1)", size.formatted)
        })
    }

    private var insetsCard: some View {
        SceneCard("Safe Area Insets", rows: [
            ("Top", format(sceneGeometry.safeAreaInsets.top)),
            ("Leading", format(sceneGeometry.safeAreaInsets.leading)),
            ("Bottom", format(sceneGeometry.safeAreaInsets.bottom)),
            ("Trailing", format(sceneGeometry.safeAreaInsets.trailing)),
        ])
    }

    private var orientationCard: some View {
        SceneCard("Orientation", rows: [
            ("Portrait", sceneGeometry.isPortrait.description),
            ("Landscape", sceneGeometry.isLandscape.description),
        ])
    }

    private var sizeClassesCard: some View {
        SceneCard("Size Classes", rows: [
            ("Horizontal", sceneGeometry.horizontalSizeClass.formatted),
            ("Vertical", sceneGeometry.verticalSizeClass.formatted),
        ])
    }
}

/// A titled card of label and value rows, styled like an inset grouped list section.
private struct SceneCard: View {
    let title: String
    let rows: [(title: String, value: String)]

    init(_ title: String, rows: [(title: String, value: String)]) {
        self.title = title
        self.rows = rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 20)
                    }
                    LabeledContent(rows[index].title, value: rows[index].value)
                        .monospacedDigit()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
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
