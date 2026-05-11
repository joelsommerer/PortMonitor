#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fputs("Kein Grafikkontext\n", stderr)
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)
let cornerRadius: CGFloat = size * 0.2237  // macOS app icon squircle ratio
let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

ctx.saveGState()
ctx.addPath(path)
ctx.clip()

let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(red: 0.10, green: 0.45, blue: 0.95, alpha: 1.0).cgColor,
        NSColor(red: 0.45, green: 0.25, blue: 0.90, alpha: 1.0).cgColor,
        NSColor(red: 0.75, green: 0.20, blue: 0.80, alpha: 1.0).cgColor
    ] as CFArray,
    locations: [0.0, 0.55, 1.0]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)

let glow = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(white: 1.0, alpha: 0.25).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: size * 0.3, y: size * 0.75),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.3, y: size * 0.75),
    endRadius: size * 0.5,
    options: []
)

let nodeColor = NSColor.white
let lineColor = NSColor(white: 1.0, alpha: 0.85)

let cx = size / 2
let cy = size / 2
let radius = size * 0.28
let nodeRadius = size * 0.075

let nodes: [CGPoint] = (0..<3).map { i in
    let angle = -.pi / 2 + CGFloat(i) * (2 * .pi / 3)
    return CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
}

ctx.setStrokeColor(lineColor.cgColor)
ctx.setLineWidth(size * 0.028)
ctx.setLineCap(.round)
for i in 0..<nodes.count {
    let a = nodes[i]
    let b = nodes[(i + 1) % nodes.count]
    ctx.move(to: a)
    ctx.addLine(to: b)
}
ctx.strokePath()

let centerDotRadius = size * 0.055
ctx.setFillColor(NSColor(white: 1.0, alpha: 0.55).cgColor)
ctx.fillEllipse(in: CGRect(
    x: cx - centerDotRadius,
    y: cy - centerDotRadius,
    width: centerDotRadius * 2,
    height: centerDotRadius * 2
))

for node in nodes {
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.008),
        blur: size * 0.025,
        color: NSColor(white: 0, alpha: 0.3).cgColor
    )
    ctx.setFillColor(nodeColor.cgColor)
    ctx.fillEllipse(in: CGRect(
        x: node.x - nodeRadius,
        y: node.y - nodeRadius,
        width: nodeRadius * 2,
        height: nodeRadius * 2
    ))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    let innerR = nodeRadius * 0.45
    ctx.setFillColor(NSColor(red: 0.30, green: 0.30, blue: 0.85, alpha: 1.0).cgColor)
    ctx.fillEllipse(in: CGRect(
        x: node.x - innerR,
        y: node.y - innerR,
        width: innerR * 2,
        height: innerR * 2
    ))
}

ctx.restoreGState()

let highlightPath = CGMutablePath()
let inset: CGFloat = size * 0.04
highlightPath.addRoundedRect(
    in: CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
    cornerWidth: cornerRadius - inset,
    cornerHeight: cornerRadius - inset
)
ctx.addPath(highlightPath)
ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.18).cgColor)
ctx.setLineWidth(size * 0.005)
ctx.strokePath()

image.unlockFocus()

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Konnte PNG nicht erzeugen\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
try png.write(to: outputURL)
print("✓ Icon erzeugt: \(outputURL.path)")
