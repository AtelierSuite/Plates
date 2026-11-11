import Foundation
import Testing
@testable import CulinaryIntelligence

@MainActor
struct DishDrawingTests {
    private static let plate = """
    <svg width="96" height="96" viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Plate">
    <defs>
    <radialGradient id="a" cx="40" cy="40" r="60" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff59a"/><stop offset="1" stop-color="#e09a00"/></radialGradient>
    </defs>
    <circle cx="48" cy="48" r="46" fill="#f0ece4"/>
    <circle cx="48" cy="48" r="30" fill="url(#a)"/>
    </svg>
    """

    @Test func keepsAPlainDrawingAndDropsTheWordsAroundIt() {
        let answer = "Here it is:\n```svg\n\(Self.plate)\n```"
        #expect(DishDrawing.sanitized(answer) == Self.plate)
    }

    @Test func rejectsAnythingThatReachesOutside() {
        let unsafe = [
            Self.plate.replacingOccurrences(of: "</svg>", with: "<script>alert(1)</script></svg>"),
            Self.plate.replacingOccurrences(of: "</svg>", with: "<image href=\"https://example.com/a.png\"/></svg>"),
            Self.plate.replacingOccurrences(of: "<circle cx=\"48\" cy=\"48\" r=\"46\"", with: "<circle onload=\"x()\" cx=\"48\" cy=\"48\" r=\"46\""),
            Self.plate.replacingOccurrences(of: "fill=\"url(#a)\"", with: "fill=\"url(https://example.com/a)\""),
            Self.plate.replacingOccurrences(of: "</svg>", with: "<foreignObject/></svg>"),
            Self.plate.replacingOccurrences(of: "<circle cx=\"48\" cy=\"48\" r=\"30\"", with: "<circle style=\"fill:red\" cx=\"48\" cy=\"48\" r=\"30\""),
            "No drawing here.",
            String(Self.plate.dropLast(6)),
        ]
        for answer in unsafe {
            #expect(DishDrawing.sanitized(answer) == nil)
        }
    }

    @Test func rendersAPNG() async throws {
        let png = try await DishDrawing.render(try #require(DishDrawing.sanitized(Self.plate)))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }
}
