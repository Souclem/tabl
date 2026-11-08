// Dessine l'icône de « Garde-fous Tabl » (bouclier SF Symbols) dans un .iconset.
// Usage : swift icone.swift <dossier.iconset>
import AppKit

let dossier = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

func dessiner(_ taille: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: taille, pixelsHigh: taille, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let c = CGFloat(taille)
    let fond = NSBezierPath(roundedRect: NSRect(x: c * 0.1, y: c * 0.1, width: c * 0.8, height: c * 0.8),
                            xRadius: c * 0.18, yRadius: c * 0.18)
    NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.16, alpha: 1).setFill()
    fond.fill()
    let config = NSImage.SymbolConfiguration(pointSize: c * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.42, alpha: 1)]))
    if let symbole = NSImage(systemSymbolName: "checkmark.shield.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let s = symbole.size
        symbole.draw(in: NSRect(x: (c - s.width) / 2, y: (c - s.height) / 2, width: s.width, height: s.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try dessiner(base).write(to: dossier.appendingPathComponent("icon_\(base)x\(base).png"))
    try dessiner(base * 2).write(to: dossier.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
