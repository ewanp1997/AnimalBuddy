import AppKit

final class PetPanel: NSPanel {
    var onDragBegan: (() -> Void)?
    var onDragChanged: ((_ screenPoint: NSPoint, _ velocity: CGFloat) -> Void)?
    var onDragEnded: ((_ screenPoint: NSPoint, _ startFrame: NSRect, _ endFrame: NSRect) -> Void)?
    private var lastDragPoint: NSPoint?
    private var lastDragTimestamp: TimeInterval?
    private var dragStartFrame: NSRect?

    // The buddy should float above windows without becoming the active app or
    // taking keyboard focus away from the app the user is working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        lastDragPoint = NSEvent.mouseLocation
        lastDragTimestamp = event.timestamp
        dragStartFrame = frame
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
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let currentPoint = NSEvent.mouseLocation
        onDragEnded?(currentPoint, dragStartFrame ?? frame, frame)
        lastDragPoint = nil
        lastDragTimestamp = nil
        dragStartFrame = nil
    }

    static func shouldDismiss(frame: NSRect, on screenFrame: NSRect, horizontalTolerance: CGFloat = 140, verticalThreshold: CGFloat = 70) -> Bool {
        let centered = abs(frame.midX - screenFrame.midX) <= horizontalTolerance
        let nearTop = frame.maxY >= screenFrame.maxY - verticalThreshold
        let nearBottom = frame.minY <= screenFrame.minY + verticalThreshold
        return centered && (nearTop || nearBottom)
    }
}
