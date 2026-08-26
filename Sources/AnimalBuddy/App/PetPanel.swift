import AppKit

final class PetPanel: NSPanel {
    var onDraggingEntered: ((NSDraggingInfo) -> NSDragOperation)?
    var onDraggingUpdated: ((NSDraggingInfo) -> NSDragOperation)?
    var onDraggingExited: ((NSDraggingInfo?) -> Void)?
    var onPrepareForDragOperation: ((NSDraggingInfo) -> Bool)?
    var onPerformDragOperation: ((NSDraggingInfo) -> Bool)?
    var onDragBegan: (() -> Void)?
    var onDragChanged: ((_ screenPoint: NSPoint, _ velocity: CGFloat, _ deltaX: CGFloat) -> Void)?
    var onDragEnded: ((_ screenPoint: NSPoint, _ startFrame: NSRect, _ endFrame: NSRect, _ velocity: CGVector) -> Void)?

    private struct DragSample {
        let point: NSPoint
        let timestamp: TimeInterval
    }
    private var dragSamples: [DragSample] = []
    private var dragStartFrame: NSRect?

    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero

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

    func beginWindowDrag(at screenPoint: NSPoint, eventTimestamp: TimeInterval) {
        dragSamples = [DragSample(point: screenPoint, timestamp: eventTimestamp)]
        dragStartFrame = frame
        initialMouseLocation = screenPoint
        initialWindowOrigin = frame.origin
        onDragBegan?()
    }

    func continueWindowDrag(at screenPoint: NSPoint, eventTimestamp: TimeInterval) {
        let deltaX = screenPoint.x - initialMouseLocation.x
        let deltaY = screenPoint.y - initialMouseLocation.y
        let newOrigin = NSPoint(x: initialWindowOrigin.x + deltaX, y: initialWindowOrigin.y + deltaY)
        setFrameOrigin(newOrigin)

        let prevPoint = dragSamples.last?.point ?? screenPoint
        let stepDeltaX = screenPoint.x - prevPoint.x
        let stepDeltaY = screenPoint.y - prevPoint.y
        let dt = max(eventTimestamp - (dragSamples.last?.timestamp ?? eventTimestamp), 0.001)
        let speed = hypot(stepDeltaX, stepDeltaY) / CGFloat(dt)

        dragSamples.append(DragSample(point: screenPoint, timestamp: eventTimestamp))
        if dragSamples.count > 12 {
            dragSamples.removeFirst(dragSamples.count - 12)
        }
        onDragChanged?(screenPoint, min(speed / 1000, 1), stepDeltaX)
    }

    func endWindowDrag(at screenPoint: NSPoint, eventTimestamp: TimeInterval) {
        var computedVelocity = CGVector.zero
        let recent = dragSamples.filter { eventTimestamp - $0.timestamp <= 0.12 }
        if recent.count >= 2, let first = recent.first, let last = recent.last {
            let totalDt = CGFloat(max(last.timestamp - first.timestamp, 0.01))
            let vx = (last.point.x - first.point.x) / totalDt
            let vy = (last.point.y - first.point.y) / totalDt
            if eventTimestamp - last.timestamp < 0.10 {
                computedVelocity = CGVector(dx: vx, dy: vy)
            }
        }

        onDragEnded?(screenPoint, dragStartFrame ?? frame, frame, computedVelocity)
        dragSamples.removeAll()
        dragStartFrame = nil
    }

    override func mouseDown(with event: NSEvent) {
        beginWindowDrag(at: NSEvent.mouseLocation, eventTimestamp: event.timestamp)
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        continueWindowDrag(at: NSEvent.mouseLocation, eventTimestamp: event.timestamp)
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        endWindowDrag(at: NSEvent.mouseLocation, eventTimestamp: event.timestamp)
        super.mouseUp(with: event)
    }

    static func shouldDismiss(frame: NSRect, on screenFrame: NSRect, horizontalTolerance: CGFloat = 140, verticalThreshold: CGFloat = 70) -> Bool {
        let centered = abs(frame.midX - screenFrame.midX) <= horizontalTolerance
        let nearTop = frame.maxY >= screenFrame.maxY - verticalThreshold
        let nearBottom = frame.minY <= screenFrame.minY + verticalThreshold
        return centered && (nearTop || nearBottom)
    }
}
