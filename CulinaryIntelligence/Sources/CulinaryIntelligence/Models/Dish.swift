import Foundation

/// A finished dish as its icon draws it, seen from above: a vessel, then the ingredients on it
/// in the order they are laid down. Every layer names one of the drawn variants of a catalog
/// ingredient, such as `tomato` `diced` or `rice` `bowl`. The seed is what the pieces are
/// scattered from, so the icon is drawn the same way every time and redrawing it can give a
/// fresh arrangement of the same dish.
public nonisolated struct Dish: Decodable, Hashable, Sendable {
    public var vessel: String
    public var seed: String
    public var layers: [DishLayer]
    /// Whether the recipe makes a dish with a signature icon, which is drawn instead of the
    /// layers. Kept through a redraw, since the recipe is the same dish.
    public var signature: SignatureDecision?

    public init(vessel: String, seed: String, layers: [DishLayer], signature: SignatureDecision? = nil) {
        self.vessel = vessel
        self.seed = seed
        self.layers = layers
        self.signature = signature
    }
}

public nonisolated struct DishLayer: Decodable, Hashable, Sendable {
    public var ingredient: String
    public var variant: String
    /// How many pieces to scatter, when the part's own count is not wanted.
    public var count: Int?

    public init(_ ingredient: String, _ variant: String, count: Int? = nil) {
        self.ingredient = ingredient
        self.variant = variant
        self.count = count
    }
}

/// Every drawn part of a dish icon, read from `DishParts.json`. The parts themselves are vector
/// images in the app's asset catalog; this is what the layout needs to know about each of them.
/// The file is written by the script that draws the parts, along with the images.
public nonisolated enum DishParts {
    public enum Kind: String, Decodable, Sendable {
        case fill, piece
    }

    /// What a fill does on the dish. A base is the food a dish is built on, a sauce or a soup
    /// fills a region the same way, a bed is greens for the rest to sit on, and a cover is laid
    /// over the base already in its region rather than taking a region of its own.
    public enum Role: String, Decodable, Sendable {
        case base, sauce, soup, bed, cover
    }

    /// How a piece is laid out: scattered across its region, set in the middle of it, or
    /// scattered as a garnish over everything else.
    public enum Tier: Int, Decodable, Sendable {
        case scattered = 0, centered = 1, garnish = 2
    }

    public struct Part: Decodable, Sendable {
        public let kind: Kind
        /// Where the variant sits in its ingredient's list, most usual first. A dish takes the
        /// lowest ranked variant when nothing in the recipe asks for another.
        public let rank: Int
        /// The colours the part reads as, most of it first.
        public let tones: [String]
        public let vessels: [String]?
        public let role: Role?
        /// A piece's size on the 96 point canvas the whole icon is drawn on.
        public let size: Double?
        public let count: Int?
        public let tier: Tier?
        /// The most of a piece the dish has room for, when each one is a whole thing, such as a
        /// fried egg or a sausage. A piece that has this is drawn as many times as the recipe's
        /// amount says, and `count` times when the amount gives no number.
        public let most: Int?
    }

    public struct Vessel: Decodable, Sendable {
        /// The kind of vessel, which is what a fill says it can go in: `plate`, `bowl`, `pan`,
        /// `pot`, or `board`. Several colours of plate are all of the kind `plate`.
        public let kind: String
        /// The colour of the well the food sits in.
        public let tone: String
    }

    struct File: Decodable {
        let vessels: [String: Vessel]
        let regions: [String: [String: [Double]]]
        let ingredients: [String: [String: Part]]
        let hidden: [String]
    }

    private static let file: File = {
        guard let url = Bundle.module.url(forResource: "DishParts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            return File(vessels: [:], regions: [:], ingredients: [:], hidden: [])
        }
        return file
    }()

    public static var vessels: [String: Vessel] { file.vessels }

    /// The drawn variants of an ingredient, most usual first.
    public static func variants(of ingredient: String) -> [(name: String, part: Part)] {
        (file.ingredients[ingredient] ?? [:])
            .map { (name: $0.key, part: $0.value) }
            .sorted { $0.part.rank < $1.part.rank }
    }

    /// Every vessel of a kind, such as the plain, rimmed, sage, and terracotta plates.
    public static func vessels(ofKind kind: String) -> [String] {
        file.vessels.filter { $0.value.kind == kind }.map(\.key).sorted()
    }

    public static func part(_ ingredient: String, _ variant: String) -> Part? {
        file.ingredients[ingredient]?[variant]
    }

    /// Whether an ingredient is left off the icon because it cannot be seen once the dish is
    /// served: salt, soy sauce, flour, a bay leaf taken out before serving.
    public static func isHidden(_ ingredient: String) -> Bool {
        hiddenSet.contains(ingredient)
    }

    private static let hiddenSet = Set(file.hidden)

    /// Where fills sit on a kind of vessel, as a circle on the 96 point canvas. Every kind has
    /// a `full` region, and `left` and `right` for two fills side by side.
    static func region(_ name: String, on kind: String) -> (x: Double, y: Double, radius: Double)? {
        guard let values = file.regions[kind]?[name], values.count == 3 else { return nil }
        return (values[0], values[1], values[2])
    }

    /// The asset a vessel is drawn from, such as `DishVesselBowlIndigo`.
    public static func assetName(vessel: String) -> String {
        "DishVessel" + pascalCased(vessel)
    }

    /// The asset a layer is drawn from, such as `DishFillRiceBowl` or `DishPieceTomatoDiced`.
    public static func assetName(_ ingredient: String, _ variant: String, kind: Kind) -> String {
        (kind == .fill ? "DishFill" : "DishPiece") + pascalCased(ingredient) + pascalCased(variant)
    }

    private static func pascalCased(_ name: String) -> String {
        name.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}

extension Dish {
    /// Drops every layer the parts catalog has nothing for, so a dish written by an older
    /// build or by hand still draws what it can.
    nonisolated public var drawable: Dish {
        Dish(
            vessel: DishParts.vessels[vessel] == nil ? "plate" : vessel,
            seed: seed,
            layers: layers.filter { DishParts.part($0.ingredient, $0.variant) != nil },
            signature: signature
        )
    }

    /// The dish as the recipe file keeps it.
    public var json: JSONValue {
        .object(
            [
                ("vessel", .string(vessel)),
                ("seed", .string(seed)),
                ("layers", .array(layers.map(\.json))),
            ] + (signature.map { [(key: "signature", value: $0.json)] } ?? [])
        )
    }
}

extension DishLayer {
    public var json: JSONValue {
        .object(
            [
                ("ingredient", JSONValue.string(ingredient)),
                ("variant", JSONValue.string(variant)),
            ] + (count.map { [(key: "count", value: JSONValue.number($0))] } ?? [])
        )
    }
}
