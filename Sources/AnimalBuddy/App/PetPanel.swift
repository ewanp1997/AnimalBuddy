import AppKit

final class PetPanel: NSPanel {
    var onDragToDismiss: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragChanged: ((_ screenPoint: NSPoint, _ velocity: CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    private var lastDragPoint: NSPoint?
    private var lastDragTimestamp: TimeInterval?

    override func mouseDown(with event: NSEvent) {
        lastDragPoint = NSEvent.mouseLocation
        lastDragTimestamp = event.timestamp
        onDragBegan?()
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let currentPoint = NSEvent.mouseLocation
        let elapsed = max(event.timestamp - (lastDragTimestamp ?? event.timestamp), 0.001)
        let previousPoint = lastDragPoint ?? currentPoint
        let velocity = hypot(currentPoint.x - previousPoint.x, currentPoint.y - previousPoint.y) / elapsed
        lastDragPoint = currentPoint
        lastDragTimestamp = event.timestamp
        onDragChanged?(currentPoint, min(velocity / 1000, 1))
        guard let screen = screen ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) else { return }
        if Self.shouldDismiss(frame: frame, on: screen.visibleFrame) { onDragToDismiss?() }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        lastDragPoint = nil
        lastDragTimestamp = nil
        onDragEnded?()
    }

    static func shouldDismiss(frame: NSRect, on screenFrame: NSRect, horizontalTolerance: CGFloat = 140, verticalThreshold: CGFloat = 70) -> Bool {
        let centered = abs(frame.midX - screenFrame.midX) <= horizontalTolerance
        let nearTop = frame.maxY >= screenFrame.maxY - verticalThreshold
        let nearBottom = frame.minY <= screenFrame.minY + verticalThreshold
        return centered && (nearTop || nearBottom)
    }
}
