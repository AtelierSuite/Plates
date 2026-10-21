import CulinaryIntelligence
import SwiftUI
import UIKit

extension Color {
    /// Paper is white whatever the reader's appearance is, so the ink is written down rather
    /// than taken from the environment.
    static let paperInk = Color(white: 0.08)
    static let paperSoft = Color(white: 0.42)
    static let paperRule = Color(white: 0.86)
    /// The app's orange, darkened until it reads as text on white.
    static let paperAccent = Color(red: 0xB5 / 255, green: 0x4E / 255, blue: 0x16 / 255)
    /// A warm wash behind the facts, the notes, and the edge of a picture.
    static let paperTint = Color(red: 0xFB / 255, green: 0xF5 / 255, blue: 0xEE / 255)
}
