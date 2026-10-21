import Foundation
import UniformTypeIdentifiers

enum RecipePageLoader {
    enum LoadError: Error {
        case noURL
        case unsupportedURL
        case downloadFailed
        case noRecipe
    }

    static func load(from items: [NSExtensionItem]) async throws -> ChefRecipe {
        let page = try await sharedPage(from: items)
        guard let url = page.url else { throw LoadError.noURL }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw LoadError.unsupportedURL
        }

        if url.pathExtension.lowercased() == "json",
           let recipe = RecipePageParser.onePanRecipe(try await download(url)) {
            return recipe
        }
        if let recipe = try await onePanRecipe(at: url) { return recipe }
        var recipe = try await structuredRecipe(at: url, sharing: page)
        recipe.page?.url = url.absoluteString
        return recipe
    }

    /// A recipe read from the page's structured data: what Safari read off the page first,
    /// then the page downloaded, then the page loaded in a hidden web view.
    private static func structuredRecipe(at url: URL, sharing page: SafariPage) async throws -> ChefRecipe {
        if let recipe = RecipePageParser.structuredRecipe(in: page.jsonLD) { return recipe }

        let downloaded = try? await download(url)
        if let downloaded,
           let recipe = RecipePageParser.structuredRecipe(in: String(decoding: downloaded, as: UTF8.self)) {
            return recipe
        }

        guard let contents = await RecipeWebPage.load(url) else {
            throw downloaded == nil ? LoadError.downloadFailed : LoadError.noRecipe
        }
        if let recipe = RecipePageParser.structuredRecipe(in: contents.jsonLD)
            ?? RecipePageParser.structuredRecipe(in: contents.html) {
            return recipe
        }
        throw LoadError.noRecipe
    }

    private struct SafariPage {
        var url: URL?
        var jsonLD: [String] = []
    }

    private static func sharedPage(from items: [NSExtensionItem]) async throws -> SafariPage {
        let providers = items.flatMap { $0.attachments ?? [] }
        var page = SafariPage()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
            guard let dictionary = try? await propertyList(from: provider),
                  let result = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any]
            else { continue }
            page.url = (result["url"] as? String).flatMap(URL.init(string:))
            page.jsonLD = result["jsonLD"] as? [String] ?? []
            break
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            guard let url = try? await url(from: provider) else { continue }
            page.url = url
            break
        }
        return page
    }

    // Safari registers the preprocessing results as a dictionary, not as data, so
    // loadDataRepresentation fails on them and the item has to be loaded as it was registered.
    private static func propertyList(from provider: NSItemProvider) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let dictionary = value as? [String: Any] {
                    continuation.resume(returning: dictionary)
                } else if let data = value as? Data,
                          let dictionary = try? PropertyListSerialization.propertyList(
                            from: data, options: [], format: nil
                          ) as? [String: Any] {
                    continuation.resume(returning: dictionary)
                } else {
                    continuation.resume(throwing: LoadError.noURL)
                }
            }
        }
    }

    private static func url(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { value, error in
                if let error { continuation.resume(throwing: error) }
                else if let value { continuation.resume(returning: value) }
                else { continuation.resume(throwing: LoadError.noURL) }
            }
        }
    }

    private static func onePanRecipe(at url: URL) async throws -> ChefRecipe? {
        guard let fragment = url.fragment,
              fragment.hasPrefix("/"),
              let id = fragment.dropFirst().split(separator: "/").first,
              !id.isEmpty else { return nil }

        var base = URLComponents(url: url, resolvingAgainstBaseURL: false)
        base?.fragment = nil
        guard let pageURL = base?.url,
              let manifestURL = URL(string: "recipes/index.json", relativeTo: pageURL)?.absoluteURL,
              let data = try? await download(manifestURL),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = manifest["recipes"] as? [[String: Any]],
              let entry = entries.first(where: { $0["id"] as? String == String(id) }),
              let path = entry["file"] as? String,
              path.hasPrefix("recipes/"), path.hasSuffix(".json"), !path.contains(".."),
              let recipeURL = URL(string: path, relativeTo: pageURL)?.absoluteURL,
              recipeURL.host == pageURL.host,
              let recipeData = try? await download(recipeURL)
        else { return nil }
        return RecipePageParser.onePanRecipe(recipeData)
    }

    private static func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("text/html, application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              response.expectedContentLength <= 3_000_000
        else { throw LoadError.downloadFailed }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 3_000_000 else { throw LoadError.downloadFailed }
            data.append(byte)
        }
        return data
    }
}
