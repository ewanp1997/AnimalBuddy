import AppKit

@MainActor final class DragTargetOverlayController {
    private let overlayWindow: NSPanel
    private let crosshairView = DragTargetCrosshairView(frame: NSRect(x: 0, y: 0, width: 72, height: 72))

    init() {
        overlayWindow = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 72, height: 72), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindow.contentView = crosshairView
    }

    func show(at screenPoint: NSPoint, redness: CGFloat) {
        let screen = NSScreen.screens.first { $0.frame.contains(screenPoint) } ?? NSScreen.main
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame
        let targetY = Self.targetCenterY(for: screenPoint.y, in: visibleFrame)
        let center = NSPoint(x: visibleFrame.midX, y: targetY)
        overlayWindow.setFrameOrigin(NSPoint(x: center.x - 36, y: center.y - 36))
        crosshairView.redness = min(max(redness, 0), 1)
        overlayWindow.orderFrontRegardless()
    }

    func hide() { overlayWindow.orderOut(nil) }

    static func targetCenterY(for screenPointY: CGFloat, in visibleFrame: NSRect, inset: CGFloat = 36) -> CGFloat {
        screenPointY >= visibleFrame.midY ? visibleFrame.maxY - inset : visibleFrame.minY + inset
    }
}

@MainActor final class DragTargetCrosshairView: NSView {
    var redness: CGFloat = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let color = NSColor(calibratedRed: 0.25 + redness * 0.75, green: 0.85 - redness * 0.75, blue: 0.85 - redness * 0.75, alpha: 0.9)
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 4
        path.move(to: NSPoint(x: bounds.midX, y: 10)); path.line(to: NSPoint(x: bounds.midX, y: bounds.maxY - 10))
        path.move(to: NSPoint(x: 10, y: bounds.midY)); path.line(to: NSPoint(x: bounds.maxX - 10, y: bounds.midY))
        path.stroke()
        NSColor.white.withAlphaComponent(0.8).setStroke()
        let inner = NSBezierPath(ovalIn: bounds.insetBy(dx: 22, dy: 22)); inner.lineWidth = 2; inner.stroke()
    }
}
