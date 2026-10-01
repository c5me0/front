#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Run from apps/flutter. Artwork is exported from Figma; no fonts are required.
let app = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let brand = app.deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("design-system/brand")

func failure(_ message: String) -> NSError {
    NSError(domain: "cameo.icons", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

func load(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw failure("Cannot read artwork: \(url.lastPathComponent)")
    }
    return image
}

func render(_ source: CGImage, size: Int, at rect: CGRect? = nil,
            opaque: Bool = false, to url: URL) throws {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: size, height: size,
              bitsPerComponent: 8, bytesPerRow: 0, space: space,
              bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue) else {
        throw failure("Cannot allocate icon canvas")
    }
    if opaque {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    context.interpolationQuality = .high
    context.draw(source, in: rect ?? CGRect(x: 0, y: 0, width: size, height: size))
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw failure("Cannot write icon: \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw failure("PNG export failed") }
}

do {
    let icon = try load(brand.appendingPathComponent("cameo-icon-figma-1024.png"))
    let wordmark = try load(brand.appendingPathComponent("cameo-wordmark-white.png"))
    guard icon.width == 1024 && icon.height == 1024 else { throw failure("The master must be 1024 × 1024") }
    try render(icon, size: 1024, opaque: true, to: brand.appendingPathComponent("cameo-icon-1024.png"))

    let catalog = app.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
    let data = try Data(contentsOf: catalog.appendingPathComponent("Contents.json"))
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let images = json["images"] as? [[String: String]] else { throw failure("Invalid AppIcon catalog") }
    var written = Set<String>()
    for item in images {
        guard let name = item["filename"], let size = item["size"], let scale = item["scale"],
              let points = Double(size.split(separator: "x")[0]),
              let multiplier = Double(scale.replacingOccurrences(of: "x", with: "")) else {
            throw failure("Invalid icon slot")
        }
        if written.insert(name).inserted {
            try render(icon, size: Int((points * multiplier).rounded()), opaque: true, to: catalog.appendingPathComponent(name))
        }
    }
    let res = app.appendingPathComponent("android/app/src/main/res")
    for (density, size, foregroundSize) in [("mdpi",48,108),("hdpi",72,162),("xhdpi",96,216),("xxhdpi",144,324),("xxxhdpi",192,432)] {
        try render(icon, size: size, to: res.appendingPathComponent("mipmap-\(density)/ic_launcher.png"))
        // Android exposes the central 72 dp of its 108 dp adaptive layer.
        // Preserve the original 230/300 wordmark proportion inside that area.
        let width = Double(foregroundSize) * (230.0 / 300.0) * (72.0 / 108.0)
        let height = width * Double(wordmark.height) / Double(wordmark.width)
        let rect = CGRect(x: (Double(foregroundSize) - width) / 2,
                          y: (Double(foregroundSize) - height) / 2, width: width, height: height)
        try render(wordmark, size: foregroundSize, at: rect,
                   to: res.appendingPathComponent("drawable-\(density)/cameo_launcher_foreground.png"))
    }
    print("Generated \(written.count) iOS icons, Android legacy/adaptive icons, and the opaque 1024 × 1024 master.")
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
