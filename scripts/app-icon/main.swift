// Renders the App Store icon from the shared dove geometry (PLBrand/DoveGeometry.swift):
// an ivory dove in flight across a gold sun, on a midnight field ("Halo").
//
//     sh scripts/make_app_icon.sh
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let side = CGFloat(size)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat(r) / 255, CGFloat(g) / 255, CGFloat(b) / 255, a])!
}
func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("context") }
// Design coordinates are y-down.
ctx.translateBy(x: 0, y: side)
ctx.scaleBy(x: 1, y: -1)

// Warm vellum field with a soft glow, a fine gilt ring, and the dove in deep ink —
// the same look as the app's welcome and completion screens.
ctx.drawLinearGradient(gradient([rgb(246, 238, 226), rgb(233, 220, 200)], [0, 1]),
                       start: .zero, end: CGPoint(x: 0, y: side), options: [])
let center = CGPoint(x: side / 2, y: side / 2)
let radius = side * 0.36
ctx.drawRadialGradient(gradient([rgb(232, 196, 150, 0.85), rgb(232, 196, 150, 0)], [0, 1]),
                       startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
ctx.setStrokeColor(rgb(176, 140, 84, 0.8))
ctx.setLineWidth(side * 0.006)
ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

let unit = side * 0.0066
let doveRect = CGRect(x: center.x - 43.5 * unit, y: center.y - 30 * unit, width: 87 * unit, height: 60 * unit)
ctx.addPath(DoveGeometry.farWingPath(in: doveRect))
ctx.setFillColor(rgb(150, 128, 104))
ctx.fillPath()
ctx.addPath(DoveGeometry.path(in: doveRect))
ctx.setFillColor(rgb(40, 34, 30))
ctx.fillPath()

let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("image") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write") }
print("wrote \(out.path) \(size)×\(size)")
