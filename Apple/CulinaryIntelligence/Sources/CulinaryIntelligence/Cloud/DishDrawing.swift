import Foundation
import UIKit
import WebKit

/// A dish icon the writer draws for a recipe, when Claude or GPT 6.1 Sol writes on the cook's
/// own key. It is asked
/// for an SVG in the style of the hand drawn signature icons, the drawing is checked in code, and
/// it is rendered once into a PNG the app keeps beside the recipe file. It stands in for the dish
/// made from parts and for a signature icon alike.
public enum DishDrawing {
    /// Whether a recipe's icon is drawn: the writer runs on the cook's own key, the key is
    /// saved, and the cook allowed requests to leave the device.
    public static var isAvailable: Bool {
        WriterProvider.current.needsKey && WriterProvider.current.hasKey
            && UserDefaults.standard.bool(forKey: PlatesCloud.allowedKey)
    }

    /// The side of the rendered PNG, in points. It is rendered at the screen's scale, enough for
    /// the largest place the icon is shown.
    static let side: CGFloat = 240

    /// Asks the writer for the dish and renders it, ready to write out as a PNG.
    @MainActor
    public static func draw(for recipe: Recipe) async throws -> Data {
        guard let writer = WriterProvider.current.keyedWriter else { throw CloudError.noResponse }
        let answer = try await writer.drawDish(
            title: recipe.title,
            ingredients: ((recipe.ingredients.supermarket ?? []) + (recipe.ingredients.general ?? []) + (recipe.ingredients.optional ?? [])).map { [$0.amount, $0.item].filter { !$0.isEmpty }.joined(separator: " ") },
            finish: recipe.steps.last.map { ([$0.title] + $0.points).joined(separator: "\n") } ?? ""
        )
        guard let svg = sanitized(answer) else { throw CloudError.noResponse }
        return try await render(svg)
    }

    /// A checked SVG rendered into a PNG.
    @MainActor
    static func render(_ svg: String) async throws -> Data {
        try await SVGRenderer().render(svg, side: side)
    }

    // MARK: - Checking

    /// The elements a dish icon may use, as the style guide allows them.
    private static let elements: Set<String> = [
        "svg", "defs", "linearGradient", "radialGradient", "stop", "g", "path", "circle",
        "ellipse", "rect", "line", "polygon", "polyline", "title", "desc",
    ]

    /// The SVG in the writer's answer, or nil when it is not one a dish icon may be: not well formed,
    /// too large, or using anything that could reach outside the drawing, such as a script, an
    /// image, a link, or an event attribute.
    nonisolated static func sanitized(_ answer: String) -> String? {
        guard let start = answer.range(of: "<svg"),
              let end = answer.range(of: "</svg>", options: .backwards),
              start.lowerBound < end.lowerBound
        else { return nil }
        let svg = String(answer[start.lowerBound..<end.upperBound])
        guard svg.utf8.count <= 80_000 else { return nil }
        let checker = SVGChecker(allowed: elements)
        let parser = XMLParser(data: Data(svg.utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = checker
        guard parser.parse(), checker.isClean, checker.sawRoot else { return nil }
        return svg
    }

    nonisolated private final class SVGChecker: NSObject, XMLParserDelegate {
        let allowed: Set<String>
        var isClean = true
        var sawRoot = false

        init(allowed: Set<String>) {
            self.allowed = allowed
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String] = [:]
        ) {
            if elementName == "svg" { sawRoot = true }
            let unsafeAttribute = attributes.keys.contains { name in
                let name = name.lowercased()
                return name.hasPrefix("on") || name.hasSuffix("href") || name == "style"
            }
            let unsafeValue = attributes.values.contains { $0.lowercased().contains("url(") && !$0.contains("url(#") }
            if !allowed.contains(elementName) || unsafeAttribute || unsafeValue {
                isClean = false
                parser.abortParsing()
            }
        }

        func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
            isClean = false
            parser.abortParsing()
        }
    }
}

/// Renders an SVG through WebKit, which draws SVG on iOS, with no script, no network, and a
/// clear background, and snapshots it.
@MainActor
private final class SVGRenderer: NSObject, WKNavigationDelegate {
    private var loaded: CheckedContinuation<Void, Error>?

    func render(_ svg: String, side: CGFloat) async throws -> Data {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: side, height: side), configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = self
        let page = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=\(Int(side)), initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
        <style>html,body{margin:0;padding:0;background:transparent}svg{display:block;width:\(Int(side))px;height:\(Int(side))px}</style>
        </head><body>\(svg)</body></html>
        """
        try await withCheckedThrowingContinuation { continuation in
            loaded = continuation
            webView.loadHTMLString(page, baseURL: nil)
        }
        let snapshot = WKSnapshotConfiguration()
        snapshot.rect = CGRect(x: 0, y: 0, width: side, height: side)
        snapshot.afterScreenUpdates = true
        let image = try await webView.takeSnapshot(configuration: snapshot)
        guard let data = image.pngData() else { throw CloudError.noResponse }
        return data
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded?.resume()
        loaded = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loaded?.resume(throwing: error)
        loaded = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loaded?.resume(throwing: error)
        loaded = nil
    }
}
