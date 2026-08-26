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
        let loc = NSEvent.mouseLocation
        dragSamples = [DragSample(point: loc, timestamp: event.timestamp)]
        dragStartFrame = frame
        onDragBegan?()
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let currentPoint = NSEvent.mouseLocation
        let now = event.timestamp
        let prevPoint = dragSamples.last?.point ?? currentPoint
        let deltaX = currentPoint.x - prevPoint.x
        let deltaY = currentPoint.y - prevPoint.y
        let dt = max(now - (dragSamples.last?.timestamp ?? now), 0.001)
        let speed = hypot(deltaX, deltaY) / CGFloat(dt)
        
        dragSamples.append(DragSample(point: currentPoint, timestamp: now))
        if dragSamples.count > 12 {
            dragSamples.removeFirst(dragSamples.count - 12)
        }
        onDragChanged?(currentPoint, min(speed / 1000, 1), deltaX)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let currentPoint = NSEvent.mouseLocation
        let now = event.timestamp
        
        var computedVelocity = CGVector.zero
        let recent = dragSamples.filter { now - $0.timestamp <= 0.12 }
        if recent.count >= 2, let first = recent.first, let last = recent.last {
            let totalDt = CGFloat(max(last.timestamp - first.timestamp, 0.01))
            let vx = (last.point.x - first.point.x) / totalDt
            let vy = (last.point.y - first.point.y) / totalDt
            if now - last.timestamp < 0.10 {
                computedVelocity = CGVector(dx: vx, dy: vy)
            }
        }
        
        onDragEnded?(currentPoint, dragStartFrame ?? frame, frame, computedVelocity)
        dragSamples.removeAll()
        dragStartFrame = nil
    }

    static func shouldDismiss(frame: NSRect, on screenFrame: NSRect, horizontalTolerance: CGFloat = 140, verticalThreshold: CGFloat = 70) -> Bool {
        let centered = abs(frame.midX - screenFrame.midX) <= horizontalTolerance
        let nearTop = frame.maxY >= screenFrame.maxY - verticalThreshold
        let nearBottom = frame.minY <= screenFrame.minY + verticalThreshold
        return centered && (nearTop || nearBottom)
    }
}
