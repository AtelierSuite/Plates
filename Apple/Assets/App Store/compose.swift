import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let languages = ["en", "ja"]

/// Captures live in `Raw/<device>/<lang>/` and are written to `<device>/<lang>/`.
enum Device: String {
    case iPhone
    case iPad

    /// 6.5" iPhone and 13" iPad.
    var canvasSize: NSSize {
        switch self {
        case .iPhone: NSSize(width: 1242, height: 2688)
        case .iPad: NSSize(width: 2064, height: 2752)
        }
    }

    /// Text and margins are laid out for the iPhone canvas and scaled up by width.
    var scale: CGFloat { canvasSize.width / Device.iPhone.canvasSize.width }

    func rawDir(_ language: String) -> URL {
        scriptDir.appendingPathComponent("Raw").appendingPathComponent(rawValue)
            .appendingPathComponent(language)
    }

    func outDir(_ language: String) -> URL {
        scriptDir.appendingPathComponent(rawValue).appendingPathComponent(language)
    }
}

struct Copy {
    let header: String
    let caption: String
}

struct Screenshot {
    let rawName: String
    let outName: String
    /// Keyed by language code. A language without copy is skipped.
    let copy: [String: Copy]
    let gradientTop: NSColor
    let gradientBottom: NSColor
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

// Plates orange, the sage of the dish rims, terracotta, and the cooking teal.
let orange = (color(0xE8823A), color(0xB04E14))
let sage = (color(0x7FA88C), color(0x3E6650))
let terracotta = (color(0xC8613F), color(0x7E3320))
let teal = (color(0x4D8580), color(0x1E4643))

let iPhoneScreenshots: [Screenshot] = [
    Screenshot(
        rawName: "01-list",
        outName: "01-list",
        copy: [
            "en": Copy(header: "Your recipe box", caption: "Every recipe gets an icon drawn from the dish"),
            "ja": Copy(header: "あなたのレシピ帳", caption: "料理ごとに描かれたアイコンで、ひと目で探せる"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "08-ideas",
        outName: "02-ideas",
        copy: [
            "en": Copy(header: "Not sure what to cook?", caption: "Say what you feel like, and pick from five dishes"),
        ],
        gradientTop: terracotta.0, gradientBottom: terracotta.1
    ),
    Screenshot(
        rawName: "09-writing",
        outName: "03-writing",
        copy: [
            "en": Copy(header: "Recipes, written for you", caption: "Ingredients, tools, and steps, sorted on device"),
            "ja": Copy(header: "レシピを書き上げます", caption: "材料・道具・手順をデバイス上で整理"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
    Screenshot(
        rawName: "02-detail",
        outName: "04-detail",
        copy: [
            "en": Copy(header: "Everything at a glance", caption: "Time, servings, ingredients, and tools"),
            "ja": Copy(header: "ひと目でわかる", caption: "時間・人数・材料・道具をまとめて表示"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "06-ask",
        outName: "05-ask",
        copy: [
            "en": Copy(header: "Change it in your own words", caption: "Add an ingredient, or cook for more people"),
            "ja": Copy(header: "自分の言葉で変更", caption: "人数の変更も、材料の入れ替えも頼むだけ"),
        ],
        gradientTop: terracotta.0, gradientBottom: terracotta.1
    ),
    Screenshot(
        rawName: "04-steps",
        outName: "06-steps",
        copy: [
            "en": Copy(header: "Steps that say why", caption: "What to look for, and what goes wrong"),
            "ja": Copy(header: "コツまでわかる手順", caption: "目安と理由を、手順ごとに"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
    Screenshot(
        rawName: "05-cook",
        outName: "07-cook",
        copy: [
            "en": Copy(header: "One step at a time", caption: "Large type in the kitchen, with timers built in"),
            "ja": Copy(header: "手順をひとつずつ", caption: "大きな文字で、タイマーも内蔵"),
        ],
        gradientTop: teal.0, gradientBottom: teal.1
    ),
    Screenshot(
        rawName: "03-have",
        outName: "08-shopping",
        copy: [
            "en": Copy(header: "Know what to buy", caption: "Tap what you have, and the rest is your list"),
            "ja": Copy(header: "買うものがわかる", caption: "あるものをタップすると、在庫に追加"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "07-inventory",
        outName: "09-inventory",
        copy: [
            "en": Copy(header: "Keep track of your kitchen", caption: "Pick ingredients and tools by their icons"),
            "ja": Copy(header: "台所の在庫を管理", caption: "材料と道具をアイコンから選ぶだけ"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
]

let iPadScreenshots: [Screenshot] = [
    Screenshot(
        rawName: "01-list",
        outName: "01-list",
        copy: [
            "en": Copy(header: "Your recipe box", caption: "Every recipe gets an icon drawn from the dish"),
            "ja": Copy(header: "あなたのレシピ帳", caption: "料理ごとに描かれたアイコンで、ひと目で探せる"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "02-writing",
        outName: "02-writing",
        copy: [
            "en": Copy(header: "Recipes, written for you", caption: "Ingredients, tools, and steps, sorted on device"),
            "ja": Copy(header: "レシピを書き上げます", caption: "材料・道具・手順をデバイス上で整理"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
    Screenshot(
        rawName: "03-detail",
        outName: "03-detail",
        copy: [
            "en": Copy(header: "Everything at a glance", caption: "Time, servings, ingredients, and every step"),
            "ja": Copy(header: "ひと目でわかる", caption: "時間・人数・材料・手順をまとめて表示"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "06-ask",
        outName: "04-ask",
        copy: [
            "en": Copy(header: "Change it in your own words", caption: "Make it for four, without the pork"),
            "ja": Copy(header: "自分の言葉で変更", caption: "人数の変更も、材料の入れ替えも頼むだけ"),
        ],
        gradientTop: terracotta.0, gradientBottom: terracotta.1
    ),
    Screenshot(
        rawName: "05-cook",
        outName: "05-cook",
        copy: [
            "en": Copy(header: "One step at a time", caption: "Swipe through the steps, with timers built in"),
            "ja": Copy(header: "手順をひとつずつ", caption: "スワイプで進めて、タイマーも内蔵"),
        ],
        gradientTop: teal.0, gradientBottom: teal.1
    ),
    Screenshot(
        rawName: "04-have",
        outName: "06-shopping",
        copy: [
            "en": Copy(header: "Know what to buy", caption: "Tap what you have, and the rest is your list"),
            "ja": Copy(header: "買うものがわかる", caption: "あるものをタップすると、在庫に追加"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "07-inventory",
        outName: "07-inventory",
        copy: [
            "en": Copy(header: "Keep track of your kitchen", caption: "Pick ingredients and tools by their icons"),
            "ja": Copy(header: "台所の在庫を管理", caption: "材料と道具をアイコンから選ぶだけ"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
]

// MARK: - Text

/// One line of text at the largest size up to `size` that fits `maxWidth`.
struct Line {
    let text: String
    let attributes: [NSAttributedString.Key: Any]
    let font: NSFont
    let size: NSSize

    init(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, maxWidth: CGFloat) {
        var fontSize = size
        var font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        var attributes: [NSAttributedString.Key: Any] = [:]
        var lineSize = NSSize.zero
        while fontSize > 10 {
            font = NSFont.systemFont(ofSize: fontSize, weight: weight)
            attributes = [.font: font, .foregroundColor: color]
            lineSize = (text as NSString).size(withAttributes: attributes)
            if lineSize.width <= maxWidth { break }
            fontSize -= 2
        }
        self.text = text
        self.attributes = attributes
        self.font = font
        self.size = lineSize
    }

    /// Draws the line centered across `canvasWidth`, with the top of its line box at `top`.
    func draw(top: CGFloat, canvasWidth: CGFloat) {
        (text as NSString).draw(
            at: NSPoint(x: (canvasWidth - size.width) / 2, y: top - size.height),
            withAttributes: attributes
        )
    }
}

// MARK: - Device frames

func cgImage(of image: NSImage) -> CGImage {
    image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

/// Draws `raw` aspect-filled into `rect`.
func drawFilled(_ raw: CGImage, in rect: CGRect, context: CGContext) {
    let rawSize = CGSize(width: raw.width, height: raw.height)
    let scale = max(rect.width / rawSize.width, rect.height / rawSize.height)
    let drawSize = CGSize(width: rawSize.width * scale, height: rawSize.height * scale)
    context.draw(raw, in: CGRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    ))
}

let hardwareImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Hardware@2x.png"))!
let displayImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Display@2x.png"))!
let hardwareCG = cgImage(of: hardwareImage)
let displayCG = cgImage(of: displayImage)
let hardwarePixel = NSSize(width: hardwareCG.width, height: hardwareCG.height)
let displayPixel = NSSize(width: displayCG.width, height: displayCG.height)
// The display mask sits centered within the hardware frame.
let displayOrigin = NSPoint(
    x: (hardwarePixel.width - displayPixel.width) / 2,
    y: (hardwarePixel.height - displayPixel.height) / 2
)

/// The raw capture clipped by the display mask, on a hardware-sized canvas.
func maskedScreen(raw: NSImage) -> NSImage {
    let image = NSImage(size: hardwarePixel)
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let displayRect = CGRect(origin: displayOrigin, size: displayPixel)
    ctx.clip(to: displayRect, mask: displayCG)
    drawFilled(cgImage(of: raw), in: displayRect, context: ctx)
    image.unlockFocus()
    return image
}

/// The iPad bezel, as a fraction of the device's width.
let iPadBezel: CGFloat = 0.03
let iPadCornerRadius: CGFloat = 0.05
/// 13" iPad Pro screen, width over height.
let iPadScreenAspect: CGFloat = 2064 / 2752

func deviceAspect(_ device: Device) -> CGFloat {
    switch device {
    case .iPhone:
        return hardwarePixel.width / hardwarePixel.height
    case .iPad:
        let screenHeight = (1 - 2 * iPadBezel) / iPadScreenAspect
        return 1 / (screenHeight + 2 * iPadBezel)
    }
}

/// A plain iPad Pro in black, drawn rather than imaged, with the capture on its screen.
func drawiPad(raw: NSImage, in rect: NSRect) {
    let ctx = NSGraphicsContext.current!.cgContext
    let bezel = rect.width * iPadBezel
    let outerRadius = rect.width * iPadCornerRadius

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.set()
    color(0x1C1C1E).setFill()
    NSBezierPath(roundedRect: rect, xRadius: outerRadius, yRadius: outerRadius).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // A lighter edge, as the aluminium band catches the light.
    let rim = NSBezierPath(
        roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: outerRadius - 2, yRadius: outerRadius - 2
    )
    rim.lineWidth = 4
    color(0x5A5A5E).setStroke()
    rim.stroke()

    let screenRect = rect.insetBy(dx: bezel, dy: bezel)
    let screenRadius = max(outerRadius - bezel * 0.8, 0)
    ctx.saveGState()
    NSBezierPath(roundedRect: screenRect, xRadius: screenRadius, yRadius: screenRadius).addClip()
    drawFilled(cgImage(of: raw), in: screenRect, context: ctx)
    ctx.restoreGState()
}

// MARK: - Composition

func compose(_ shot: Screenshot, language: String, device: Device) -> Bool {
    guard let copy = shot.copy[language] else { return true }
    let rawURL = device.rawDir(language).appendingPathComponent("\(shot.rawName).png")
    guard let raw = NSImage(contentsOf: rawURL) else {
        print("missing raw capture: \(rawURL.path)")
        return false
    }

    let canvasSize = device.canvasSize
    let s = device.scale
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    NSGradient(starting: shot.gradientTop, ending: shot.gradientBottom)?
        .draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

    // One-line header and caption. AppKit's origin is bottom-left.
    let textWidth = canvasSize.width - 96 * s
    let header = Line(copy.header, size: 84 * s, weight: .bold, color: .white, maxWidth: textWidth)
    let caption = Line(
        copy.caption, size: 44 * s, weight: .medium,
        color: NSColor.white.withAlphaComponent(0.92), maxWidth: textWidth
    )
    let captionGap = 4 * s
    var headerTop = canvasSize.height - 96 * s
    let textBottom = headerTop - header.size.height - captionGap - caption.size.height

    // The device fills what is left below the text.
    let deviceTopMargin = 64 * s
    let deviceBottomMargin = 88 * s
    let availableHeight = textBottom - deviceTopMargin - deviceBottomMargin
    let aspect = deviceAspect(device)
    var deviceSize = NSSize(width: availableHeight * aspect, height: availableHeight)
    if deviceSize.width > canvasSize.width - 120 * s {
        deviceSize.width = canvasSize.width - 120 * s
        deviceSize.height = deviceSize.width / aspect
    }

    // The iPad leaves more room above it, so its text is centered, by the header's cap height
    // and the caption's baseline, between the top of the canvas and the top of the device.
    if device == .iPad {
        let deviceTop = deviceBottomMargin + deviceSize.height
        let capInset = header.font.ascender - header.font.capHeight
        let visualHeight = header.size.height + captionGap + caption.font.ascender - capInset
        let visualTop = (canvasSize.height + deviceTop) / 2 + visualHeight / 2
        headerTop = (visualTop + capInset).rounded()
    }
    header.draw(top: headerTop, canvasWidth: canvasSize.width)
    caption.draw(top: headerTop - header.size.height - captionGap, canvasWidth: canvasSize.width)

    let deviceRect = NSRect(
        x: ((canvasSize.width - deviceSize.width) / 2).rounded(),
        y: deviceBottomMargin,
        width: deviceSize.width,
        height: deviceSize.height
    )

    switch device {
    case .iPhone:
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 60
        shadow.shadowOffset = NSSize(width: 0, height: -24)
        shadow.set()
        hardwareImage.draw(in: deviceRect)
        NSGraphicsContext.current?.restoreGraphicsState()
        maskedScreen(raw: raw).draw(in: deviceRect)
    case .iPad:
        drawiPad(raw: raw, in: deviceRect)
    }

    image.unlockFocus()

    // Rasterize at exactly the canvas size in pixels.
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width), pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return false }
    bitmap.size = canvasSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: canvasSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { return false }
    let outDir = device.outDir(language)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let outURL = outDir.appendingPathComponent("\(shot.outName).png")
    do {
        try png.write(to: outURL)
        print("wrote \(outURL.path.replacingOccurrences(of: scriptDir.path + "/", with: ""))")
        return true
    } catch {
        print("failed to write \(outURL.path): \(error)")
        return false
    }
}

var allOK = true
for language in languages {
    for shot in iPhoneScreenshots {
        allOK = compose(shot, language: language, device: .iPhone) && allOK
    }
    for shot in iPadScreenshots {
        allOK = compose(shot, language: language, device: .iPad) && allOK
    }
}
exit(allOK ? 0 : 1)
