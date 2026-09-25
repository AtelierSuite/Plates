import XCTest
@testable import PlatesKitchen

final class SVGChecksTests: XCTestCase {
    func testPromptSuppliesAReferenceForEveryRequiredObject() throws {
        for asset in try SVGSampleRecipe.load().flatMap(\.assets) {
            let prompt = SVGPrompt.user(for: asset)
            XCTAssertTrue(prompt.contains("Scene: \(asset.subject)."), asset.id)
            XCTAssertTrue(prompt.contains("viewBox=\"0 0 \(asset.size.width) \(asset.size.height)\""), asset.id)
            for symbol in asset.expectedSymbols {
                XCTAssertTrue(prompt.contains("\(symbol): <"), "Missing \(symbol) reference for \(asset.id)")
            }
        }
    }

    func testSamplesCoverEveryStepAndRecipeIcon() throws {
        let recipes = try SVGSampleRecipe.load()
        XCTAssertEqual(recipes.count, 3)
        XCTAssertEqual(recipes.flatMap(\.assets).count, 15)
        for recipe in recipes {
            XCTAssertEqual(recipe.assets.filter { $0.kind == .icon }.count, 1)
            XCTAssertEqual(recipe.assets.filter { $0.kind == .step }.count, recipe.steps.count)
        }
    }

    func testRejectsActiveContentAndExternalReferences() throws {
        let asset = try XCTUnwrap(SVGSampleRecipe.load().first?.assets.first)
        let safe = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 128 128\"><circle cx=\"64\" cy=\"64\" r=\"40\" fill=\"#f1c21b\"/></svg>"
        XCTAssertTrue(SVGChecks.evaluate(safe, asset: asset).isEmpty)
        XCTAssertFalse(SVGChecks.evaluate(safe.replacingOccurrences(of: "<circle", with: "<script>alert(1)</script><circle"), asset: asset).isEmpty)
        XCTAssertFalse(SVGChecks.evaluate(safe.replacingOccurrences(of: "<circle", with: "<circle onload=\"alert(1)\""), asset: asset).isEmpty)
        XCTAssertFalse(SVGChecks.evaluate(safe.replacingOccurrences(of: "#f1c21b", with: "url(https://example.com/image)"), asset: asset).isEmpty)
    }

    func testUnwrapsOnlyOneCleanSVGCodeFence() {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 128 128\"></svg>"
        XCTAssertEqual(SVGChecks.extract("```svg\n\(svg)\n```").svg, svg)
        XCTAssertEqual(SVGChecks.extract("```xml\n\(svg)\n```").warning, "Markdown code fence removed")
        XCTAssertEqual(SVGChecks.extract("Here is your SVG:\n```svg\n\(svg)\n```").warning, nil)
    }
}
