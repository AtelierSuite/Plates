import XCTest
@testable import PlatesKitchen

final class ScenePlanTests: XCTestCase {
    func testEveryListedCatalogSymbolIsBundled() throws {
        let asset = try XCTUnwrap(SVGSampleRecipe.load().first?.assets.first)
        for symbol in ScenePlan.symbols {
            let plan = ScenePlan(primary: symbol, secondary: "none", accent: "none", setting: "none", action: "serve")
            XCTAssertTrue(SVGChecks.evaluate(try SceneSVGRenderer.render(plan, for: asset), asset: asset).isEmpty, symbol)
        }
    }

    func testCatalogSymbolsRenderAsValidSVG() throws {
        let asset = try XCTUnwrap(SVGSampleRecipe.load().first?.assets.first)
        let plan = ScenePlan(primary: "Rice", secondary: "Egg", accent: "SpringOnion", setting: "Bowl", action: "serve")
        let svg = try SceneSVGRenderer.render(plan, for: asset)
        XCTAssertTrue(SVGChecks.evaluate(svg, asset: asset).isEmpty)
        XCTAssertTrue(SceneChecks.evaluate(plan, for: asset).isEmpty)
    }

    func testSceneCheckFindsMissingObjectsAndWrongAction() throws {
        let asset = try XCTUnwrap(SVGSampleRecipe.load().first?.assets[1])
        let plan = ScenePlan(primary: "Rice", secondary: "none", accent: "none", setting: "Pan", action: "heat")
        let issues = SceneChecks.evaluate(plan, for: asset)
        XCTAssertTrue(issues.contains("Missing scene symbol: Egg"))
        XCTAssertTrue(issues.contains("Expected action mix, got heat"))
    }
}
