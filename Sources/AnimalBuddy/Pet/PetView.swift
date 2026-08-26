import AppKit

final class PetView: NSView {
    var onDraggingEntered: ((NSDraggingInfo) -> NSDragOperation)?
    var onDraggingUpdated: ((NSDraggingInfo) -> NSDragOperation)?
    var onDraggingExited: ((NSDraggingInfo?) -> Void)?
    var onPrepareForDragOperation: ((NSDraggingInfo) -> Bool)?
    var onPerformDragOperation: ((NSDraggingInfo) -> Bool)?
    var state: PetState = .idle { didSet { needsDisplay = true } }
    var onStateChange: ((PetState) -> Void)?
    var onMinimizeRequested: (() -> Void)?
    var onBlushTapped: ((BlushSlot) -> Void)?
    private var dragPresentation: DragPresentation?
    private(set) var pupilOffset = NSPoint.zero
    private let minimizeButton = NSButton()
    private let leftBlushButton = NSButton()
    private let rightBlushButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var animationTimer: Timer?
    private let animationStart = Date()
    private var bobOffset: CGFloat = 0
    private var leftWingFlap: CGFloat = 0
    private var rightWingFlap: CGFloat = 0
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

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDraggingEntered?(sender) ?? []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDraggingUpdated?(sender) ?? []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDraggingExited?(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onPrepareForDragOperation?(sender) ?? false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onPerformDragOperation?(sender) ?? false
    }

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

    func updateDragPresentation(_ presentation: DragPresentation?) {
        dragPresentation = presentation
        needsDisplay = true
    }

    private func tickAnimation() {
        let now = Date()
        let elapsed = now.timeIntervalSince(animationStart)
        bobOffset = CGFloat(sin(elapsed * 1.8)) * 1.6
        // The wings flap independently, like two tiny enthusiastic greetings.
        leftWingFlap = CGFloat(sin(elapsed * 5.1)) * 8
        rightWingFlap = CGFloat(sin(elapsed * 4.4 + 1.7)) * 8
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
        let bodyColor: NSColor = switch state { case .idle, .sleeping: NSColor(calibratedRed: 0.31, green: 0.57, blue: 0.93, alpha: 1); case .noticingDrag, .waitingForDrop: .systemOrange; case .dragAccepted, .processing: .systemPurple; case .success: .systemGreen; case .dragRejected, .failure: .systemRed }
        let cream = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.93, alpha: 1)
        let blueHighlight = bodyColor.blended(withFraction: 0.20, of: .white) ?? bodyColor

        // Rounded body, soft wings, and the three-feather tuft mirror the app icon.
        bodyColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 17, y: 23, width: 116, height: 113), xRadius: 45, yRadius: 45).fill()
        blueHighlight.setFill()
        drawWing(in: NSRect(x: 5 + leftWingFlap * 0.22, y: 73, width: 34, height: 53), angle: leftWingFlap)
        drawWing(in: NSRect(x: 111 + rightWingFlap * 0.22, y: 73, width: 34, height: 53), angle: -rightWingFlap)
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
            NSBezierPath(ovalIn: NSRect(x: 40 + pupilOffset.x, y: 48 + pupilOffset.y, width: 11, height: 13)).fill()
            NSBezierPath(ovalIn: NSRect(x: 93 + pupilOffset.x, y: 48 + pupilOffset.y, width: 11, height: 13)).fill()
            NSBezierPath(ovalIn: NSRect(x: 53 + pupilOffset.x, y: 64 + pupilOffset.y, width: 5, height: 6)).fill()
            NSBezierPath(ovalIn: NSRect(x: 106 + pupilOffset.x, y: 64 + pupilOffset.y, width: 5, height: 6)).fill()
            NSBezierPath(ovalIn: NSRect(x: 39 + pupilOffset.x, y: 65 + pupilOffset.y, width: 3, height: 4)).fill()
            NSBezierPath(ovalIn: NSRect(x: 92 + pupilOffset.x, y: 65 + pupilOffset.y, width: 3, height: 4)).fill()
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
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 49, y: 82, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 31, y: 82, width: 18, height: 10)).fill()

        NSColor(calibratedRed: 1, green: 0.68, blue: 0.16, alpha: 1).setFill()
        let beak = NSBezierPath(); beak.move(to: NSPoint(x: bounds.midX, y: 68)); beak.curve(to: NSPoint(x: bounds.midX + 11, y: 76), controlPoint1: NSPoint(x: bounds.midX + 7, y: 68), controlPoint2: NSPoint(x: bounds.midX + 11, y: 72)); beak.curve(to: NSPoint(x: bounds.midX, y: 82), controlPoint1: NSPoint(x: bounds.midX + 7, y: 80), controlPoint2: NSPoint(x: bounds.midX + 3, y: 82)); beak.curve(to: NSPoint(x: bounds.midX - 11, y: 76), controlPoint1: NSPoint(x: bounds.midX - 3, y: 82), controlPoint2: NSPoint(x: bounds.midX - 7, y: 80)); beak.close(); beak.fill()
        NSColor(calibratedRed: 0.72, green: 0.20, blue: 0.25, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 5, y: 76, width: 10, height: 7)).fill()

        NSColor(calibratedRed: 1, green: 0.68, blue: 0.16, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 30, y: 123, width: 22, height: 15)).fill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 123, width: 22, height: 15)).fill()
        NSBezierPath(ovalIn: NSRect(x: 84, y: 123, width: 22, height: 15)).fill()
        NSBezierPath(ovalIn: NSRect(x: 98, y: 123, width: 22, height: 15)).fill()
        if let dragPresentation { drawDragPresentation(dragPresentation) }
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

    private func drawWing(in frame: NSRect, angle: CGFloat) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()
        NSBezierPath(ovalIn: frame).fill()
        context.restoreGraphicsState()
    }

    private func drawDragPresentation(_ presentation: DragPresentation) {
        switch presentation.prop {
        case .cameraAndSDCard:
            NSColor(calibratedWhite: 0.18, alpha: 0.96).setFill()
            NSBezierPath(roundedRect: NSRect(x: 3, y: 94, width: 30, height: 21), xRadius: 5, yRadius: 5).fill()
            NSColor(calibratedRed: 0.28, green: 0.67, blue: 0.95, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 12, y: 99, width: 11, height: 11)).fill()
            NSColor.white.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: NSRect(x: 8, y: 96, width: 8, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
            NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.18, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 119, y: 96, width: 15, height: 24), xRadius: 2, yRadius: 2).fill()
            NSColor(calibratedRed: 0.20, green: 0.36, blue: 0.66, alpha: 1).setFill()
            for index in 0..<3 { NSBezierPath(rect: NSRect(x: 122 + CGFloat(index) * 3.5, y: 99, width: 2, height: 7)).fill() }
        case .envelopeAndLink:
            drawEnvelope(at: NSPoint(x: 3, y: 98))
            NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.22, alpha: 1).setStroke()
            let link = NSBezierPath(); link.lineWidth = 3; link.lineCapStyle = .round
            link.move(to: NSPoint(x: 117, y: 105)); link.curve(to: NSPoint(x: 130, y: 105), controlPoint1: NSPoint(x: 121, y: 99), controlPoint2: NSPoint(x: 127, y: 99)); link.stroke()
        case .storageBox:
            NSColor(calibratedRed: 0.76, green: 0.48, blue: 0.24, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 96, width: 30, height: 24), xRadius: 4, yRadius: 4).fill()
            NSColor(calibratedRed: 0.94, green: 0.68, blue: 0.32, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: 2, y: 96, width: 30, height: 7)).fill()
            NSColor(calibratedRed: 0.96, green: 0.80, blue: 0.42, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 12, y: 99, width: 10, height: 3), xRadius: 1, yRadius: 1).fill()
        case .document:
            NSColor.white.withAlphaComponent(0.96).setFill()
            let document = NSBezierPath(); document.move(to: NSPoint(x: 4, y: 96)); document.line(to: NSPoint(x: 25, y: 96)); document.line(to: NSPoint(x: 31, y: 102)); document.line(to: NSPoint(x: 31, y: 120)); document.line(to: NSPoint(x: 4, y: 120)); document.close(); document.fill()
            NSColor(calibratedRed: 0.31, green: 0.57, blue: 0.93, alpha: 1).setStroke()
            let lines = NSBezierPath(); lines.lineWidth = 2; lines.move(to: NSPoint(x: 9, y: 106)); lines.line(to: NSPoint(x: 25, y: 106)); lines.move(to: NSPoint(x: 9, y: 112)); lines.line(to: NSPoint(x: 22, y: 112)); lines.stroke()
        case .questionMark:
            NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 5, y: 97, width: 24, height: 24)).fill()
            NSColor(calibratedRed: 0.26, green: 0.30, blue: 0.48, alpha: 1).setFill()
            let question = "?" as NSString
            question.draw(at: NSPoint(x: 12, y: 99), withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)])
        }
        drawActionAccent(presentation.actionTitle)
    }

    private func drawEnvelope(at origin: NSPoint) {
        NSColor.white.withAlphaComponent(0.96).setFill()
        NSBezierPath(roundedRect: NSRect(x: origin.x, y: origin.y, width: 31, height: 21), xRadius: 4, yRadius: 4).fill()
        NSColor(calibratedRed: 0.31, green: 0.57, blue: 0.93, alpha: 1).setStroke()
        let fold = NSBezierPath(); fold.lineWidth = 2; fold.move(to: NSPoint(x: origin.x + 3, y: origin.y + 18)); fold.line(to: NSPoint(x: origin.x + 15.5, y: origin.y + 8)); fold.line(to: NSPoint(x: origin.x + 28, y: origin.y + 18)); fold.stroke()
    }

    private func drawActionAccent(_ title: String?) {
        guard let title, !title.isEmpty else { return }
        let accent = NSColor.black.withAlphaComponent(0.48)
        accent.setFill()
        NSBezierPath(roundedRect: NSRect(x: 44, y: 112, width: 62, height: 15), xRadius: 7, yRadius: 7).fill()
        let shortTitle = String(title.prefix(11))
        (shortTitle as NSString).draw(at: NSPoint(x: 49, y: 114), withAttributes: [.font: NSFont.systemFont(ofSize: 8, weight: .semibold), .foregroundColor: NSColor.white])
    }
}
