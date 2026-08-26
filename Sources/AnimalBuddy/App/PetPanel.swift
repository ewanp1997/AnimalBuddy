import AppKit

final class PetPanel: NSPanel {
    var onDraggingEntered: ((NSDraggingInfo) -> NSDragOperation)?
    var onDraggingUpdated: ((NSDraggingInfo) -> NSDragOperation)?
    var onDraggingExited: ((NSDraggingInfo?) -> Void)?
    var onPrepareForDragOperation: ((NSDraggingInfo) -> Bool)?
    var onPerformDragOperation: ((NSDraggingInfo) -> Bool)?
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

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDraggingEntered?(sender) ?? []
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDraggingUpdated?(sender) ?? []
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        onDraggingExited?(sender)
    }

    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onPrepareForDragOperation?(sender) ?? false
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onPerformDragOperation?(sender) ?? false
    }

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
