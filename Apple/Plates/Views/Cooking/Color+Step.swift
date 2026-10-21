import CulinaryIntelligence
import SwiftUI
import UIKit

extension Color {
    /// The background of one step in cooking mode, taken from the step's title, so a step keeps
    /// its colour wherever it appears and however the recipe is reordered. The colour is then
    /// darkened until white text on it passes 7:1, which reads at arm's length and across a
    /// kitchen.
    static func step(_ title: String) -> Color {
        let hue = Double(stableHash(Step.comparable(title)) % 360) / 360
        let saturation = 0.55
        var brightness = 0.75
        while brightness > 0.2,
              contrastWithWhite(hue: hue, saturation: saturation, brightness: brightness) < 7 {
            brightness -= 0.01
        }
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// FNV-1a over the text's bytes. `hashValue` is seeded afresh on every launch, so it would
    /// give a step a new colour each time the app is opened.
    private static func stableHash(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private static func contrastWithWhite(hue: Double, saturation: Double, brightness: Double) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
            .getRed(&red, green: &green, blue: &blue, alpha: nil)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return 1.05 / (luminance + 0.05)
    }
}
