//
//  render_app_icon.swift
//  IDFAVault Tools
//
//  アプリアイコン（仕様書 7 章・案 B「ID / FA 2 段」）を描いて PNG に書き出す。
//  デザインの原本（AppIconsIDFA の中央の案）の寸法を 1024px に引き伸ばし、CSS のグラデーションと同じ向きで塗る。
//
//    swift Tools/render_app_icon.swift <出力先のフォルダ>
//
//  書き出すもの:
//    icon-1024.png      iOS（正方形・透明なし。角丸は OS が付ける）
//    mac-<size>.png     macOS（標準の角丸の枠に収め、外側は透明）
//    vision-back.png    visionOS の奥の層（背景。透明なし）
//    vision-front.png   visionOS の手前の層（インゴットと文字。外側は透明）
//

import AppKit
import CoreText

let size: CGFloat = 1024
/// デザインの原本は 220px の枠で描いてある
let scale = size / 220

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// グラデーションの 1 点（色・位置・不透明度）
struct Stop {
    var hex: UInt32
    var location: CGFloat
    var alpha: CGFloat = 1

    init(_ hex: UInt32, _ location: CGFloat, _ alpha: CGFloat = 1) {
        self.hex = hex
        self.location = location
        self.alpha = alpha
    }
}

func gradient(_ stops: [Stop]) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: stops.map { color($0.hex, $0.alpha) } as CFArray,
        locations: stops.map(\.location)
    )!
}

/// CSS の linear-gradient(<deg>) と同じ向きで rect を塗る
func fillLinear(_ context: CGContext, _ gradient: CGGradient, degrees: CGFloat, in rect: CGRect) {
    let radians = degrees * .pi / 180
    // CSS のグラデーションの線の長さ（角が 0% / 100% に来る長さ）
    let length = abs(rect.width * sin(radians)) + abs(rect.height * cos(radians))
    let dx = sin(radians) * length / 2
    let dy = cos(radians) * length / 2
    // CoreGraphics は y が上向き。CSS の 0deg（上向き）は +y
    let start = CGPoint(x: rect.midX - dx, y: rect.midY - dy)
    let end = CGPoint(x: rect.midX + dx, y: rect.midY + dy)
    context.drawLinearGradient(
        gradient,
        start: start,
        end: end,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

func octagon(_ rect: CGRect, chamfer: CGFloat) -> CGPath {
    let corner = min(chamfer, min(rect.width, rect.height) / 2)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
    path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
    path.closeSubpath()
    return path
}

let ingotRim = gradient([
    Stop(0xF4EFFF, 0, 1), Stop(0x9D84E0, 0.06, 1), Stop(0x2A2565, 0.18, 1), Stop(0x1F4F8C, 0.36, 1),
    Stop(0x0B0E24, 0.56, 1), Stop(0x3A2F7C, 0.74, 1), Stop(0x0A1630, 0.88, 1), Stop(0x8FC0EE, 1, 1)
])
let ingotFace = gradient([Stop(0x262C5C, 0, 1), Stop(0x121638, 0.45, 1), Stop(0x18284F, 0.70, 1), Stop(0x0A0D22, 1, 1)])
let streak = gradient([Stop(0xDCD7FF, 0.20, 0), Stop(0xDCD7FF, 0.24, 0.5), Stop(0xDCD7FF, 0.28, 0)])
let sheen = gradient([Stop(0x648CE6, 0.30, 0), Stop(0x786EE6, 0.50, 0.22), Stop(0x50AAE6, 0.62, 0.14), Stop(0x648CE6, 0.75, 0)])
let identifierMetal = gradient([
    Stop(0xFFFFFF, 0, 1), Stop(0xDFE3FB, 0.42, 1), Stop(0x9B92E6, 0.52, 1), Stop(0xA9CFF2, 0.66, 1), Stop(0xF3F6FF, 1, 1)
])

/// 背景（#07081A に、左上から #2B2F66 のにじみ）
func drawBackground(_ context: CGContext, in rect: CGRect) {
    context.setFillColor(color(0x0B0D24))
    context.fill(rect)
    // radial-gradient(70% 70% at 30% 20%, #2b2f66 0%, #0b0d24 70%)
    let center = CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY - rect.height * 0.2)
    let radius = rect.width * 0.7
    let glow = gradient([Stop(0x2B2F66, 0, 1), Stop(0x0B0D24, 0.7, 1)])
    context.drawRadialGradient(
        glow,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

/// 文字の形を返す（中央寄せ。基準線の y を渡す）
func textPath(_ text: String, font: CTFont, centerX: CGFloat, baseline: CGFloat) -> CGPath {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    let path = CGMutablePath()
    let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
    for run in runs {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for index in 0..<count {
            guard let glyph = CTFontCreatePathForGlyph(font, glyphs[index], nil) else {
                continue
            }
            let transform = CGAffineTransform(translationX: centerX - width / 2 + positions[index].x, y: baseline)
            path.addPath(glyph, transform: transform)
        }
    }
    return path
}

/// インゴット（八角形の縁と面）と「ID」「FA」の 2 段の文字。rect はインゴットの外形
func drawIngot(_ context: CGContext, in rect: CGRect, unit: CGFloat) {
    let outer = octagon(rect, chamfer: 44 * unit)
    // drop-shadow(0 14px 16px rgba(0,0,0,0.8))
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14 * unit), blur: 16 * unit, color: color(0x000000, 0.8))
    context.addPath(outer)
    context.setFillColor(color(0x0B0E24))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(outer)
    context.clip()
    fillLinear(context, ingotRim, degrees: 165, in: rect)
    context.restoreGState()

    let faceRect = rect.insetBy(dx: 8 * unit, dy: 8 * unit)
    context.saveGState()
    context.addPath(octagon(faceRect, chamfer: 40.7 * unit))
    context.clip()
    fillLinear(context, ingotFace, degrees: 155, in: faceRect)
    fillLinear(context, sheen, degrees: 112, in: faceRect)
    fillLinear(context, streak, degrees: 112, in: faceRect)
    context.restoreGState()

    // 文字: font-size 44px・line-height 0.95・太さ 800 の等幅（SF Mono Heavy）
    let fontSize = 44 * unit
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .heavy) as CTFont
    let lineHeight = fontSize * 0.95
    let capHeight = CTFontGetCapHeight(font)
    let centerY = faceRect.midY
    let lines = [("ID", centerY + lineHeight / 2), ("FA", centerY - lineHeight / 2)]
    for (text, lineCenter) in lines {
        let path = textPath(text, font: font, centerX: faceRect.midX, baseline: lineCenter - capHeight / 2)
        let bounds = path.boundingBoxOfPath
        // drop-shadow(0 2px 1px rgba(0,0,0,0.9))
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2 * unit), blur: 1 * unit, color: color(0x000000, 0.9))
        context.addPath(path)
        context.setFillColor(color(0x9B92E6))
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(path)
        context.clip()
        // 文字の行の箱ごとに、上から下へ金属のグラデーション
        let box = CGRect(x: bounds.minX, y: lineCenter - lineHeight / 2, width: bounds.width, height: lineHeight)
        fillLinear(context, identifierMetal, degrees: 180, in: box)
        context.restoreGState()
    }
}

func render(width: Int, height: Int, opaque: Bool, _ draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue
    )!
    context.interpolationQuality = .high
    draw(context)
    return context.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    do {
        try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    } catch {
        fatalError("\(path) に書き出せません: \(error)")
    }
}

let output = CommandLine.arguments.dropFirst().first ?? "."
let canvas = CGRect(x: 0, y: 0, width: size, height: size)
/// インゴットはアイコンの幅の約 68%（150 / 220）
let ingotSide = 150 * scale
let ingotRect = CGRect(x: (size - ingotSide) / 2, y: (size - ingotSide) / 2, width: ingotSide, height: ingotSide)

// iOS
let full = render(width: 1024, height: 1024, opaque: true) { context in
    drawBackground(context, in: canvas)
    drawIngot(context, in: ingotRect, unit: scale)
}
write(full, to: "\(output)/icon-1024.png")

// visionOS（奥の層は背景だけ、手前の層はインゴットと文字）
write(render(width: 1024, height: 1024, opaque: true) { drawBackground($0, in: canvas) }, to: "\(output)/vision-back.png")
write(render(width: 1024, height: 1024, opaque: false) { drawIngot($0, in: ingotRect, unit: scale) }, to: "\(output)/vision-front.png")

// macOS（1024 の枠の中の 824 の角丸の板に収める。Apple のアイコンのグリッド）
let mac = render(width: 1024, height: 1024, opaque: false) { context in
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let rounded = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: color(0x000000, 0.35))
    context.addPath(rounded)
    context.setFillColor(color(0x0B0D24))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(rounded)
    context.clip()
    drawBackground(context, in: plate)
    let unit = 824 / 220.0
    let side = 150 * unit
    drawIngot(context, in: CGRect(x: plate.midX - side / 2, y: plate.midY - side / 2, width: side, height: side), unit: unit)
    context.restoreGState()
}
for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    let resized = render(width: pixels, height: pixels, opaque: false) { context in
        context.draw(mac, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    }
    write(resized, to: "\(output)/mac-\(pixels).png")
}
print("wrote icons to \(output)")
