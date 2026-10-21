import Foundation

// Run from Assets/DishIcons: swift contrast.swift
let manifestURL = URL(fileURLWithPath: "Parts/manifest.json")
let data = try Data(contentsOf: manifestURL)
guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let ingredients = manifest["ingredients"] as? [String: [String: [String: Any]]] else {
    fatalError("Invalid parts manifest")
}

let surfaces: [(String, String)] = [
    ("plate", "#e8e3d8"), ("rice", "#fbf8f0"), ("fried rice", "#f2d796"),
    ("tomato sauce", "#d94f45"), ("curry", "#a4693a"),
    ("creamy pasta", "#efd281"), ("lettuce", "#a8cf8e"),
    ("broth", "#e2b878"), ("pan", "#4a4e54"),
]

func lab(_ hex: String) -> (Double, Double, Double)? {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
    func linear(_ number: Int) -> Double {
        let value = Double(number) / 255
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    let r = linear((value >> 16) & 255)
    let g = linear((value >> 8) & 255)
    let b = linear(value & 255)
    let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    func adjusted(_ value: Double) -> Double {
        value > 0.008856 ? cbrt(value) : 7.787 * value + 16 / 116
    }
    let fx = adjusted(x), fy = adjusted(y), fz = adjusted(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
}

func distance(_ lhs: String, _ rhs: String) -> Double? {
    guard let a = lab(lhs), let b = lab(rhs) else { return nil }
    return sqrt(pow(a.0 - b.0, 2) + pow(a.1 - b.1, 2) + pow(a.2 - b.2, 2))
}

var count = 0
var flagged = 0
for ingredient in ingredients.keys.sorted() {
    guard let variants = ingredients[ingredient] else { continue }
    for variant in variants.keys.sorted(by: {
        let left = variants[$0]?["rank"] as? Int ?? 0
        let right = variants[$1]?["rank"] as? Int ?? 0
        return left == right ? $0 < $1 : left < right
    }) {
        guard let entry = variants[variant], entry["kind"] as? String == "piece" else { continue }
        count += 1
        let tones = entry["tones"] as? [String] ?? []
        let weak = surfaces.compactMap { name, color -> String? in
            let farthest = tones.compactMap { distance($0, color) }.max() ?? 0
            return farthest < 18 ? name : nil
        }
        if !weak.isEmpty {
            flagged += 1
            print("\(ingredient) \(variant): \(weak.joined(separator: ", "))")
        }
    }
}
print("\(flagged) of \(count) pieces are hard to see on at least one surface")
