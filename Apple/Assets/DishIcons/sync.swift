import Foundation

// Run from Assets/DishIcons after changing Parts: swift sync.swift
let files = FileManager.default
let work = URL(fileURLWithPath: files.currentDirectoryPath, isDirectory: true)
let root = work.deletingLastPathComponent().deletingLastPathComponent()
let parts = work.appendingPathComponent("Parts", isDirectory: true)
let assets = root.appendingPathComponent("Plates/Dishes.xcassets", isDirectory: true)
let resource = root.appendingPathComponent("CulinaryIntelligence/Sources/CulinaryIntelligence/Resources/DishParts.json")

func object(_ value: Any?) throws -> [String: Any] {
    guard let result = value as? [String: Any] else { throw SyncError.invalidManifest }
    return result
}

func string(_ value: Any?) throws -> String {
    guard let result = value as? String else { throw SyncError.invalidManifest }
    return result
}

func array(_ value: Any?) throws -> [String] {
    guard let result = value as? [String] else { throw SyncError.invalidManifest }
    return result
}

enum SyncError: Error {
    case invalidManifest
    case missingSource(String)
}

func pascal(_ name: String) -> String {
    name.split(separator: "-").map { $0.capitalized }.joined()
}

func write(_ value: Any, to url: URL, pretty: Bool = false) throws {
    if let existing = try? Data(contentsOf: url),
       let decoded = try? JSONSerialization.jsonObject(with: existing),
       NSDictionary(dictionary: try object(decoded)).isEqual(to: try object(value)) {
        return
    }
    let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys, .fragmentsAllowed]
    var data = try JSONSerialization.data(withJSONObject: value, options: options)
    data.append(0x0a)
    try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if (try? Data(contentsOf: url)) != data { try data.write(to: url, options: .atomic) }
}

func copy(_ source: URL, to destination: URL) throws {
    guard files.fileExists(atPath: source.path) else { throw SyncError.missingSource(source.path) }
    let data = try Data(contentsOf: source)
    if (try? Data(contentsOf: destination)) != data {
        if files.fileExists(atPath: destination.path) { try files.removeItem(at: destination) }
        try files.copyItem(at: source, to: destination)
    }
}

let folder: [String: Any] = [
    "info": ["author": "xcode", "version": 1],
    "properties": ["provides-namespace": false],
]

func imageSet(group: String, name: String, file: String) throws {
    let groupURL = assets.appendingPathComponent(group, isDirectory: true)
    let setURL = groupURL.appendingPathComponent("\(name).imageset", isDirectory: true)
    try files.createDirectory(at: setURL, withIntermediateDirectories: true)
    try write(folder, to: groupURL.appendingPathComponent("Contents.json"), pretty: true)
    try copy(parts.appendingPathComponent(file), to: setURL.appendingPathComponent("\(name).svg"))
    let contents: [String: Any] = [
        "images": [["filename": "\(name).svg", "idiom": "universal"]],
        "info": ["author": "xcode", "version": 1],
        "properties": ["preserves-vector-representation": true],
    ]
    try write(contents, to: setURL.appendingPathComponent("Contents.json"), pretty: true)
}

func role(_ variant: String, covers: Bool) -> String {
    if covers { return "cover" }
    if ["broth", "soup", "stew", "porridge"].contains(variant) { return "soup" }
    if ["sauce", "curry", "dal", "glaze"].contains(variant) { return "sauce" }
    if ["bed", "shredded"].contains(variant) { return "bed" }
    return "base"
}

let manifestData = try Data(contentsOf: parts.appendingPathComponent("manifest.json"))
let manifest = try object(JSONSerialization.jsonObject(with: manifestData))
let vessels = try object(manifest["vessels"])
let ingredients = try object(manifest["ingredients"])
let hidden = try object(manifest["hidden"])
var appVessels: [String: Any] = [:]
var appIngredients: [String: Any] = [:]
var expected: [String: Set<String>] = ["Vessels": [], "Fills": [], "Pieces": []]

try files.createDirectory(at: assets, withIntermediateDirectories: true)
try write(folder, to: assets.appendingPathComponent("Contents.json"), pretty: true)

for (name, value) in vessels {
    let entry = try object(value)
    let assetName = "DishVessel" + pascal(name)
    try imageSet(group: "Vessels", name: assetName, file: string(entry["file"]))
    expected["Vessels", default: []].insert("\(assetName).imageset")
    appVessels[name] = ["kind": try string(entry["kind"]), "tone": try array(entry["tones"]).first ?? "#ffffff"]
}

for (ingredient, value) in ingredients {
    let variants = try object(value)
    var appVariants: [String: Any] = [:]
    for (variant, rawEntry) in variants {
        let entry = try object(rawEntry)
        let kind = try string(entry["kind"])
        let group = kind == "fill" ? "Fills" : "Pieces"
        let assetName = "Dish\(kind == "fill" ? "Fill" : "Piece")" + pascal(ingredient) + pascal(variant)
        try imageSet(group: group, name: assetName, file: string(entry["file"]))
        expected[group, default: []].insert("\(assetName).imageset")
        var output: [String: Any] = [
            "kind": kind, "tones": try array(entry["tones"]),
            "rank": entry["rank"] ?? 0,
        ]
        if kind == "fill" {
            output["vessels"] = try array(entry["vessels"])
            output["role"] = role(variant, covers: entry["covers"] as? Bool ?? false)
        } else {
            output["size"] = entry["size"]
            output["count"] = entry["count"]
            output["tier"] = entry["tier"]
            if let most = entry["most"] { output["most"] = most }
        }
        appVariants[variant] = output
    }
    appIngredients[ingredient] = appVariants
}

for (group, names) in expected {
    let groupURL = assets.appendingPathComponent(group, isDirectory: true)
    for url in try files.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil) {
        if url.pathExtension == "imageset" && !names.contains(url.lastPathComponent) {
            try files.removeItem(at: url)
        }
    }
}

let app: [String: Any] = [
    "vessels": appVessels,
    "regions": manifest["regions"] ?? [:],
    "ingredients": appIngredients,
    "hidden": hidden.keys.sorted(),
]
try write(app, to: resource)
print("Synced \(expected.values.reduce(0) { $0 + $1.count }) image sets")
