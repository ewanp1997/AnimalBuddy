import AppKit

final class PetPanel: NSPanel {
    var onDragToDismiss: (() -> Void)?

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard let screen = screen ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) else { return }
        if Self.shouldDismiss(frame: frame, on: screen.visibleFrame) { onDragToDismiss?() }
    }

    static func shouldDismiss(frame: NSRect, on screenFrame: NSRect, horizontalTolerance: CGFloat = 140, verticalThreshold: CGFloat = 70) -> Bool {
        let centered = abs(frame.midX - screenFrame.midX) <= horizontalTolerance
        let nearTop = frame.maxY >= screenFrame.maxY - verticalThreshold
        let nearBottom = frame.minY <= screenFrame.minY + verticalThreshold
        return centered && (nearTop || nearBottom)
    }
}
