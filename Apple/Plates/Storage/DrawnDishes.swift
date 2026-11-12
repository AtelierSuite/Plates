import Foundation
import Observation
import UIKit

/// The dish icons the writer drew, kept as `<id>.png` beside each recipe's `<id>.json`. The file sits
/// in the same folder, so it travels through iCloud Drive with the recipe, and builds that only
/// read the JSON leave it alone.
@MainActor
@Observable
final class DrawnDishes {
    static let shared = DrawnDishes()

    private(set) var images: [String: UIImage] = [:]
    private var directory: URL?

    /// Reads every drawing in the folder, after the recipes in it are read.
    func load(from directory: URL?) {
        self.directory = directory
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else {
            images = [:]
            return
        }
        var found: [String: UIImage] = [:]
        for file in files where file.pathExtension == "png" {
            let id = file.deletingPathExtension().lastPathComponent
            if let image = UIImage(contentsOfFile: file.path(percentEncoded: false)) {
                found[id] = image
            }
        }
        images = found
    }

    func image(for id: String) -> UIImage? {
        id.isEmpty ? nil : images[id]
    }

    /// Writes a drawing beside its recipe and shows it.
    func store(_ data: Data, for id: String, in directory: URL) {
        let url = Self.url(for: id, in: directory)
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        if directory == self.directory, let image = UIImage(data: data) {
            images[id] = image
        }
    }

    /// Takes a drawing away, so the dish is drawn from its parts again.
    func remove(for id: String, in directory: URL) {
        try? FileManager.default.removeItem(at: Self.url(for: id, in: directory))
        if directory == self.directory {
            images[id] = nil
        }
    }

    static func url(for id: String, in directory: URL) -> URL {
        directory.appending(path: "\(id).png", directoryHint: .notDirectory)
    }
}
