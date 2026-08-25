import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "AnimalBuddy.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor.systemBlue.setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 250, yRadius: 250).fill()
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: 298, y: 456, width: 184, height: 236)).fill()
NSBezierPath(ovalIn: NSRect(x: 542, y: 456, width: 184, height: 236)).fill()
NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 366, y: 496, width: 84, height: 84)).fill()
NSBezierPath(ovalIn: NSRect(x: 610, y: 496, width: 84, height: 84)).fill()
image.unlockFocus()

guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render Animal Buddy icon")
}
try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
