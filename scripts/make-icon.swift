// Generates AppIcon.icns. Run via: ./scripts/make-icon.sh
import AppKit

let iconsetDir = "build/BetterFasterShorter.iconset"
try FileManager.default.createDirectory(
    atPath: iconsetDir, withIntermediateDirectories: true)

// (pixels, filename) pairs required by iconutil
let sizes: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

func render(px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let canvas = CGFloat(px)

    // Rounded-square background, inset like standard macOS app icons
    let inset = canvas * 0.098
    let rect = NSRect(x: inset, y: inset,
                      width: canvas - 2 * inset, height: canvas - 2 * inset)
    let bg = NSBezierPath(roundedRect: rect,
                          xRadius: rect.width * 0.225,
                          yRadius: rect.width * 0.225)
    NSGradient(
        starting: NSColor(calibratedRed: 0.29, green: 0.60, blue: 1.00, alpha: 1),
        ending: NSColor(calibratedRed: 0.05, green: 0.29, blue: 0.85, alpha: 1)
    )!.draw(in: bg, angle: -90)

    // White "link" symbol, centered
    guard let symbol = NSImage(systemSymbolName: "link", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: canvas * 0.5, weight: .medium))
    else { fatalError("link symbol unavailable") }

    let targetW = canvas * 0.52
    let scale = targetW / symbol.size.width
    let drawSize = NSSize(width: symbol.size.width * scale,
                          height: symbol.size.height * scale)
    let drawRect = NSRect(
        x: (canvas - drawSize.width) / 2,
        y: (canvas - drawSize.height) / 2,
        width: drawSize.width, height: drawSize.height)

    let tinted = NSImage(size: drawSize)
    tinted.lockFocus()
    symbol.draw(in: NSRect(origin: .zero, size: drawSize))
    NSColor.white.set()
    NSRect(origin: .zero, size: drawSize).fill(using: .sourceAtop)
    tinted.unlockFocus()
    tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)

    return rep
}

for (px, name) in sizes {
    let rep = render(px: px)
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name).png"))
}
print("wrote \(iconsetDir)")
