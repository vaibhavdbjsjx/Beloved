// Renders brand art from the shared dove geometry (PLBrand/DoveGeometry.swift):
//   icon   1024×1024  dove crossing a gold sun on midnight ("Halo")
//   header 3840×1646  App Store product-page header
//   search 1920×1280  App Store search-results asset
// Usage: art <icon|header|search> OUT.png   (see scripts/make_app_icon.sh)
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let kind = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]
let (W, H): (Int, Int) = kind == "header" ? (3840, 1646) : kind == "search" ? (1920, 1280) : (1024, 1024)
let w = CGFloat(W), h = CGFloat(H)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat(r) / 255, CGFloat(g) / 255, CGFloat(b) / 255, a])!
}
func gradient(_ c: [CGColor], _ l: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: space, colors: c as CFArray, locations: l)! }

let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: h); ctx.scaleBy(x: 1, y: -1)
ctx.drawLinearGradient(gradient([rgb(26, 36, 78), rgb(10, 14, 32)], [0, 1]), start: .zero, end: CGPoint(x: 0, y: h), options: [])

func sun(_ c: CGPoint, _ r: CGFloat) {
    ctx.drawRadialGradient(gradient([rgb(150, 118, 64, 0.32), rgb(150, 118, 64, 0)], [0, 1]),
                           startCenter: c, startRadius: r * 0.92, endCenter: c, endRadius: r * 1.45, options: [])
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)); ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(238, 207, 142), rgb(196, 150, 74)], [0, 1]),
                           start: CGPoint(x: 0, y: c.y - r), end: CGPoint(x: 0, y: c.y + r), options: [])
    ctx.restoreGState()
}
func dove(_ c: CGPoint, _ u: CGFloat) {
    let r = CGRect(x: c.x - 43.5 * u, y: c.y - 30 * u, width: 87 * u, height: 60 * u)
    ctx.addPath(DoveGeometry.farWingPath(in: r)); ctx.setFillColor(rgb(230, 214, 186)); ctx.fillPath()
    ctx.addPath(DoveGeometry.path(in: r)); ctx.setFillColor(rgb(247, 242, 232)); ctx.fillPath()
}
func line(_ s: String, _ font: String, _ size: CGFloat, _ color: CGColor, kern: CGFloat = 0) -> CTLine {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    return CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): kern]))
}
func draw(_ l: CTLine, x: CGFloat, y: CGFloat) {
    ctx.saveGState(); ctx.textMatrix = .identity
    ctx.translateBy(x: x, y: y); ctx.scaleBy(x: 1, y: -1); ctx.textPosition = .zero
    CTLineDraw(l, ctx); ctx.restoreGState()
}
func centered(_ l: CTLine, y: CGFloat) {
    draw(l, x: (w - CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))) / 2, y: y)
}
let gold = rgb(217, 183, 110), ivory = rgb(247, 242, 232), mist = rgb(196, 202, 226)

switch kind {
case "icon":
    sun(CGPoint(x: w * 0.56, y: h * 0.44), w * 0.27)
    dove(CGPoint(x: w * 0.48, y: h * 0.52), w * 0.0074)
case "header":
    sun(CGPoint(x: w * 0.73, y: h * 0.47), h * 0.30)
    dove(CGPoint(x: w * 0.70, y: h * 0.53), h * 0.0084)
    draw(line("BELOVED", "Avenir-Heavy", h * 0.042, gold, kern: h * 0.014), x: w * 0.09, y: h * 0.34)
    draw(line("A pause before the scroll.", "NewYork-Regular", h * 0.086, ivory), x: w * 0.09, y: h * 0.49)
    draw(line("Pray, read your scripture, breathe — then continue, on purpose.", "Avenir-Book", h * 0.033, mist), x: w * 0.09, y: h * 0.585)
    draw(line("Bible  ·  Quran  ·  Bhagavad Gita", "Avenir-Medium", h * 0.031, gold), x: w * 0.09, y: h * 0.665)
default:
    sun(CGPoint(x: w * 0.52, y: h * 0.37), h * 0.21)
    dove(CGPoint(x: w * 0.50, y: h * 0.41), h * 0.0056)
    centered(line("A pause before the scroll.", "NewYork-Regular", h * 0.068, ivory), y: h * 0.75)
    centered(line("Pray before you scroll  ·  Bible  ·  Quran  ·  Gita", "Avenir-Medium", h * 0.03, gold), y: h * 0.835)
}
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
print("wrote \(outPath) \(W)×\(H)")
