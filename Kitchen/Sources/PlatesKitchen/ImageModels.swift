import Foundation
import Darwin
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct ImageCandidate: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let repository: String
    let archiveName: String?
    let approximateSizeMB: Int
    let resolution: Int
    let isXL: Bool
    let notes: String
    var defaultStyle: ImageStyle = .cookbook

    static let all: [ImageCandidate] = [
        .init(id: "sd21-base", name: "Stable Diffusion 2.1 base", repository: "apple/coreml-stable-diffusion-2-1-base-palettized",
              archiveName: "coreml-stable-diffusion-2-1-base-palettized_split_einsum_v2_compiled.zip",
              approximateSizeMB: 1140, resolution: 512, isXL: false, notes: "6-bit palettized; CreativeML Open RAIL++-M"),
        .init(id: "sdxl-ios", name: "Stable Diffusion XL base (iOS)", repository: "apple/coreml-stable-diffusion-xl-base-ios",
              archiveName: "coreml-stable-diffusion-xl-base-ios_split_einsum_compiled.zip",
              approximateSizeMB: 3050, resolution: 768, isXL: true, notes: "4-bit mixed palettization; CreativeML Open RAIL++-M",
              defaultStyle: .flatColor),
        .init(id: "sd21-base-4bit", name: "Stable Diffusion 2.1 base, 4-bit", repository: "sd2-community/stable-diffusion-2-1-base",
              archiveName: nil, approximateSizeMB: 790, resolution: 512, isXL: false, notes: "Local conversion; Apple 4.00-bit mixed palettization recipe"),
        .init(id: "bk-sdm-v2-small", name: "BK-SDM v2 Small", repository: "nota-ai/bk-sdm-v2-small",
              archiveName: nil, approximateSizeMB: 760, resolution: 512, isXL: false, notes: "Local conversion; distilled SD 2.1 base UNet, 6-bit"),
        .init(id: "bk-sdm-v2-tiny", name: "BK-SDM v2 Tiny", repository: "nota-ai/bk-sdm-v2-tiny",
              archiveName: nil, approximateSizeMB: 640, resolution: 512, isXL: false, notes: "Local conversion; distilled SD 2.1 base UNet, 6-bit")
    ]

    /// Nil for models that are converted locally with Scripts/convert-image-models.sh.
    var archiveURL: URL? { archiveName.map { URL(string: "https://huggingface.co/\(repository)/resolve/main/\($0)")! } }
    var modelPage: URL { URL(string: "https://huggingface.co/\(repository)")! }
}

enum ImageBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case white, green

    var id: String { rawValue }
    var phrase: String { "isolated on a plain solid \(self == .white ? "white" : "bright green") background" }
}

/// Style wording differs by model: SD 2.1 and its distilled variants read "cookbook illustration" as flat art,
/// while SDXL reads it, together with outlines and a white background, as an ink sketch.
struct ImageStyle: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let style: String
    /// Replaces the white background phrase, since "white" pushes SDXL toward uncolored line art.
    let whiteBackground: String?
    let negative: String

    static let cookbook = ImageStyle(
        id: "cookbook", name: "Cookbook",
        style: "flat vector cookbook illustration, simple bold shapes, thick dark outlines, warm food colors",
        whiteBackground: nil, negative: "photo, photorealistic")
    static let flatColor = ImageStyle(
        id: "flat-color", name: "Flat color",
        style: "flat 2D food icon, solid colors, rounded shapes, no outlines or shading, minimal detail",
        whiteBackground: "isolated on a plain light pastel background",
        negative: "photo, photorealistic, sketch, line art, monochrome, grayscale, intricate texture, glass")
    static let cartoon = ImageStyle(
        id: "cartoon", name: "Cartoon",
        style: "cute flat cartoon illustration, bright solid colors, chunky simple shapes, soft rounded forms, minimal detail, picture book",
        whiteBackground: "isolated on a plain light pastel background",
        negative: "photo, photorealistic, sketch, line art, monochrome, grayscale, intricate texture, glass")
    static let sticker = ImageStyle(
        id: "sticker", name: "Sticker",
        style: "simple flat food sticker, vivid solid colors, smooth color fills, clean vector shapes, soft drop shadow, minimal detail",
        whiteBackground: "isolated on a plain light pastel background",
        negative: "photo, photorealistic, sketch, line art, monochrome, grayscale, intricate texture, glass")
    static let simpleGeometric = ImageStyle(
        id: "simple-geometric", name: "Simple geometric",
        style: "simple geometric 2D food icon, rounded shapes, solid ingredient colors",
        whiteBackground: "isolated on a plain light pastel background",
        negative: "sketch, line art, monochrome, grayscale, gradients, realistic texture, photograph, photorealistic, intricate detail")
    static let outlineGlyph = ImageStyle(
        id: "outline-glyph", name: "Outline glyph",
        style: "minimal outline food glyph, clean bold colored contour strokes, sparse ingredient-colored fills, simple recognizable silhouette",
        whiteBackground: nil,
        negative: "black and white, monochrome, grayscale, sketch, hatching, engraving, pencil, photo, photorealism, dense detail")
    static let abstract3D = ImageStyle(
        id: "3d-abstract", name: "3D abstract",
        style: "stylized 3D food icon, simple sculpted forms, saturated ingredient colors, smooth matte material, soft studio lighting",
        whiteBackground: nil,
        negative: "flat vector, line art, monochrome, grayscale, photograph, photorealistic, realistic texture, intricate detail")
    static let photorealistic3D = ImageStyle(
        id: "3d-photorealistic", name: "3D photorealistic",
        style: "photorealistic 3D food render, natural ingredient colors, realistic textures, soft studio lighting, sharp focus",
        whiteBackground: nil,
        negative: "flat vector, cartoon, illustration, line art, sketch, monochrome, grayscale, plastic, toy")

    static let all: [ImageStyle] = [.cookbook, .flatColor, .cartoon, .sticker,
                                    .simpleGeometric, .outlineGlyph, .abstract3D, .photorealistic3D]
}

enum ImagePrompt {
    static let composition = "top-down view, centered objects, fully visible, clear margins"
    static let negative = "text, watermark, logo, people, hands, clutter, scenery, frame, cropped, cut off, close-up, off-center, duplicate, blurry"

    /// Short, asset-specific palettes put the requested colors before the style tokens in CLIP's context.
    static let colors: [String: String] = [
        "egg-fried-rice-icon": "white rice, golden egg, green spring onion",
        "egg-fried-rice-step-1": "golden yellow egg, pale bowl, silver fork",
        "egg-fried-rice-step-2": "golden yellow egg, dark gray pan",
        "egg-fried-rice-step-3": "white rice, golden egg, dark gray pan",
        "egg-fried-rice-step-4": "white rice, golden egg, green spring onion",
        "tomato-meat-sauce-icon": "golden pasta, red tomato sauce, brown beef, green celery",
        "tomato-meat-sauce-step-1": "ivory onion, pale green celery, natural wood board",
        "tomato-meat-sauce-step-2": "browned beef, dark gray pan, silver spoon",
        "tomato-meat-sauce-step-3": "red tomato sauce, brown beef, green celery, dark pan",
        "tomato-meat-sauce-step-4": "golden pasta, red tomato sauce, brown beef",
        "grilled-cheese-icon": "golden brown toast, warm yellow melted cheese",
        "grilled-cheese-step-1": "pale bread, yellow butter",
        "grilled-cheese-step-2": "pale bread, yellow cheese and butter",
        "grilled-cheese-step-3": "golden brown bread, yellow cheese, dark gray pan",
        "grilled-cheese-step-4": "golden brown toast, warm yellow melted cheese"
    ]

    /// Subject and its palette first, then composition and style, to stay inside CLIP's context.
    static func prompt(for asset: SVGSampleAsset, background: ImageBackground, style: ImageStyle = .cookbook) -> String {
        let backgroundPhrase = background == .white ? (style.whiteBackground ?? background.phrase) : background.phrase
        let colorPhrase = colors[asset.id].map { "colors: \($0), " } ?? ""
        return "\(asset.subject), \(colorPhrase)\(composition), \(backgroundPhrase), \(style.style)"
    }

    static func negative(for style: ImageStyle) -> String {
        style.negative.isEmpty ? negative : "\(negative), \(style.negative)"
    }
}

struct ImageRun: Identifiable, Codable, Sendable {
    let id: UUID
    let modelID: String
    let assetID: String
    let recipeID: String
    let kind: SVGSampleAsset.Kind
    let repetition: Int
    let seed: UInt32
    let stepCount: Int
    let prompt: String
    let startedAt: Date
    let loadSeconds: Double?
    let durationSeconds: Double
    let footprintMB: Double
    let peakFootprintMB: Double
    let imageFile: String?
    let error: String?
    var review: SVGReview
    var background: ImageBackground? = nil
    var styleID: String? = nil
    var cutoutFile: String? = nil
    var cutoutMethod: CutoutResult.Method? = nil
    var subjectInstances: Int? = nil
    var droppedInstances: Int? = nil
    var subjectCoverage: Double? = nil
    var subjectCenterOffset: Double? = nil
    var subjectTouchesEdge: Bool? = nil
    var cutoutSeconds: Double? = nil

    /// Problems that remain in the cutout. Empty means a usable, centered subject.
    var cutoutChecks: [String] {
        guard imageFile != nil else { return [] }
        guard cutoutFile != nil else { return ["No subject found"] }
        var checks: [String] = []
        if subjectTouchesEdge == true { checks.append("Subject touches the image edge and may be cut off") }
        if (subjectCoverage ?? 0) < 0.08 { checks.append("Subject covers under 8% of the image") }
        return checks
    }

    /// Corrections the cutout step made to the generated image.
    var cutoutNotes: [String] {
        guard cutoutFile != nil else { return [] }
        var notes: [String] = []
        if cutoutMethod == .backgroundKey { notes.append("Vision found no subject, so the border color was removed") }
        if (droppedInstances ?? 0) > 0 { notes.append("Dropped \(droppedInstances!) extra object\(droppedInstances! == 1 ? "" : "s") beside the subject") }
        if (subjectCenterOffset ?? 0) > 0.25 { notes.append("Re-centered a subject that was \(Int((subjectCenterOffset ?? 0) * 100))% off center") }
        return notes
    }
}

enum ProcessMemory {
    static func footprintMB() -> (current: Double, peak: Double) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task_self_trap(), task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        return (Double(info.phys_footprint) / 1_048_576, Double(info.ledger_phys_footprint_peak) / 1_048_576)
    }
}

enum ImageContactSheet {
    /// One row per recipe, model, and style, with the icon followed by each step.
    /// With `cutouts`, draws each cutout over a checkerboard so removed background is visible.
    static func write(runs: [ImageRun], recipes: [SVGSampleRecipe], imageDirectory: URL, to url: URL,
                      tile: Int = 256, cutouts: Bool = false) throws {
        let models = ImageCandidate.all.filter { model in runs.contains { $0.modelID == model.id } }
        let rows = recipes.flatMap { recipe in
            models.flatMap { model in
                ImageStyle.all.map(\.id).filter { style in
                    runs.contains { $0.recipeID == recipe.id && $0.modelID == model.id && ($0.styleID ?? "cookbook") == style }
                }.map { (recipe, model, $0) }
            }
        }
        let columns = recipes.map(\.assets.count).max() ?? 0
        guard !rows.isEmpty, columns > 0,
              let context = CGContext(data: nil, width: columns * tile, height: rows.count * tile, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.setFillColor(CGColor(gray: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: columns * tile, height: rows.count * tile))
        for (rowIndex, (recipe, model, style)) in rows.enumerated() {
            for (column, asset) in recipe.assets.enumerated() {
                let y = (rows.count - 1 - rowIndex) * tile
                if cutouts {
                    let square = tile / 8
                    for row in 0..<8 {
                        for col in 0..<8 {
                            context.setFillColor(CGColor(gray: (row + col) % 2 == 0 ? 1 : 0.82, alpha: 1))
                            context.fill(CGRect(x: column * tile + col * square, y: y + row * square, width: square, height: square))
                        }
                    }
                }
                guard let run = runs.first(where: { $0.modelID == model.id && $0.assetID == asset.id && $0.imageFile != nil
                                                    && ($0.styleID ?? "cookbook") == style }),
                      let file = cutouts ? run.cutoutFile : run.imageFile,
                      let source = CGImageSourceCreateWithURL(imageDirectory.appendingPathComponent(file) as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
                context.draw(image, in: CGRect(x: column * tile, y: y, width: tile, height: tile))
            }
        }
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ImageRunnerError.encoding
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ImageRunnerError.encoding }
    }
}
