import XCTest
@testable import PlatesKitchen

final class ImagePromptTests: XCTestCase {
    func testPromptLeadsWithSubjectAndSharesStyle() throws {
        let assets = try SVGSampleRecipe.load().flatMap(\.assets)
        XCTAssertEqual(assets.count, 15)
        XCTAssertEqual(Set(ImageStyle.all.map(\.id)).count, 8)
        XCTAssertEqual(Set(ImagePrompt.colors.keys), Set(assets.map(\.id)))
        for asset in assets {
            for background in ImageBackground.allCases {
                for style in ImageStyle.all {
                    let prompt = ImagePrompt.prompt(for: asset, background: background, style: style)
                    XCTAssertTrue(prompt.hasPrefix(asset.subject))
                    XCTAssertTrue(prompt.contains("colors: \(ImagePrompt.colors[asset.id]!)"))
                    XCTAssertTrue(prompt.contains(ImagePrompt.composition))
                    XCTAssertTrue(prompt.contains("top-down view"))
                    XCTAssertTrue(prompt.contains(background == .white ? (style.whiteBackground ?? background.phrase) : background.phrase))
                    XCTAssertTrue(prompt.hasSuffix(style.style))
                    // CLIP truncates at 77 tokens; words are a conservative proxy.
                    XCTAssertLessThan(prompt.split(separator: " ").count, 60, prompt)
                }
            }
        }
        XCTAssertTrue(ImagePrompt.negative.contains("text"))
        XCTAssertTrue(ImagePrompt.negative.contains("cut off"))
        XCTAssertTrue(ImagePrompt.negative.contains("off-center"))
        XCTAssertTrue(ImagePrompt.negative(for: .flatColor).contains("line art"))
        XCTAssertLessThan(ImagePrompt.negative(for: .flatColor).split(separator: " ").count, 30)
        XCTAssertTrue(ImagePrompt.negative(for: .cookbook).contains("photo"))
        XCTAssertFalse(ImagePrompt.negative(for: .photorealistic3D).contains("photo"))
        XCTAssertTrue(ImagePrompt.negative(for: .photorealistic3D).contains("cartoon"))
        for style in ImageStyle.all {
            XCTAssertLessThan(ImagePrompt.negative(for: style).split(separator: " ").count, 45)
        }
    }

    func testCandidatesPointAtCompiledArchives() {
        for candidate in ImageCandidate.all {
            guard let url = candidate.archiveURL else { continue }
            XCTAssertTrue(url.absoluteString.hasSuffix("_compiled.zip"))
        }
    }
}
