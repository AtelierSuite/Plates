import CulinaryIntelligence
import SwiftUI
import UIKit

/// A file written to the temporary folder, waiting to be handed to the share sheet.
struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}
