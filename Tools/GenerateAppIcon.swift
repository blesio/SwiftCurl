import AppKit
import CoreGraphics
import Foundation
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceArtwork = root.appending(path: "curl icon.png")
let resources = root.appending(path: "Resources", directoryHint: .isDirectory)
let iconset = resources.appending(path: "AppIcon.iconset", directoryHint: .isDirectory)
let source = resources.appending(path: "AppIcon-1024.png")

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

guard let imageSource = CGImageSourceCreateWithURL(sourceArtwork as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
    fatalError("Could not read \(sourceArtwork.path)")
}

let sourceWidth = sourceImage.width
let sourceHeight = sourceImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
var sourcePixels = [UInt8](repeating: 0, count: sourceWidth * sourceHeight * 4)

guard let sourceContext = CGContext(
    data: &sourcePixels,
    width: sourceWidth,
    height: sourceHeight,
    bitsPerComponent: 8,
    bytesPerRow: sourceWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create source context")
}

sourceContext.interpolationQuality = .high
sourceContext.draw(sourceImage, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))

var artworkPixels = [UInt8](repeating: 0, count: sourcePixels.count)
var minX = sourceWidth
var minY = sourceHeight
var maxX = 0
var maxY = 0

for y in 0..<sourceHeight {
    for x in 0..<sourceWidth {
        let offset = (y * sourceWidth + x) * 4
        let red = sourcePixels[offset]
        let green = sourcePixels[offset + 1]
        let blue = sourcePixels[offset + 2]

        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let saturation = Int(maxChannel) - Int(minChannel)

        // The supplied PNG has a checkerboard background baked in. The background is
        // neutral gray/white, while the logo has blue/teal chroma.
        let isArtwork = saturation > 14 && maxChannel < 248

        if isArtwork {
            artworkPixels[offset] = red
            artworkPixels[offset + 1] = green
            artworkPixels[offset + 2] = blue
            artworkPixels[offset + 3] = 255
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
}

guard minX <= maxX, minY <= maxY else {
    fatalError("Could not isolate artwork from \(sourceArtwork.path)")
}

guard let artworkContext = CGContext(
    data: &artworkPixels,
    width: sourceWidth,
    height: sourceHeight,
    bitsPerComponent: 8,
    bytesPerRow: sourceWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let artworkImage = artworkContext.makeImage() else {
    fatalError("Could not create transparent artwork")
}

let cropRect = CGRect(
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1
)

guard let croppedArtwork = artworkImage.cropping(to: cropRect) else {
    fatalError("Could not crop artwork")
}

let iconSize = 1024
var iconPixels = [UInt8](repeating: 0, count: iconSize * iconSize * 4)

guard let iconContext = CGContext(
    data: &iconPixels,
    width: iconSize,
    height: iconSize,
    bitsPerComponent: 8,
    bytesPerRow: iconSize * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create icon context")
}

iconContext.interpolationQuality = .high
iconContext.clear(CGRect(x: 0, y: 0, width: iconSize, height: iconSize))

let maxArtworkWidth: CGFloat = 820
let maxArtworkHeight: CGFloat = 545
let scale = min(maxArtworkWidth / CGFloat(croppedArtwork.width), maxArtworkHeight / CGFloat(croppedArtwork.height))
let drawWidth = CGFloat(croppedArtwork.width) * scale
let drawHeight = CGFloat(croppedArtwork.height) * scale
let drawRect = CGRect(
    x: (CGFloat(iconSize) - drawWidth) / 2,
    y: (CGFloat(iconSize) - drawHeight) / 2,
    width: drawWidth,
    height: drawHeight
)

iconContext.draw(croppedArtwork, in: drawRect)

guard let iconImage = iconContext.makeImage(),
      let destination = CGImageDestinationCreateWithURL(source as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Could not create app icon PNG")
}

CGImageDestinationAddImage(destination, iconImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write app icon PNG")
}

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, pixelSize) in sizes {
    let output = iconset.appending(path: name)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = ["-z", "\(pixelSize)", "\(pixelSize)", source.path, "--out", output.path]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try task.run()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else {
        fatalError("sips failed for \(name)")
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appending(path: "AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed")
}
