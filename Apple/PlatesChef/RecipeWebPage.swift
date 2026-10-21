import Foundation
import WebKit

// Loads a page the way Safari would, with no view, for pages that only write their recipe data
// once their scripts run, or that turn away a plain download.
enum RecipeWebPage {
    struct Contents {
        var jsonLD: [String]
        var html: String
    }

    // The page is read with the same script Safari runs before sharing.
    private static let script = """
        \(Bundle.main.url(forResource: "PagePreprocessing", withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
        var page = typeof ExtensionPreprocessingJS === 'undefined'
            ? { jsonLD: [] }
            : ExtensionPreprocessingJS.read();
        return {
            jsonLD: page.jsonLD,
            html: document.documentElement.outerHTML.slice(0, 3000000)
        };
        """

    static func load(_ url: URL, timeout: Duration = .seconds(20)) async -> Contents? {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        let page = WebPage(configuration: configuration)
        defer { page.stopLoading() }

        let loaded = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                do {
                    for try await event in page.load(URLRequest(url: url)) where event == .finished {
                        return true
                    }
                    return true
                } catch {
                    return false
                }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        guard loaded else { return nil }

        // A page that builds itself after it loads may not have its recipe data yet,
        // so it is read again a few times before giving up.
        var contents: Contents?
        for attempt in 0..<5 {
            if attempt > 0 { try? await Task.sleep(for: .seconds(1)) }
            guard let result = try? await page.callJavaScript(script) as? [String: Any] else {
                continue
            }
            contents = Contents(
                jsonLD: result["jsonLD"] as? [String] ?? [],
                html: result["html"] as? String ?? ""
            )
            if RecipePageParser.structuredRecipe(in: contents!.jsonLD) != nil { break }
        }
        return contents
    }
}
