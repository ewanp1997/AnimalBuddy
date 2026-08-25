import AppKit

final class PetView: NSView {
    var state: PetState = .idle { didSet { needsDisplay = true } }
    var onStateChange: ((PetState) -> Void)?
    private(set) var pupilOffset = NSPoint.zero
    override var isFlipped: Bool { true }

    func setPupilOffset(_ target: NSPoint, animated: Bool) {
        let bounded = Self.clampPupilOffset(target)
        if animated {
            let smoothing: CGFloat = 0.28
            pupilOffset.x += (bounded.x - pupilOffset.x) * smoothing
            pupilOffset.y += (bounded.y - pupilOffset.y) * smoothing
        } else {
            pupilOffset = bounded
        }
        needsDisplay = true
    }

    static func pupilOffset(toward point: NSPoint, from eyeCenter: NSPoint, maximum: CGFloat = 5) -> NSPoint {
        clampPupilOffset(NSPoint(x: point.x - eyeCenter.x, y: point.y - eyeCenter.y), maximum: maximum)
    }

    static func clampPupilOffset(_ offset: NSPoint, maximum: CGFloat = 5) -> NSPoint {
        let length = hypot(offset.x, offset.y)
        guard length > maximum, length > 0 else { return offset }
        let scale = maximum / length
        return NSPoint(x: offset.x * scale, y: offset.y * scale)
    }

    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor = switch state { case .idle, .sleeping: .systemBlue; case .noticingDrag, .waitingForDrop: .systemOrange; case .dragAccepted, .processing: .systemPurple; case .success: .systemGreen; case .dragRejected, .failure: .systemRed }
        color.setFill(); NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 10), xRadius: 28, yRadius: 28).fill()
        NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: bounds.midX - 24, y: 38, width: 16, height: 20)).fill(); NSBezierPath(ovalIn: NSRect(x: bounds.midX + 8, y: 38, width: 16, height: 20)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 19 + pupilOffset.x, y: 45 + pupilOffset.y, width: 7, height: 9)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 13 + pupilOffset.x, y: 45 + pupilOffset.y, width: 7, height: 9)).fill()
        let title = state.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
        title.draw(at: NSPoint(x: 12, y: bounds.height - 28), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white])
    }
}
