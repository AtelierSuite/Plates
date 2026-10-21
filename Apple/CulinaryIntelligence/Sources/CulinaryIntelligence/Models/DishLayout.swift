import Foundation

/// One image of a dish icon, placed on the 96 point canvas the icon is drawn on.
public nonisolated struct DishPlacement: Hashable, Sendable {
    public let asset: String
    /// The centre of the image.
    public let x: Double
    public let y: Double
    /// The width and height of the square the image is drawn into.
    public let size: Double
    /// Degrees clockwise.
    public let rotation: Double
    /// Pieces cast a small shadow. Vessels and fills lie flat.
    public let isPiece: Bool
    /// The colour of the outline a piece is drawn with when its own colours sit too close to
    /// what it lands on, written as `#rrggbb`. A piece that reads on its own has none.
    public let outline: String?
}

/// Lays a dish out the way its parts were drawn to be laid out. One base takes the whole of the
/// vessel, two sit side by side, and a cover is laid over the base before it. Pieces are
/// scattered across the region of the fill they follow without landing on one another, and
/// garnish is scattered last over everything but what is set in the middle. The scatter is
/// seeded from the dish, so an icon comes out the same every time it is drawn.
public nonisolated enum DishLayout {
    public static let canvas: Double = 96

    /// The circle a fill is drawn into on its own 64 point canvas, which the layout scales onto
    /// whichever region it lands in.
    private static let fillCanvas: Double = 64
    private static let fillRadius: Double = 30

    /// Pieces whose colours all sit closer than this to the surface under them get an outline.
    private static let clash: Double = 18

    public static func placements(for dish: Dish) -> [DishPlacement] {
        let dish = dish.drawable
        guard let vessel = DishParts.vessels[dish.vessel] else { return [] }
        var random = SeededRandom(dish.seed)
        var placements = [
            DishPlacement(
                asset: DishParts.assetName(vessel: dish.vessel), x: canvas / 2, y: canvas / 2,
                size: canvas, rotation: 0, isPiece: false, outline: nil
            ),
        ]
        let parts = dish.layers.compactMap { layer in
            DishParts.part(layer.ingredient, layer.variant).map { (layer, $0) }
        }
        let bases = parts.filter { $0.1.kind == .fill && $0.1.role != .cover }.count
        var slots = (bases <= 1 ? ["full"] : ["left", "right"]).makeIterator()
        var region = DishParts.region("full", on: vessel.kind) ?? (48, 48, 32)
        var surface = vessel.tone
        var taken: [(x: Double, y: Double, size: Double)] = []
        var tiers: [DishParts.Tier: [DishPlacement]] = [:]

        for (layer, part) in parts {
            if part.kind == .fill {
                if part.role != .cover {
                    guard let slot = slots.next(), let next = DishParts.region(slot, on: vessel.kind) else { continue }
                    region = next
                    taken = []
                }
                surface = part.tones.first ?? surface
                placements.append(DishPlacement(
                    asset: DishParts.assetName(layer.ingredient, layer.variant, kind: .fill),
                    x: region.x, y: region.y, size: region.radius * fillCanvas / fillRadius,
                    rotation: 0, isPiece: false, outline: nil
                ))
                continue
            }
            let tier = part.tier ?? .scattered
            let size = part.size ?? 12
            let edge = outline(for: part.tones, on: surface)
            // Garnish keeps clear of what is set in the middle, so a sprinkle never lands
            // across the fried egg, and scatters over everything else.
            var pool = tier == .garnish ? taken.filter { $0.size >= 18 } : taken
            let spots = scatter(
                &random, in: region, count: layer.count ?? part.count ?? 1, size: size,
                avoiding: &pool, centered: tier == .centered
            )
            if tier != .garnish { taken = pool }
            for spot in spots {
                tiers[tier, default: []].append(DishPlacement(
                    asset: DishParts.assetName(layer.ingredient, layer.variant, kind: .piece),
                    x: spot.x, y: spot.y, size: size, rotation: spot.rotation, isPiece: true, outline: edge
                ))
            }
        }
        for tier in [DishParts.Tier.scattered, .centered, .garnish] {
            placements += tiers[tier] ?? []
        }
        return placements
    }

    /// Spots for a piece inside a region, each far enough from every spot already taken. A
    /// piece set in the middle stays near the centre and is not turned. When a region is too
    /// crowded for a clear spot, the last one tried is used rather than dropping the piece.
    private static func scatter(
        _ random: inout SeededRandom,
        in region: (x: Double, y: Double, radius: Double),
        count: Int,
        size: Double,
        avoiding taken: inout [(x: Double, y: Double, size: Double)],
        centered: Bool
    ) -> [(x: Double, y: Double, rotation: Double)] {
        var spots: [(x: Double, y: Double, rotation: Double)] = []
        let spread = centered ? (count == 1 ? 0.12 : 0.6) : 0.85
        let gap = centered ? 0.5 : 0.42
        for _ in 0..<count {
            for attempt in 0..<80 {
                let angle = random.next(in: 0..<(2 * .pi))
                let distance = region.radius * spread * random.next(in: 0..<1).squareRoot()
                let x = region.x + distance * cos(angle)
                let y = region.y + distance * sin(angle)
                let clear = taken.allSatisfy { hypot(x - $0.x, y - $0.y) > (size + $0.size) * gap }
                if attempt > 60 || clear {
                    taken.append((x, y, size))
                    spots.append((x, y, centered ? 0 : random.next(in: 0..<360)))
                    break
                }
            }
        }
        return spots
    }

    /// The edge a piece needs on a surface, or nothing when one of its colours already stands
    /// apart from it. The edge is the surface darkened, or lightened on a dark surface.
    static func outline(for tones: [String], on surface: String) -> String? {
        guard let ground = Color(hex: surface), !tones.isEmpty else { return nil }
        let distances = tones.compactMap(Color.init(hex:)).map { $0.distance(to: ground) }
        guard let farthest = distances.max(), farthest < clash else { return nil }
        let edge = ground.lab.l > 45
            ? ground.mixed(with: Color(r: 0x3a, g: 0x30, b: 0x26), by: 0.4)
            : ground.mixed(with: Color(r: 0xff, g: 0xff, b: 0xff), by: 0.45)
        return edge.hex
    }

    /// A colour as the layout compares colours: in CIE Lab, where a distance is close to how
    /// different two colours look.
    struct Color {
        let r: Double
        let g: Double
        let b: Double

        init(r: Double, g: Double, b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }

        init?(hex: String) {
            let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
            guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
            self.init(r: Double((value >> 16) & 0xff), g: Double((value >> 8) & 0xff), b: Double(value & 0xff))
        }

        var hex: String {
            String(format: "#%02x%02x%02x", Int(r.rounded()), Int(g.rounded()), Int(b.rounded()))
        }

        func mixed(with other: Color, by amount: Double) -> Color {
            Color(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
        }

        var lab: (l: Double, a: Double, b: Double) {
            func linear(_ channel: Double) -> Double {
                let c = channel / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            let (lr, lg, lb) = (linear(r), linear(g), linear(self.b))
            let x = (0.4124 * lr + 0.3576 * lg + 0.1805 * lb) / 0.95047
            let y = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
            let z = (0.0193 * lr + 0.1192 * lg + 0.9505 * lb) / 1.08883
            func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
            return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))
        }

        func distance(to other: Color) -> Double {
            let (p, q) = (lab, other.lab)
            return ((p.l - q.l) * (p.l - q.l) + (p.a - q.a) * (p.a - q.a) + (p.b - q.b) * (p.b - q.b)).squareRoot()
        }
    }
}

/// A random number source that always runs the same way from the same seed, so a recipe's icon
/// is laid out the same on every launch. `Hasher` is seeded per process and would not be.
nonisolated struct SeededRandom {
    private var state: UInt64

    init(_ seed: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        state = hash
    }

    /// SplitMix64.
    mutating func nextValue() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    mutating func next(in range: Range<Double>) -> Double {
        let unit = Double(nextValue() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func pick<T>(_ options: [T]) -> T? {
        guard !options.isEmpty else { return nil }
        return options[Int(nextValue() % UInt64(options.count))]
    }
}
