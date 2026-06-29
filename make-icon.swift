#!/usr/bin/swift
import Cocoa

let iconsetDir = "AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16",       16), ("icon_16x16@2x",    32),
    ("icon_32x32",       32), ("icon_32x32@2x",    64),
    ("icon_128x128",    128), ("icon_128x128@2x", 256),
    ("icon_256x256",    256), ("icon_256x256@2x", 512),
    ("icon_512x512",    512), ("icon_512x512@2x", 1024),
]

for (name, size) in specs {
    let s = CGFloat(size)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: s, height: s)

    // Dark rounded background
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)
    NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1).setFill()
    path.fill()

    // White mouse symbol
    var cfg = NSImage.SymbolConfiguration(pointSize: s * 0.58, weight: .medium)
    cfg = cfg.applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) {
        let r = NSRect(x: (s - sym.size.width) / 2,
                       y: (s - sym.size.height) / 2,
                       width: sym.size.width, height: sym.size.height)
        sym.draw(in: r)
    }

    NSGraphicsContext.restoreGraphicsState()

    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name).png"))
    print("✓ \(name).png")
}

print("Done. Run: iconutil -c icns \(iconsetDir) -o AppIcon.icns")
