import AppKit

// Renders SVGs to PNGs through the same CoreSVG path the asset catalog uses, so a preview
// shows what the app will. Each line of the list file is "input output width".
let lines = try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8).split(separator: "\n")
for line in lines {
    let parts = line.split(separator: " ")
    guard parts.count == 3, let image = NSImage(contentsOf: URL(fileURLWithPath: String(parts[0]))) else {
        print("failed: \(line)")
        continue
    }
    let width = Int(parts[2])!
    let height = Int(Double(width) * image.size.height / image.size.width)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: String(parts[1])))
}
