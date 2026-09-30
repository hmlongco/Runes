import CoreGraphics
import Testing
@testable import Runes

struct SceneGeometrySizesTests {
    private let size = CGSize(width: 800, height: 600)

    @Test func noDividersReturnsTheSingleSize() {
        #expect(SceneGeometry.sizes(dividing: size, by: []) == [size])
    }

    @Test func fullHeightDividerSplitsLeadingAndTrailing() {
        let divider = CGRect(x: 380, y: 0, width: 40, height: 600)
        #expect(SceneGeometry.sizes(dividing: size, by: [divider]) == [
            CGSize(width: 380, height: 600),
            CGSize(width: 380, height: 600),
        ])
    }

    @Test func unevenDividerGivesUnevenSizes() {
        let divider = CGRect(x: 200, y: 0, width: 50, height: 600)
        #expect(SceneGeometry.sizes(dividing: size, by: [divider]) == [
            CGSize(width: 200, height: 600),
            CGSize(width: 550, height: 600),
        ])
    }

    @Test func fullWidthDividerSplitsTopAndBottom() {
        let divider = CGRect(x: 0, y: 280, width: 800, height: 40)
        #expect(SceneGeometry.sizes(dividing: size, by: [divider]) == [
            CGSize(width: 800, height: 280),
            CGSize(width: 800, height: 280),
        ])
    }

    @Test func dividerThatSpansNeitherAxisIsIgnored() {
        let notch = CGRect(x: 300, y: 0, width: 200, height: 40)
        #expect(SceneGeometry.sizes(dividing: size, by: [notch]) == [size])
    }

    @Test func dividerAtTheEdgeLeavesOneSize() {
        let divider = CGRect(x: 0, y: 0, width: 40, height: 600)
        #expect(SceneGeometry.sizes(dividing: size, by: [divider]) == [CGSize(width: 760, height: 600)])
    }

    @Test func multipleDividersGiveOneSizePerPanel() {
        let dividers = [
            CGRect(x: 500, y: 0, width: 20, height: 600),
            CGRect(x: 250, y: 0, width: 20, height: 600),
        ]
        #expect(SceneGeometry.sizes(dividing: size, by: dividers) == [
            CGSize(width: 250, height: 600),
            CGSize(width: 230, height: 600),
            CGSize(width: 280, height: 600),
        ])
    }
}
