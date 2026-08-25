import AppKit

final class PetView: NSView {
    var state: PetState = .idle { didSet { needsDisplay = true } }
    var onStateChange: ((PetState) -> Void)?
    var onMinimizeRequested: (() -> Void)?
    var onBlushTapped: ((BlushSlot) -> Void)?
    private(set) var pupilOffset = NSPoint.zero
    private let minimizeButton = NSButton()
    private let leftBlushButton = NSButton()
    private let rightBlushButton = NSButton()
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
        configureBlushButton(leftBlushButton, slot: .left)
        configureBlushButton(rightBlushButton, slot: .right)
        addSubview(leftBlushButton)
        addSubview(rightBlushButton)
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
        leftBlushButton.frame = NSRect(x: bounds.midX - 52, y: 63, width: 24, height: 22)
        rightBlushButton.frame = NSRect(x: bounds.midX + 28, y: 63, width: 24, height: 22)
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
    @objc private func leftBlushPressed() { onBlushTapped?(.left) }
    @objc private func rightBlushPressed() { onBlushTapped?(.right) }

    private func configureBlushButton(_ button: NSButton, slot: BlushSlot) {
        button.isBordered = false
        button.isTransparent = true
        button.alphaValue = 0.02
        button.target = self
        button.action = slot == .left ? #selector(leftBlushPressed) : #selector(rightBlushPressed)
        button.setAccessibilityLabel("\(slot == .left ? "Left" : "Right") blush macro")
    }

    func updateBlushMacroLabels(_ settings: AppSettings) {
        leftBlushButton.toolTip = settings.leftBlushMacro.isConfigured ? settings.leftBlushMacro.name : "Configure left blush macro"
        rightBlushButton.toolTip = settings.rightBlushMacro.isConfigured ? settings.rightBlushMacro.name : "Configure right blush macro"
    }

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
        let bodyColor: NSColor = switch state { case .idle, .sleeping: NSColor(calibratedRed: 0.36, green: 0.64, blue: 0.98, alpha: 1); case .noticingDrag, .waitingForDrop: .systemOrange; case .dragAccepted, .processing: .systemPurple; case .success: .systemGreen; case .dragRejected, .failure: .systemRed }
        let cream = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.93, alpha: 1)
        let blueHighlight = bodyColor.blended(withFraction: 0.20, of: .white) ?? bodyColor

        // Rounded body, soft wings, and the three-feather tuft mirror the app icon.
        bodyColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 17, y: 23, width: 116, height: 113), xRadius: 45, yRadius: 45).fill()
        blueHighlight.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5, y: 73, width: 34, height: 53)).fill()
        NSBezierPath(ovalIn: NSRect(x: 111, y: 73, width: 34, height: 53)).fill()
        NSBezierPath(ovalIn: NSRect(x: 43, y: 3, width: 27, height: 27)).fill()
        NSBezierPath(ovalIn: NSRect(x: 61, y: 0, width: 29, height: 34)).fill()
        NSBezierPath(ovalIn: NSRect(x: 81, y: 4, width: 27, height: 27)).fill()

        // Cream face and belly.
        cream.setFill()
        NSBezierPath(ovalIn: NSRect(x: 19, y: 29, width: 112, height: 83)).fill()
        NSBezierPath(ovalIn: NSRect(x: 42, y: 88, width: 66, height: 47)).fill()

        if eyesAreOpen {
            NSColor(calibratedWhite: 1, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 29, y: 38, width: 39, height: 45)).fill()
            NSBezierPath(ovalIn: NSRect(x: 82, y: 38, width: 39, height: 45)).fill()
            NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 36 + pupilOffset.x, y: 46 + pupilOffset.y, width: 25, height: 31)).fill()
            NSBezierPath(ovalIn: NSRect(x: 89 + pupilOffset.x, y: 46 + pupilOffset.y, width: 25, height: 31)).fill()
            NSColor(calibratedRed: 0.04, green: 0.50, blue: 0.90, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 38 + pupilOffset.x, y: 63 + pupilOffset.y, width: 21, height: 14)).fill()
            NSBezierPath(ovalIn: NSRect(x: 91 + pupilOffset.x, y: 63 + pupilOffset.y, width: 21, height: 14)).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: 41 + pupilOffset.x, y: 49 + pupilOffset.y, width: 9, height: 10)).fill()
            NSBezierPath(ovalIn: NSRect(x: 94 + pupilOffset.x, y: 49 + pupilOffset.y, width: 9, height: 10)).fill()
            NSBezierPath(ovalIn: NSRect(x: 53 + pupilOffset.x, y: 63 + pupilOffset.y, width: 4, height: 5)).fill()
            NSBezierPath(ovalIn: NSRect(x: 106 + pupilOffset.x, y: 63 + pupilOffset.y, width: 4, height: 5)).fill()
        } else {
            NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.55, alpha: 1).setStroke()
            let blink = NSBezierPath(); blink.lineWidth = 3; blink.lineCapStyle = .round
            blink.move(to: NSPoint(x: 36, y: 59)); blink.line(to: NSPoint(x: 61, y: 59)); blink.move(to: NSPoint(x: 89, y: 59)); blink.line(to: NSPoint(x: 114, y: 59)); blink.stroke()
        }

        // Tiny brows, a happy beak, and the open smile from the icon.
        NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.72, alpha: 1).setStroke()
        let brows = NSBezierPath(); brows.lineWidth = 3.5; brows.lineCapStyle = .round
        brows.move(to: NSPoint(x: 38, y: 31)); brows.curve(to: NSPoint(x: 53, y: 29), controlPoint1: NSPoint(x: 42, y: 27), controlPoint2: NSPoint(x: 49, y: 27))
        brows.move(to: NSPoint(x: 97, y: 29)); brows.curve(to: NSPoint(x: 112, y: 31), controlPoint1: NSPoint(x: 101, y: 27), controlPoint2: NSPoint(x: 108, y: 27)); brows.stroke()

        NSColor.systemPink.withAlphaComponent(0.58).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 49, y: 71, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 31, y: 71, width: 18, height: 10)).fill()

        NSColor(calibratedRed: 1, green: 0.68, blue: 0.16, alpha: 1).setFill()
        let beak = NSBezierPath(); beak.move(to: NSPoint(x: bounds.midX, y: 68)); beak.curve(to: NSPoint(x: bounds.midX + 11, y: 76), controlPoint1: NSPoint(x: bounds.midX + 7, y: 68), controlPoint2: NSPoint(x: bounds.midX + 11, y: 72)); beak.curve(to: NSPoint(x: bounds.midX, y: 82), controlPoint1: NSPoint(x: bounds.midX + 7, y: 80), controlPoint2: NSPoint(x: bounds.midX + 3, y: 82)); beak.curve(to: NSPoint(x: bounds.midX - 11, y: 76), controlPoint1: NSPoint(x: bounds.midX - 3, y: 82), controlPoint2: NSPoint(x: bounds.midX - 7, y: 80)); beak.close(); beak.fill()
        NSColor(calibratedRed: 0.72, green: 0.20, blue: 0.25, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 5, y: 76, width: 10, height: 7)).fill()

        NSColor(calibratedRed: 1, green: 0.68, blue: 0.16, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 30, y: 123, width: 22, height: 15)).fill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 123, width: 22, height: 15)).fill()
        NSBezierPath(ovalIn: NSRect(x: 84, y: 123, width: 22, height: 15)).fill()
        NSBezierPath(ovalIn: NSRect(x: 98, y: 123, width: 22, height: 15)).fill()
        if state == .success { drawSparkle(at: NSPoint(x: 20, y: 30)); drawSparkle(at: NSPoint(x: bounds.maxX - 20, y: 28)) }
        if state != .idle {
            let title = state.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
            title.draw(at: NSPoint(x: 12, y: bounds.height - 28), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white])
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawSparkle(at point: NSPoint) {
        NSColor.systemYellow.setStroke()
        let sparkle = NSBezierPath(); sparkle.lineWidth = 2; sparkle.lineCapStyle = .round
        sparkle.move(to: NSPoint(x: point.x, y: point.y - 6)); sparkle.line(to: NSPoint(x: point.x, y: point.y + 6))
        sparkle.move(to: NSPoint(x: point.x - 6, y: point.y)); sparkle.line(to: NSPoint(x: point.x + 6, y: point.y)); sparkle.stroke()
    }
}
