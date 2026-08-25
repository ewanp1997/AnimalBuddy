import AppKit

final class PetView: NSView {
    var state: PetState = .idle { didSet { needsDisplay = true } }
    var onStateChange: ((PetState) -> Void)?
    var onMinimizeRequested: (() -> Void)?
    private(set) var pupilOffset = NSPoint.zero
    private let minimizeButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var animationTimer: Timer?
    private let animationStart = Date()
    private var bobOffset: CGFloat = 0
    private var eyesAreOpen = true
    private var nextBlink = Date().addingTimeInterval(2.8)
    private var blinkEnds = Date.distantPast
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        minimizeButton.image = NSImage(systemSymbolName: "minus.circle.fill", accessibilityDescription: "Minimize Animal Buddy")
        minimizeButton.imageScaling = .scaleProportionallyUpOrDown
        minimizeButton.isBordered = false
        minimizeButton.contentTintColor = .white
        minimizeButton.target = self
        minimizeButton.action = #selector(minimizeButtonPressed)
        minimizeButton.toolTip = "Minimize Animal Buddy"
        minimizeButton.setAccessibilityLabel("Minimize Animal Buddy")
        minimizeButton.isHidden = true
        addSubview(minimizeButton)
        updateTrackingAreas()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickAnimation() }
        }
        if let animationTimer { RunLoop.main.add(animationTimer, forMode: .common) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        minimizeButton.frame = NSRect(x: bounds.maxX - 34, y: 10, width: 24, height: 24)
    }

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        if let trackingArea { addTrackingArea(trackingArea) }
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { minimizeButton.isHidden = false }
    override func mouseExited(with event: NSEvent) { minimizeButton.isHidden = true }

    @objc private func minimizeButtonPressed() { onMinimizeRequested?() }

    private func tickAnimation() {
        let now = Date()
        bobOffset = CGFloat(sin(now.timeIntervalSince(animationStart) * 1.8)) * 1.6
        if now >= nextBlink {
            blinkEnds = now.addingTimeInterval(0.12)
            nextBlink = now.addingTimeInterval(2.8 + Double.random(in: 0...2.8))
        }
        eyesAreOpen = now >= blinkEnds
        needsDisplay = true
    }

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

    /// Converts a screen-space target into the view's flipped drawing space.
    static func pupilOffset(towardScreenPoint point: NSPoint, fromScreenEyeCenter eyeCenter: NSPoint, maximum: CGFloat = 5) -> NSPoint {
        clampPupilOffset(NSPoint(x: point.x - eyeCenter.x, y: eyeCenter.y - point.y), maximum: maximum)
    }

    static func clampPupilOffset(_ offset: NSPoint, maximum: CGFloat = 5) -> NSPoint {
        let length = hypot(offset.x, offset.y)
        guard length > maximum, length > 0 else { return offset }
        let scale = maximum / length
        return NSPoint(x: offset.x * scale, y: offset.y * scale)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: bobOffset)
        transform.concat()
        let color: NSColor = switch state { case .idle, .sleeping: .systemBlue; case .noticingDrag, .waitingForDrop: .systemOrange; case .dragAccepted, .processing: .systemPurple; case .success: .systemGreen; case .dragRejected, .failure: .systemRed }
        color.setFill(); NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 10), xRadius: 28, yRadius: 28).fill()
        NSColor.systemPink.withAlphaComponent(0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 48, y: 70, width: 16, height: 9)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 32, y: 70, width: 16, height: 9)).fill()
        if eyesAreOpen {
            NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: bounds.midX - 24, y: 38, width: 16, height: 20)).fill(); NSBezierPath(ovalIn: NSRect(x: bounds.midX + 8, y: 38, width: 16, height: 20)).fill()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX - 19 + pupilOffset.x, y: 45 + pupilOffset.y, width: 7, height: 9)).fill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX + 13 + pupilOffset.x, y: 45 + pupilOffset.y, width: 7, height: 9)).fill()
        } else {
            NSColor.white.setStroke()
            let blink = NSBezierPath(); blink.lineWidth = 3; blink.lineCapStyle = .round
            blink.move(to: NSPoint(x: bounds.midX - 23, y: 48)); blink.line(to: NSPoint(x: bounds.midX - 9, y: 48))
            blink.move(to: NSPoint(x: bounds.midX + 9, y: 48)); blink.line(to: NSPoint(x: bounds.midX + 23, y: 48)); blink.stroke()
        }
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let smile = NSBezierPath(); smile.lineWidth = 2; smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: bounds.midX - 7, y: 75)); smile.curve(to: NSPoint(x: bounds.midX + 7, y: 75), controlPoint1: NSPoint(x: bounds.midX - 3, y: 82), controlPoint2: NSPoint(x: bounds.midX + 3, y: 82)); smile.stroke()
        if state == .success { drawSparkle(at: NSPoint(x: 20, y: 30)); drawSparkle(at: NSPoint(x: bounds.maxX - 20, y: 28)) }
        let title = state.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
        title.draw(at: NSPoint(x: 12, y: bounds.height - 28), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white])
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawSparkle(at point: NSPoint) {
        NSColor.systemYellow.setStroke()
        let sparkle = NSBezierPath(); sparkle.lineWidth = 2; sparkle.lineCapStyle = .round
        sparkle.move(to: NSPoint(x: point.x, y: point.y - 6)); sparkle.line(to: NSPoint(x: point.x, y: point.y + 6))
        sparkle.move(to: NSPoint(x: point.x - 6, y: point.y)); sparkle.line(to: NSPoint(x: point.x + 6, y: point.y)); sparkle.stroke()
    }
}
