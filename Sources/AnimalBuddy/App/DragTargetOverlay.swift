import AppKit

@MainActor final class DragTargetOverlayController {
    private static let targetSize: CGFloat = 48
    private let overlayWindow: NSPanel
    private let crosshairView = DragTargetCrosshairView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))

    init() {
        overlayWindow = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 48, height: 48), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindow.contentView = crosshairView
    }

    static let visibilityRadius: CGFloat = 260

    func show(at screenPoint: NSPoint, redness: CGFloat, alpha: CGFloat = 1.0) {
        let screen = NSScreen.screens.first { $0.frame.contains(screenPoint) } ?? NSScreen.main
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame
        let center = Self.targetCenter(for: screenPoint, in: visibleFrame)
        overlayWindow.setFrameOrigin(NSPoint(x: center.x - Self.targetSize / 2, y: center.y - Self.targetSize / 2))
        overlayWindow.alphaValue = min(max(alpha, 0), 1)
        crosshairView.redness = min(max(redness, 0), 1)
        overlayWindow.orderFrontRegardless()
    }

    func hide() { overlayWindow.orderOut(nil) }

    static func targetCenter(for screenPoint: NSPoint, in visibleFrame: NSRect, inset: CGFloat = 36) -> NSPoint {
        NSPoint(x: visibleFrame.midX, y: targetCenterY(for: screenPoint.y, in: visibleFrame, inset: inset))
    }

    static func targetCenterY(for screenPointY: CGFloat, in visibleFrame: NSRect, inset: CGFloat = 36) -> CGFloat {
        screenPointY >= visibleFrame.midY ? visibleFrame.maxY - inset : visibleFrame.minY + inset
    }

    static func isWithinVisibilityRadius(for frame: NSRect, target: NSPoint, radius: CGFloat = visibilityRadius) -> Bool {
        hypot(frame.midX - target.x, frame.midY - target.y) <= radius
    }

    static func redness(for frame: NSRect, target: NSPoint, boundaryRadius: CGFloat = 100, transitionDepth: CGFloat = 24) -> CGFloat {
        let distance = hypot(frame.midX - target.x, frame.midY - target.y)
        guard distance < boundaryRadius else { return 0 }
        return min(max((boundaryRadius - distance) / transitionDepth, 0), 1)
    }
}

@MainActor final class DragTargetCrosshairView: NSView {
    var redness: CGFloat = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let circleRect = bounds.insetBy(dx: 3, dy: 3)
        NSColor.black.withAlphaComponent(0.22).setFill()
        NSBezierPath(ovalIn: circleRect.offsetBy(dx: 0, dy: -2)).fill()
        let fillColor = NSColor(calibratedRed: 0.12 + redness * 0.72, green: 0.14 - redness * 0.10, blue: 0.16 - redness * 0.10, alpha: 0.92)
        fillColor.setFill()
        NSBezierPath(ovalIn: circleRect).fill()

        NSColor.white.withAlphaComponent(0.95).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 3.5
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: 17, y: 17)); path.line(to: NSPoint(x: 31, y: 31))
        path.move(to: NSPoint(x: 31, y: 17)); path.line(to: NSPoint(x: 17, y: 31))
        path.stroke()
    }
}
