import AppKit
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let bounds = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill(); bounds.fill()
let shape = NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: 976, height: 976), xRadius: 218, yRadius: 218)
let gradient = NSGradient(colors: [NSColor(calibratedRed: 0.16, green: 0.13, blue: 0.32, alpha: 1), NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.09, alpha: 1)])!
gradient.draw(in: shape, angle: -70)
NSGraphicsContext.saveGraphicsState(); shape.addClip()
let glow = NSGradient(starting: NSColor(calibratedRed: 0.5, green: 0.35, blue: 1, alpha: 0.32), ending: .clear)!
glow.draw(fromCenter: NSPoint(x: 600, y: 640), radius: 0, toCenter: NSPoint(x: 600, y: 640), radius: 540, options: [])
NSGraphicsContext.restoreGraphicsState()
let ring = NSBezierPath(ovalIn: NSRect(x: 206, y: 206, width: 612, height: 612))
ring.lineWidth = 3; NSColor(calibratedRed: 0.65, green: 0.56, blue: 1, alpha: 0.23).setStroke(); ring.stroke()
let orbit = NSBezierPath(ovalIn: NSRect(x: 160, y: 160, width: 704, height: 704))
orbit.lineWidth = 1.5; NSColor(calibratedRed: 0.65, green: 0.56, blue: 1, alpha: 0.1).setStroke(); orbit.stroke()
// A moon crescent behind a sound wave, drawn as native vector paths.
let moon = NSBezierPath()
moon.appendArc(withCenter: NSPoint(x: 512, y: 535), radius: 235, startAngle: 65, endAngle: 300, clockwise: false)
moon.curve(to: NSPoint(x: 611, y: 748), controlPoint1: NSPoint(x: 435, y: 383), controlPoint2: NSPoint(x: 426, y: 681))
moon.close()
NSColor(calibratedRed: 0.69, green: 0.61, blue: 1, alpha: 0.9).setFill(); moon.fill()
let heights: [CGFloat] = [50, 95, 150, 210, 128, 270, 180, 110, 60]
for (index, height) in heights.enumerated() {
    let x = CGFloat(316 + index * 46)
    let bar = NSBezierPath(roundedRect: NSRect(x: x, y: 385 - height / 2, width: 20, height: height), xRadius: 10, yRadius: 10)
    NSColor(calibratedRed: 0.45 + CGFloat(index) * 0.025, green: 0.93, blue: 0.83, alpha: 1).setFill()
    let shadow = NSShadow(); shadow.shadowColor = NSColor(calibratedRed: 0.35, green: 0.9, blue: 0.8, alpha: 0.4); shadow.shadowBlurRadius = 22
    NSGraphicsContext.saveGraphicsState(); shadow.set(); bar.fill(); NSGraphicsContext.restoreGraphicsState()
}
let star = NSBezierPath(ovalIn: NSRect(x: 696, y: 714, width: 13, height: 13)); NSColor.white.withAlphaComponent(0.8).setFill(); star.fill()
let dot = NSBezierPath(ovalIn: NSRect(x: 760, y: 624, width: 7, height: 7)); dot.fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
