import SwiftUI
import Testing
@testable import Runes

@MainActor
struct OverlaysTests {
    @Test func toastsStayInTheirOwnScene() {
        let first = Overlays()
        let second = Overlays()

        first.toast(duration: 60) { Text("first") }

        #expect(first.items.count == 1)
        #expect(second.items.isEmpty)
    }

    @Test func blockingStaysInItsOwnScene() {
        let first = Overlays()
        let second = Overlays()

        first.blocking(true)
        #expect(first.items == [.blocking(true)])
        #expect(second.items.isEmpty)

        first.blocking(false)
        #expect(first.items.isEmpty)
    }
}
