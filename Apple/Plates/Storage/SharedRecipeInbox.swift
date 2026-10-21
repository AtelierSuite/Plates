import CulinaryIntelligence
import Foundation

/// A recipe the share extension left in the inbox. A recipe read off a web page carries the
/// page's lines as well, for the app to sort, and the recipe as the extension read it is kept
/// for when it cannot be sorted. A recipe that was already in the app's schema has no page.
struct SharedImport: Identifiable {
    let url: URL
    let recipe: Recipe
    let page: SharedPage?

    var id: URL { url }
}

/// The share extension puts each recipe here as a JSON file with a unique name, written
/// atomically before the extension completes.
enum SharedRecipeInbox {
    static let groupIdentifier = "group.com.tsubuzaki.Plates"

    private static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
            .appending(path: "PendingRecipes", directoryHint: .isDirectory)
    }

    /// The page lines sit beside the recipe's own keys in the same file.
    private struct Envelope: Decodable {
        var page: SharedPage?
    }

    static func pendingRecipes() throws -> [SharedImport] {
        guard let directory else { return [] }
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        let decoder = JSONDecoder()
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let recipe = try? decoder.decode(Recipe.self, from: data)
            else { return nil }
            let page = (try? decoder.decode(Envelope.self, from: data))?.page
            return SharedImport(url: url, recipe: recipe, page: page)
        }
    }

    static func remove(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
