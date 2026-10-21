import CulinaryIntelligence
import SwiftUI
import UIKit

/// The three ways a recipe leaves the app: as the file the app itself reads, as a picture, or
/// as pages to print.
enum ShareFormat: String, CaseIterable, Identifiable {
    case plate
    case image
    case pdf

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .plate: "Recipe.Share.Plate"
        case .image: "Recipe.Share.Image"
        case .pdf: "Recipe.Share.PDF"
        }
    }

    var symbol: String {
        switch self {
        case .plate: "doc.text"
        case .image: "photo"
        case .pdf: "doc.richtext"
        }
    }
}
