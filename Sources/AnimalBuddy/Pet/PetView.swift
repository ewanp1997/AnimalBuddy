import AppKit

final class MacroBlushButton: NSButton {
    private var isDragging = false
    private var mouseDownLocation: NSPoint = .zero
    private let dragThreshold: CGFloat = 3.0

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self)
        addTrackingArea(tracking)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.pop()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        mouseDownLocation = NSEvent.mouseLocation
        if let panel = window as? PetPanel {
            panel.beginWindowDrag(at: mouseDownLocation, eventTimestamp: event.timestamp)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let currentLoc = NSEvent.mouseLocation
        let distance = hypot(currentLoc.x - mouseDownLocation.x, currentLoc.y - mouseDownLocation.y)
        if distance > dragThreshold {
            isDragging = true
        }
        if let panel = window as? PetPanel {
            panel.continueWindowDrag(at: currentLoc, eventTimestamp: event.timestamp)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let panel = window as? PetPanel {
            panel.endWindowDrag(at: NSEvent.mouseLocation, eventTimestamp: event.timestamp)
        }
        if !isDragging {
            if let target, let action {
                NSApp.sendAction(action, to: target, from: self)
            }
        }
        isDragging = false
    }
}

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
    var animalKind: AnimalKind = .bird {
        didSet {
            needsLayout = true
            needsDisplay = true
        }
    }
    var themePalette: PetThemePalette = AnimalKind.bird.defaultPalette(for: .classic) {
        didSet { needsDisplay = true }
    }
    var themePreset: PetThemePreset = .classic {
        didSet { needsDisplay = true }
    }
    private var dragPresentation: DragPresentation?
    private var isDragHovering = false
    private(set) var pupilOffset = NSPoint.zero
    private let minimizeButton = NSButton()
    private let leftBlushButton = MacroBlushButton()
    private let rightBlushButton = MacroBlushButton()
    private var trackingArea: NSTrackingArea?
    private var animationTimer: Timer?
    private let animationStart = Date()
    private var bobOffset: CGFloat = 0
    private var leftWingFlap: CGFloat = 0
    private var rightWingFlap: CGFloat = 0
    private var eyesAreOpen = true
    private var nextBlink = Date().addingTimeInterval(2.8)
    private var blinkEnds = Date.distantPast
    private(set) var isFlying = false
    private var flightIntensity: CGFloat = 0
    private var flightTiltAngle: CGFloat = 0
    private var targetFlightTilt: CGFloat = 0
    private var lastMovementTime = Date()
    private var lastTickTime = Date()
    private var wingPhase: Double = 0
    private var idleLeftWingPhase: Double = 0
    private var idleRightWingPhase: Double = 1.7
    private var bobPhase: Double = 0
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
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
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
        switch animalKind {
        case .bird:
            leftBlushButton.frame = NSRect(x: bounds.midX - 53, y: 42, width: 48, height: 44)
            rightBlushButton.frame = NSRect(x: bounds.midX + 5, y: 42, width: 48, height: 44)
        case .dog:
            leftBlushButton.frame = NSRect(x: bounds.midX - 59, y: 38, width: 54, height: 50)
            rightBlushButton.frame = NSRect(x: bounds.midX + 5, y: 38, width: 54, height: 50)
        case .cat:
            leftBlushButton.frame = NSRect(x: bounds.midX - 55, y: 38, width: 50, height: 48)
            rightBlushButton.frame = NSRect(x: bounds.midX + 5, y: 38, width: 50, height: 48)
        case .monkey:
            leftBlushButton.frame = NSRect(x: bounds.midX - 59, y: 40, width: 54, height: 48)
            rightBlushButton.frame = NSRect(x: bounds.midX + 5, y: 40, width: 54, height: 48)
        case .giraffe:
            leftBlushButton.frame = NSRect(x: bounds.midX - 51, y: 26, width: 48, height: 56)
            rightBlushButton.frame = NSRect(x: bounds.midX + 3, y: 26, width: 48, height: 56)
        case .slinky:
            leftBlushButton.frame = NSRect(x: bounds.midX - 51, y: 36, width: 48, height: 52)
            rightBlushButton.frame = NSRect(x: bounds.midX + 3, y: 36, width: 48, height: 52)
        }
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(leftBlushButton.frame, cursor: .pointingHand)
        addCursorRect(rightBlushButton.frame, cursor: .pointingHand)
        addCursorRect(minimizeButton.frame, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        if let trackingArea { addTrackingArea(trackingArea) }
        super.updateTrackingAreas()
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        if !minimizeButton.isHidden && minimizeButton.frame.contains(point) {
            return minimizeButton
        }
        if leftBlushButton.frame.contains(point) {
            return leftBlushButton
        }
        if rightBlushButton.frame.contains(point) {
            return rightBlushButton
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        if let panel = window as? PetPanel {
            panel.beginWindowDrag(at: NSEvent.mouseLocation, eventTimestamp: event.timestamp)
        } else {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if let panel = window as? PetPanel {
            panel.continueWindowDrag(at: NSEvent.mouseLocation, eventTimestamp: event.timestamp)
        } else {
            super.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let panel = window as? PetPanel {
            panel.endWindowDrag(at: NSEvent.mouseLocation, eventTimestamp: event.timestamp)
        } else {
            super.mouseUp(with: event)
        }
    }

    override func mouseEntered(with event: NSEvent) { minimizeButton.isHidden = false }
    override func mouseExited(with event: NSEvent) { minimizeButton.isHidden = true }

    @objc private func minimizeButtonPressed() { onMinimizeRequested?() }
    @objc private func leftBlushPressed() { onBlushTapped?(.left) }
    @objc private func rightBlushPressed() { onBlushTapped?(.right) }

    private func configureBlushButton(_ button: NSButton, slot: BlushSlot) {
        button.isBordered = false
        button.isTransparent = true
        button.target = self
        button.action = slot == .left ? #selector(leftBlushPressed) : #selector(rightBlushPressed)
        button.setAccessibilityLabel("\(slot == .left ? "Left" : "Right") macro trigger")
    }

    func updateBlushMacroLabels(_ settings: AppSettings) {
        leftBlushButton.toolTip = settings.leftBlushMacro.isConfigured ? settings.leftBlushMacro.name : "Configure left blush macro"
        rightBlushButton.toolTip = settings.rightBlushMacro.isConfigured ? settings.rightBlushMacro.name : "Configure right blush macro"
    }

    func updateDragPresentation(_ presentation: DragPresentation?) {
        dragPresentation = presentation
        needsDisplay = true
    }

    func setDragHovering(_ hovering: Bool) {
        isDragHovering = hovering
        needsDisplay = true
    }

    func setFlying(_ flying: Bool) {
        isFlying = flying
        if !flying {
            targetFlightTilt = 0
        }
        needsDisplay = true
    }

    func updateFlightMovement(velocity: CGFloat, deltaX: CGFloat) {
        isFlying = true
        let tilt = max(min(deltaX * 1.8, 22), -22)
        targetFlightTilt = tilt
        lastMovementTime = Date()
        needsDisplay = true
    }

    private func tickAnimation() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTickTime), 0.001), 0.05)
        lastTickTime = now
        
        let targetIntensity: CGFloat = isFlying ? 1.0 : 0.0
        let intensitySmoothing: CGFloat = isFlying ? 0.22 : 0.08
        flightIntensity += (targetIntensity - flightIntensity) * intensitySmoothing
        
        flightTiltAngle += (targetFlightTilt - flightTiltAngle) * 0.18
        
        let flightFlapSpeed: Double = 18.0 + Double(flightIntensity) * 6.0
        wingPhase += dt * flightFlapSpeed
        idleLeftWingPhase += dt * 5.1
        idleRightWingPhase += dt * 4.4
        bobPhase += dt * 1.8
        
        if flightIntensity > 0.01 {
            let flapAmplitude: CGFloat = 34.0 * flightIntensity + 8.0 * (1.0 - flightIntensity)
            let wingCycle = CGFloat(sin(wingPhase))
            let idleLeft = CGFloat(sin(idleLeftWingPhase)) * 8
            let idleRight = CGFloat(sin(idleRightWingPhase)) * 8
            
            leftWingFlap = wingCycle * flapAmplitude * flightIntensity + idleLeft * (1.0 - flightIntensity)
            rightWingFlap = wingCycle * flapAmplitude * flightIntensity + idleRight * (1.0 - flightIntensity)
            
            let flightBob = CGFloat(sin(wingPhase)) * 3.5 * flightIntensity
            let idleBob = CGFloat(sin(bobPhase)) * 1.6 * (1.0 - flightIntensity)
            if animalKind == .slinky {
                let slinkyBounce = CGFloat(sin(wingPhase * 1.1)) * 6.5 * flightIntensity
                let idleSlinkyBob = CGFloat(sin(bobPhase * 1.4)) * 2.5 * (1.0 - flightIntensity)
                bobOffset = idleSlinkyBob + slinkyBounce
            } else {
                bobOffset = idleBob + flightBob
            }
            
            if isFlying && now.timeIntervalSince(lastMovementTime) > 0.12 {
                targetFlightTilt *= 0.88
            }
        } else {
            if animalKind == .slinky {
                bobOffset = CGFloat(sin(bobPhase * 1.4)) * 2.5
            } else {
                bobOffset = CGFloat(sin(bobPhase)) * 1.6
            }
            leftWingFlap = CGFloat(sin(idleLeftWingPhase)) * 8
            rightWingFlap = CGFloat(sin(idleRightWingPhase)) * 8
            flightTiltAngle = 0
        }
        
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
        NSGraphicsContext.current?.shouldAntialias = true
        let designSize: CGFloat = 150
        let scale = min(bounds.width / designSize, bounds.height / designSize)
        if isDragHovering {
            let glowContext = NSGraphicsContext.current
            glowContext?.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = NSColor(calibratedRed: 0.28, green: 0.62, blue: 1, alpha: 0.72)
            glow.shadowBlurRadius = 18
            glow.shadowOffset = .zero
            glow.set()
            NSColor(calibratedRed: 0.30, green: 0.64, blue: 1, alpha: 0.20).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 12, dy: 12), xRadius: 48, yRadius: 48).fill()
            glowContext?.restoreGraphicsState()
        }
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: bounds.midY)
        transform.scaleX(by: scale, yBy: scale)
        transform.translateX(by: -designSize / 2, yBy: -designSize / 2)
        transform.translateX(by: 0, yBy: bobOffset)
        if abs(flightTiltAngle) > 0.1 && animalKind != .slinky {
            transform.translateX(by: designSize / 2, yBy: designSize / 2)
            transform.rotate(byDegrees: flightTiltAngle)
            transform.translateX(by: -designSize / 2, yBy: -designSize / 2)
        }
        transform.concat()
        drawCreatureShadow()
        let defaultBodyColor = themePalette.bodyColor.nsColor
        let bodyColor: NSColor = switch state { case .idle, .sleeping: defaultBodyColor; case .noticingDrag, .waitingForDrop: .systemOrange; case .dragAccepted, .processing: .systemPurple; case .success: .systemGreen; case .dragRejected, .failure: .systemRed }
        let bellyColor = themePalette.bellyColor.nsColor
        let accentColor = themePalette.beakColor.nsColor

        switch animalKind {
        case .bird:
            drawBird(bodyColor: bodyColor, bellyColor: bellyColor, accentColor: accentColor)
        case .dog:
            drawDog(bodyColor: bodyColor, bellyColor: bellyColor, accentColor: accentColor)
        case .cat:
            drawCat(bodyColor: bodyColor, bellyColor: bellyColor, accentColor: accentColor)
        case .monkey:
            drawMonkey(bodyColor: bodyColor, bellyColor: bellyColor, accentColor: accentColor)
        case .giraffe:
            drawGiraffe(bodyColor: bodyColor, bellyColor: bellyColor, accentColor: accentColor)
        case .slinky:
            drawSlinky(bodyColor: bodyColor, bellyColor: bellyColor, accentColor: accentColor)
        }

        drawRimHighlight()
        if flightIntensity > 0.25 { drawFlightBreeze(intensity: flightIntensity) }
        if let dragPresentation { drawDragPresentation(dragPresentation) }
        if state == .success { drawSparkle(at: NSPoint(x: 20, y: 30)); drawSparkle(at: NSPoint(x: bounds.maxX - 20, y: 28)) }
        if state != .idle {
            let title = state.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
            title.draw(at: NSPoint(x: 12, y: bounds.height - 28), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white])
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawBird(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        let highlight = bodyColor.blended(withFraction: 0.20, of: .white) ?? bodyColor

        bodyColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 17, y: 23, width: 116, height: 113), xRadius: 45, yRadius: 45).fill()
        highlight.setFill()
        drawWing(in: NSRect(x: 5 + leftWingFlap * 0.22, y: 73, width: 34, height: 53), angle: leftWingFlap, isLeft: true)
        drawWing(in: NSRect(x: 111 - rightWingFlap * 0.22, y: 73, width: 34, height: 53), angle: -rightWingFlap, isLeft: false)
        drawBirdFeathers(color: bodyColor.withAlphaComponent(0.32))
        NSBezierPath(ovalIn: NSRect(x: 43, y: 3, width: 27, height: 27)).fill()
        NSBezierPath(ovalIn: NSRect(x: 61, y: 0, width: 29, height: 34)).fill()
        NSBezierPath(ovalIn: NSRect(x: 81, y: 4, width: 27, height: 27)).fill()

        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 19, y: 29, width: 112, height: 83)).fill()
        NSBezierPath(ovalIn: NSRect(x: 42, y: 88, width: 66, height: 47)).fill()

        drawStandardEyes(leftEyeRect: NSRect(x: 29, y: 38, width: 39, height: 45), rightEyeRect: NSRect(x: 82, y: 38, width: 39, height: 45))

        NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.72, alpha: 1).setStroke()
        let brows = NSBezierPath(); brows.lineWidth = 3.5; brows.lineCapStyle = .round
        brows.move(to: NSPoint(x: 38, y: 31)); brows.curve(to: NSPoint(x: 53, y: 29), controlPoint1: NSPoint(x: 42, y: 27), controlPoint2: NSPoint(x: 49, y: 27))
        brows.move(to: NSPoint(x: 97, y: 29)); brows.curve(to: NSPoint(x: 112, y: 31), controlPoint1: NSPoint(x: 101, y: 27), controlPoint2: NSPoint(x: 108, y: 27)); brows.stroke()

        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 49, y: 82, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 31, y: 82, width: 18, height: 10)).fill()

        accentColor.setFill()
        let beak = NSBezierPath(); beak.move(to: NSPoint(x: bounds.midX, y: 68)); beak.curve(to: NSPoint(x: bounds.midX + 11, y: 76), controlPoint1: NSPoint(x: bounds.midX + 7, y: 68), controlPoint2: NSPoint(x: bounds.midX + 11, y: 72)); beak.curve(to: NSPoint(x: bounds.midX, y: 82), controlPoint1: NSPoint(x: bounds.midX + 7, y: 80), controlPoint2: NSPoint(x: bounds.midX + 3, y: 82)); beak.curve(to: NSPoint(x: bounds.midX - 11, y: 76), controlPoint1: NSPoint(x: bounds.midX - 3, y: 82), controlPoint2: NSPoint(x: bounds.midX - 7, y: 80)); beak.close(); beak.fill()
        NSColor(calibratedRed: 0.72, green: 0.20, blue: 0.25, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 5, y: 76, width: 10, height: 7)).fill()
        NSColor.white.withAlphaComponent(0.38).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 4, y: 77, width: 4, height: 2)).fill()

        accentColor.setFill()
        let feetTuck = flightIntensity * 6.0
        NSBezierPath(ovalIn: NSRect(x: 30, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 84, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 98, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()
    }

    private func drawDog(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        // Wagging tail at back
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let tailAnchor = NSPoint(x: 116, y: 94)
        let tailTransform = NSAffineTransform()
        tailTransform.translateX(by: tailAnchor.x, yBy: tailAnchor.y)
        tailTransform.rotate(byDegrees: rightWingFlap * 1.1)
        tailTransform.translateX(by: -tailAnchor.x, yBy: -tailAnchor.y)
        tailTransform.concat()
        bodyColor.setFill()
        let tailPath = NSBezierPath()
        tailPath.move(to: NSPoint(x: 114, y: 92))
        tailPath.curve(to: NSPoint(x: 136, y: 68), controlPoint1: NSPoint(x: 124, y: 88), controlPoint2: NSPoint(x: 136, y: 78))
        tailPath.curve(to: NSPoint(x: 118, y: 100), controlPoint1: NSPoint(x: 130, y: 78), controlPoint2: NSPoint(x: 124, y: 96))
        tailPath.close()
        tailPath.fill()
        context.restoreGraphicsState()

        // Puppy Body
        bodyColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 18, y: 24, width: 114, height: 110), xRadius: 46, yRadius: 46).fill()

        // Cream Chest
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 34, y: 58, width: 82, height: 72)).fill()

        // Floppy Puppy Ears
        drawDogEar(in: NSRect(x: 10 + leftWingFlap * 0.18, y: 24, width: 34, height: 60), angle: leftWingFlap * 0.7, color: accentColor, isLeft: true)
        drawDogEar(in: NSRect(x: 106 - rightWingFlap * 0.18, y: 24, width: 34, height: 60), angle: -rightWingFlap * 0.7, color: accentColor, isLeft: false)

        // Cream Muzzle
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 64, width: 62, height: 46)).fill()

        // Puppy Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 32, y: 38, width: 37, height: 43), rightEyeRect: NSRect(x: 81, y: 38, width: 37, height: 43))

        // Puppy Brows
        accentColor.withAlphaComponent(0.8).setStroke()
        let brows = NSBezierPath(); brows.lineWidth = 3; brows.lineCapStyle = .round
        brows.move(to: NSPoint(x: 40, y: 32)); brows.curve(to: NSPoint(x: 54, y: 30), controlPoint1: NSPoint(x: 44, y: 28), controlPoint2: NSPoint(x: 50, y: 28))
        brows.move(to: NSPoint(x: 96, y: 30)); brows.curve(to: NSPoint(x: 110, y: 32), controlPoint1: NSPoint(x: 100, y: 28), controlPoint2: NSPoint(x: 106, y: 28)); brows.stroke()

        // Cute Button Nose
        accentColor.setFill()
        let nose = NSBezierPath(roundedRect: NSRect(x: 67, y: 68, width: 16, height: 12), xRadius: 5, yRadius: 5)
        nose.fill()
        NSColor.white.withAlphaComponent(0.7).setFill()
        NSBezierPath(ovalIn: NSRect(x: 70, y: 69, width: 5, height: 3)).fill()

        // Puppy Smile & Tongue
        accentColor.setStroke()
        let mouth = NSBezierPath(); mouth.lineWidth = 2.5; mouth.lineCapStyle = .round
        mouth.move(to: NSPoint(x: 75, y: 80)); mouth.line(to: NSPoint(x: 75, y: 84))
        mouth.move(to: NSPoint(x: 66, y: 84)); mouth.curve(to: NSPoint(x: 75, y: 86), controlPoint1: NSPoint(x: 68, y: 87), controlPoint2: NSPoint(x: 72, y: 87))
        mouth.curve(to: NSPoint(x: 84, y: 84), controlPoint1: NSPoint(x: 78, y: 87), controlPoint2: NSPoint(x: 82, y: 87)); mouth.stroke()

        NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.55, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 85, width: 7, height: 8)).fill()

        accentColor.withAlphaComponent(0.82).setStroke()
        let collar = NSBezierPath(); collar.lineWidth = 4; collar.lineCapStyle = .round
        collar.move(to: NSPoint(x: 47, y: 103)); collar.curve(to: NSPoint(x: 103, y: 103), controlPoint1: NSPoint(x: 62, y: 109), controlPoint2: NSPoint(x: 88, y: 109)); collar.stroke()
        accentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 71, y: 101, width: 8, height: 8)).fill()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 48, y: 80, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 30, y: 80, width: 18, height: 10)).fill()

        // Paws
        let feetTuck = flightIntensity * 6.0
        accentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 36, y: 123 - feetTuck, width: 26, height: 16), xRadius: 8, yRadius: 8).fill()
        NSBezierPath(roundedRect: NSRect(x: 88, y: 123 - feetTuck, width: 26, height: 16), xRadius: 8, yRadius: 8).fill()
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 42, y: 128 - feetTuck, width: 14, height: 8)).fill()
        NSBezierPath(ovalIn: NSRect(x: 94, y: 128 - feetTuck, width: 14, height: 8)).fill()
    }

    private func drawDogEar(in frame: NSRect, angle: CGFloat, color: NSColor, isLeft: Bool) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let anchor = isLeft ? NSPoint(x: frame.maxX - 6, y: frame.minY + 8) : NSPoint(x: frame.minX + 6, y: frame.minY + 8)
        let transform = NSAffineTransform()
        transform.translateX(by: anchor.x, yBy: anchor.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -anchor.x, yBy: -anchor.y)
        transform.concat()
        color.setFill()
        NSBezierPath(roundedRect: frame, xRadius: 16, yRadius: 16).fill()
        color.blended(withFraction: 0.20, of: .white)?.setFill()
        NSBezierPath(ovalIn: NSRect(x: frame.minX + 7, y: frame.minY + 8, width: 8, height: 12)).fill()
        context.restoreGraphicsState()
    }

    private func drawCat(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        // Swishing Cat Tail
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let tailAnchor = NSPoint(x: 114, y: 96)
        let tailTransform = NSAffineTransform()
        tailTransform.translateX(by: tailAnchor.x, yBy: tailAnchor.y)
        tailTransform.rotate(byDegrees: rightWingFlap * 0.9)
        tailTransform.translateX(by: -tailAnchor.x, yBy: -tailAnchor.y)
        tailTransform.concat()
        bodyColor.setStroke()
        let tail = NSBezierPath()
        tail.lineWidth = 11; tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 112, y: 94))
        tail.curve(to: NSPoint(x: 136, y: 58), controlPoint1: NSPoint(x: 128, y: 90), controlPoint2: NSPoint(x: 140, y: 74))
        tail.stroke()
        context.restoreGraphicsState()

        // Pointy Cat Ears
        drawCatEar(tip: NSPoint(x: 36 + leftWingFlap * 0.12, y: 6), baseLeft: NSPoint(x: 18, y: 40), baseRight: NSPoint(x: 54, y: 30), bodyColor: bodyColor, innerColor: accentColor)
        drawCatEar(tip: NSPoint(x: 114 - rightWingFlap * 0.12, y: 6), baseLeft: NSPoint(x: 96, y: 30), baseRight: NSPoint(x: 132, y: 40), bodyColor: bodyColor, innerColor: accentColor)

        // Cat Body
        bodyColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 20, y: 28, width: 110, height: 106), xRadius: 44, yRadius: 44).fill()

        // Cream Chest
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 36, y: 62, width: 78, height: 68)).fill()

        // Muzzle Mounds
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 48, y: 68, width: 28, height: 22)).fill()
        NSBezierPath(ovalIn: NSRect(x: 74, y: 68, width: 28, height: 22)).fill()

        // Cat Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 30, y: 38, width: 38, height: 43), rightEyeRect: NSRect(x: 82, y: 38, width: 38, height: 43))

        // Pink Triangle Nose
        accentColor.setFill()
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 70, y: 70)); nose.line(to: NSPoint(x: 80, y: 70)); nose.line(to: NSPoint(x: 75, y: 76)); nose.close(); nose.fill()

        // Cat Whiskers
        NSColor(calibratedWhite: 0.2, alpha: 0.55).setStroke()
        let whiskers = NSBezierPath(); whiskers.lineWidth = 1.6; whiskers.lineCapStyle = .round
        whiskers.move(to: NSPoint(x: 24, y: 74)); whiskers.line(to: NSPoint(x: 50, y: 76))
        whiskers.move(to: NSPoint(x: 22, y: 82)); whiskers.line(to: NSPoint(x: 49, y: 80))
        whiskers.move(to: NSPoint(x: 126, y: 74)); whiskers.line(to: NSPoint(x: 100, y: 76))
        whiskers.move(to: NSPoint(x: 128, y: 82)); whiskers.line(to: NSPoint(x: 101, y: 80)); whiskers.stroke()

        accentColor.withAlphaComponent(0.58).setStroke()
        let stripes = NSBezierPath(); stripes.lineWidth = 2.2; stripes.lineCapStyle = .round
        stripes.move(to: NSPoint(x: 61, y: 31)); stripes.line(to: NSPoint(x: 65, y: 40))
        stripes.move(to: NSPoint(x: 75, y: 28)); stripes.line(to: NSPoint(x: 75, y: 39))
        stripes.move(to: NSPoint(x: 89, y: 31)); stripes.line(to: NSPoint(x: 85, y: 40)); stripes.stroke()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 48, y: 78, width: 16, height: 9)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 32, y: 78, width: 16, height: 9)).fill()

        // Dainty Cat Paws
        let feetTuck = flightIntensity * 6.0
        accentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 38, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7).fill()
        NSBezierPath(roundedRect: NSRect(x: 88, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7).fill()
        bellyColor.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 128 - feetTuck, width: 6, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 100, y: 128 - feetTuck, width: 6, height: 4)).fill()
    }

    private func drawCatEar(tip: NSPoint, baseLeft: NSPoint, baseRight: NSPoint, bodyColor: NSColor, innerColor: NSColor) {
        bodyColor.setFill()
        let ear = NSBezierPath()
        ear.move(to: baseLeft); ear.line(to: tip); ear.line(to: baseRight); ear.close(); ear.fill()

        innerColor.setFill()
        let inner = NSBezierPath()
        let innerTip = NSPoint(x: tip.x, y: tip.y + 7)
        let innerLeft = NSPoint(x: baseLeft.x + (tip.x - baseLeft.x) * 0.3 + 3, y: baseLeft.y - 3)
        let innerRight = NSPoint(x: baseRight.x + (tip.x - baseRight.x) * 0.3 - 3, y: baseRight.y - 3)
        inner.move(to: innerLeft); inner.line(to: innerTip); inner.line(to: innerRight); inner.close(); inner.fill()
    }

    private func drawMonkey(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        // Curled Monkey Tail
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let tailAnchor = NSPoint(x: 112, y: 92)
        let tailTransform = NSAffineTransform()
        tailTransform.translateX(by: tailAnchor.x, yBy: tailAnchor.y)
        tailTransform.rotate(byDegrees: rightWingFlap * 0.9)
        tailTransform.translateX(by: -tailAnchor.x, yBy: -tailAnchor.y)
        tailTransform.concat()
        bodyColor.setStroke()
        let tail = NSBezierPath()
        tail.lineWidth = 9; tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 110, y: 90))
        tail.curve(to: NSPoint(x: 138, y: 58), controlPoint1: NSPoint(x: 126, y: 88), controlPoint2: NSPoint(x: 140, y: 72))
        tail.curve(to: NSPoint(x: 130, y: 50), controlPoint1: NSPoint(x: 136, y: 50), controlPoint2: NSPoint(x: 132, y: 48))
        tail.stroke()
        context.restoreGraphicsState()

        // Big Round Monkey Ears
        bodyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 8 + leftWingFlap * 0.15, y: 42, width: 32, height: 32)).fill()
        NSBezierPath(ovalIn: NSRect(x: 110 - rightWingFlap * 0.15, y: 42, width: 32, height: 32)).fill()
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 14 + leftWingFlap * 0.15, y: 47, width: 20, height: 20)).fill()
        NSBezierPath(ovalIn: NSRect(x: 116 - rightWingFlap * 0.15, y: 47, width: 20, height: 20)).fill()
        accentColor.withAlphaComponent(0.28).setStroke()
        let earDetail = NSBezierPath(); earDetail.lineWidth = 1.5
        earDetail.appendArc(withCenter: NSPoint(x: 24 + leftWingFlap * 0.15, y: 57), radius: 7, startAngle: 205, endAngle: 335)
        earDetail.appendArc(withCenter: NSPoint(x: 126 - rightWingFlap * 0.15, y: 57), radius: 7, startAngle: 25, endAngle: 155)
        earDetail.stroke()

        // Body
        bodyColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 22, y: 26, width: 106, height: 108), xRadius: 44, yRadius: 44).fill()

        // Peach Heart Face Mask
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 28, y: 28, width: 50, height: 50)).fill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 28, width: 50, height: 50)).fill()
        NSBezierPath(ovalIn: NSRect(x: 36, y: 52, width: 78, height: 52)).fill()

        // Belly
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 42, y: 84, width: 66, height: 46)).fill()

        // Monkey Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 34, y: 38, width: 35, height: 40), rightEyeRect: NSRect(x: 81, y: 38, width: 35, height: 40))

        // Cute Nostrils & Wide Smile
        accentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 70, y: 70, width: 4, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 76, y: 70, width: 4, height: 4)).fill()

        accentColor.setStroke()
        let smile = NSBezierPath(); smile.lineWidth = 2.5; smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 64, y: 80)); smile.curve(to: NSPoint(x: 86, y: 80), controlPoint1: NSPoint(x: 70, y: 88), controlPoint2: NSPoint(x: 80, y: 88)); smile.stroke()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 46, y: 76, width: 17, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 29, y: 76, width: 17, height: 10)).fill()

        // Monkey Hands / Paws
        let feetTuck = flightIntensity * 6.0
        accentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 36, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7).fill()
        NSBezierPath(roundedRect: NSRect(x: 90, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7).fill()
    }

    private func drawGiraffe(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        // Giraffe Ossicones (Horns)
        accentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 52, y: 8, width: 7, height: 22), xRadius: 3, yRadius: 3).fill()
        NSBezierPath(roundedRect: NSRect(x: 91, y: 8, width: 7, height: 22), xRadius: 3, yRadius: 3).fill()
        accentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 48, y: 3, width: 15, height: 15)).fill()
        NSBezierPath(ovalIn: NSRect(x: 87, y: 3, width: 15, height: 15)).fill()

        // Gentle Leaf Ears
        drawGiraffeEar(at: NSPoint(x: 24 + leftWingFlap * 0.15, y: 28), angle: leftWingFlap * 0.5, color: bodyColor, isLeft: true)
        drawGiraffeEar(at: NSPoint(x: 112 - rightWingFlap * 0.15, y: 28), angle: -rightWingFlap * 0.5, color: bodyColor, isLeft: false)

        // Long Neck & Head
        bodyColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 46, y: 64, width: 58, height: 72), xRadius: 20, yRadius: 20).fill()
        NSBezierPath(roundedRect: NSRect(x: 30, y: 18, width: 90, height: 74), xRadius: 36, yRadius: 36).fill()

        accentColor.withAlphaComponent(0.72).setFill()
        let mane = NSBezierPath()
        mane.move(to: NSPoint(x: 45, y: 34)); mane.line(to: NSPoint(x: 40, y: 40)); mane.line(to: NSPoint(x: 45, y: 45)); mane.line(to: NSPoint(x: 40, y: 51)); mane.line(to: NSPoint(x: 46, y: 57)); mane.close(); mane.fill()
        mane.move(to: NSPoint(x: 105, y: 34)); mane.line(to: NSPoint(x: 110, y: 40)); mane.line(to: NSPoint(x: 105, y: 45)); mane.line(to: NSPoint(x: 110, y: 51)); mane.line(to: NSPoint(x: 104, y: 57)); mane.close(); mane.fill()

        // Giraffe Spots on Neck & Cheeks
        accentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 52, y: 76, width: 18, height: 16), xRadius: 6, yRadius: 6).fill()
        NSBezierPath(roundedRect: NSRect(x: 78, y: 88, width: 20, height: 18), xRadius: 7, yRadius: 7).fill()
        NSBezierPath(roundedRect: NSRect(x: 54, y: 108, width: 18, height: 16), xRadius: 6, yRadius: 6).fill()
        NSBezierPath(ovalIn: NSRect(x: 32, y: 44, width: 10, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: 108, y: 44, width: 10, height: 10)).fill()

        // Soft Cream Muzzle
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 42, y: 52, width: 66, height: 42)).fill()

        // Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 34, y: 32, width: 35, height: 40), rightEyeRect: NSRect(x: 81, y: 32, width: 35, height: 40))

        // Nostrils & Smile
        accentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 66, y: 62, width: 5, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 79, y: 62, width: 5, height: 4)).fill()
        NSColor.white.withAlphaComponent(0.32).setFill()
        NSBezierPath(ovalIn: NSRect(x: 68, y: 63, width: 2, height: 1.5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 81, y: 63, width: 2, height: 1.5)).fill()

        accentColor.setStroke()
        let smile = NSBezierPath(); smile.lineWidth = 2.2; smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 68, y: 74)); smile.curve(to: NSPoint(x: 82, y: 74), controlPoint1: NSPoint(x: 72, y: 79), controlPoint2: NSPoint(x: 78, y: 79)); smile.stroke()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 45, y: 66, width: 17, height: 9)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 28, y: 66, width: 17, height: 9)).fill()

        // Hooves
        let feetTuck = flightIntensity * 6.0
        accentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 48, y: 124 - feetTuck, width: 22, height: 14), xRadius: 5, yRadius: 5).fill()
        NSBezierPath(roundedRect: NSRect(x: 80, y: 124 - feetTuck, width: 22, height: 14), xRadius: 5, yRadius: 5).fill()
    }

    private func drawGiraffeEar(at point: NSPoint, angle: CGFloat, color: NSColor, isLeft: Bool) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: point.x, yBy: point.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -point.x, yBy: -point.y)
        transform.concat()
        color.setFill()
        let ear = NSBezierPath(ovalIn: NSRect(x: point.x - 14, y: point.y - 8, width: 28, height: 16))
        ear.fill()
        context.restoreGraphicsState()
    }

    private func drawSlinky(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        // A friendly little spring: broad rounded coils make the silhouette read
        // clearly even at the compact 150-point buddy size.
        let highlight = bodyColor.blended(withFraction: 0.28, of: .white) ?? bodyColor
        let shadow = bodyColor.blended(withFraction: 0.22, of: .black) ?? bodyColor

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        // Slinky bounces vertically like an elastic accordion spring.
        let bounce = CGFloat(sin(wingPhase * 0.8)) * (isFlying ? 7.5 : 2.5)

        let y0: CGFloat = 31
        let y1: CGFloat = 48 + bounce * 0.2
        let y2: CGFloat = 65 + bounce * 0.45
        let y3: CGFloat = 82 + bounce * 0.7
        let y4: CGFloat = 99 + bounce * 0.9
        let y5: CGFloat = 119 + bounce * 1.1

        let coil = NSBezierPath()
        coil.lineWidth = 15
        coil.lineCapStyle = .round
        coil.lineJoinStyle = .round
        bodyColor.setStroke()
        coil.move(to: NSPoint(x: 39, y: y0))
        coil.curve(to: NSPoint(x: 111, y: y0), controlPoint1: NSPoint(x: 55, y: y0 - 13), controlPoint2: NSPoint(x: 95, y: y0 - 13))
        coil.curve(to: NSPoint(x: 40, y: y1), controlPoint1: NSPoint(x: 126, y: y1 - 1), controlPoint2: NSPoint(x: 25, y: y1 + 1))
        coil.curve(to: NSPoint(x: 110, y: y2), controlPoint1: NSPoint(x: 126, y: y2), controlPoint2: NSPoint(x: 24, y: y2 + 1))
        coil.curve(to: NSPoint(x: 40, y: y3), controlPoint1: NSPoint(x: 126, y: y3), controlPoint2: NSPoint(x: 25, y: y3 + 1))
        coil.curve(to: NSPoint(x: 110, y: y4), controlPoint1: NSPoint(x: 126, y: y4), controlPoint2: NSPoint(x: 25, y: y4 + 1))
        coil.curve(to: NSPoint(x: 48, y: y5), controlPoint1: NSPoint(x: 119, y: y5), controlPoint2: NSPoint(x: 80, y: y5 + 10))
        if animalKind == .slinky && themePreset == .rainbow {
            drawRainbowSlinkyCoils(shift: 0)
        } else {
            coil.stroke()
        }

        // Extra inner turns give the spring its playful, unmistakable swirl.
        let iy0: CGFloat = 39
        let iy1: CGFloat = 55 + bounce * 0.25
        let iy2: CGFloat = 72 + bounce * 0.5
        let iy3: CGFloat = 89 + bounce * 0.75
        let iy4: CGFloat = 105 + bounce * 1.0

        let innerCoils = NSBezierPath()
        innerCoils.lineWidth = 4.2
        innerCoils.lineCapStyle = .round
        highlight.withAlphaComponent(0.58).setStroke()
        innerCoils.move(to: NSPoint(x: 45, y: iy0))
        innerCoils.curve(to: NSPoint(x: 105, y: iy0), controlPoint1: NSPoint(x: 59, y: iy0 - 10), controlPoint2: NSPoint(x: 91, y: iy0 - 10))
        innerCoils.curve(to: NSPoint(x: 47, y: iy1), controlPoint1: NSPoint(x: 116, y: iy1 - 2), controlPoint2: NSPoint(x: 34, y: iy1))
        innerCoils.curve(to: NSPoint(x: 104, y: iy2), controlPoint1: NSPoint(x: 116, y: iy2), controlPoint2: NSPoint(x: 34, y: iy2 + 1))
        innerCoils.curve(to: NSPoint(x: 47, y: iy3), controlPoint1: NSPoint(x: 116, y: iy3), controlPoint2: NSPoint(x: 34, y: iy3 + 1))
        innerCoils.curve(to: NSPoint(x: 101, y: iy4), controlPoint1: NSPoint(x: 116, y: iy4), controlPoint2: NSPoint(x: 69, y: iy4 + 10))
        innerCoils.stroke()

        // Curled tips peek out from either side and wobble with the vertical bounce.
        accentColor.withAlphaComponent(0.7).setStroke()
        let curls = NSBezierPath()
        curls.lineWidth = 3
        curls.lineCapStyle = .round
        curls.appendArc(withCenter: NSPoint(x: 28, y: 37 + bounce * 0.1), radius: 8, startAngle: 240, endAngle: 65)
        curls.appendArc(withCenter: NSPoint(x: 122, y: 37 + bounce * 0.1), radius: 8, startAngle: 115, endAngle: 300)
        curls.stroke()

        // A soft face plate keeps the eyes readable against the winding spring.
        let faceYOffset = bounce * 0.45
        bellyColor.withAlphaComponent(0.96).setFill()
        NSBezierPath(roundedRect: NSRect(x: 29, y: 27 + faceYOffset, width: 92, height: 67), xRadius: 30, yRadius: 30).fill()
        highlight.withAlphaComponent(0.42).setStroke()
        let shine = NSBezierPath(); shine.lineWidth = 3; shine.lineCapStyle = .round
        shine.move(to: NSPoint(x: 42, y: 111 + bounce * 1.0))
        shine.curve(to: NSPoint(x: 105, y: 111 + bounce * 1.0), controlPoint1: NSPoint(x: 57, y: 120 + bounce * 1.0), controlPoint2: NSPoint(x: 91, y: 120 + bounce * 1.0))
        shine.stroke()

        drawStandardEyes(leftEyeRect: NSRect(x: 34, y: 39 + faceYOffset, width: 34, height: 38), rightEyeRect: NSRect(x: 82, y: 39 + faceYOffset, width: 34, height: 38))

        // Tiny center nub and a happy smile.
        accentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 70, y: 72 + faceYOffset, width: 10, height: 7)).fill()
        accentColor.setStroke()
        let smile = NSBezierPath(); smile.lineWidth = 2.3; smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 66, y: 83 + faceYOffset))
        smile.curve(to: NSPoint(x: 84, y: 83 + faceYOffset), controlPoint1: NSPoint(x: 71, y: 90 + faceYOffset), controlPoint2: NSPoint(x: 79, y: 90 + faceYOffset))
        smile.stroke()

        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 28, y: 76 + faceYOffset, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: 104, y: 76 + faceYOffset, width: 18, height: 10)).fill()

        let feetTuck = flightIntensity * 6.0
        shadow.setFill()
        NSBezierPath(ovalIn: NSRect(x: 38, y: 119 + bounce * 1.1 - feetTuck, width: 26, height: 17)).fill()
        NSBezierPath(ovalIn: NSRect(x: 86, y: 119 + bounce * 1.1 - feetTuck, width: 26, height: 17)).fill()
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 123 + bounce * 1.1 - feetTuck, width: 14, height: 7)).fill()
        NSBezierPath(ovalIn: NSRect(x: 92, y: 123 + bounce * 1.1 - feetTuck, width: 14, height: 7)).fill()
        context.restoreGraphicsState()
    }

    private func drawRainbowSlinkyCoils(shift: CGFloat) {
        let colors: [NSColor] = [
            NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.35, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.16, alpha: 1),
            NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.45, alpha: 1),
            NSColor(calibratedRed: 0.18, green: 0.64, blue: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.58, green: 0.34, blue: 0.94, alpha: 1)
        ]
        for index in 0..<6 {
            let y = CGFloat(30 + index * 17)
            let path = NSBezierPath()
            path.lineWidth = 15
            path.lineCapStyle = .round
            colors[index].setStroke()
            path.move(to: NSPoint(x: 40 + (index.isMultiple(of: 2) ? shift : -shift), y: y))
            path.curve(to: NSPoint(x: 110 - (index.isMultiple(of: 2) ? shift : -shift), y: y), controlPoint1: NSPoint(x: 57, y: y - 12), controlPoint2: NSPoint(x: 93, y: y - 12))
            path.stroke()
        }
    }

    private func drawStandardEyes(leftEyeRect: NSRect, rightEyeRect: NSRect) {
        if eyesAreOpen {
            NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.28, alpha: 0.48).setStroke()
            let eyeOutline = NSBezierPath(); eyeOutline.lineWidth = 1.8
            eyeOutline.appendOval(in: leftEyeRect.insetBy(dx: 0.9, dy: 0.9))
            eyeOutline.appendOval(in: rightEyeRect.insetBy(dx: 0.9, dy: 0.9)); eyeOutline.stroke()
            NSColor(calibratedWhite: 1, alpha: 1).setFill()
            NSBezierPath(ovalIn: leftEyeRect).fill()
            NSBezierPath(ovalIn: rightEyeRect).fill()

            NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1).setFill()
            let pw = leftEyeRect.width * 0.64
            let ph = leftEyeRect.height * 0.68
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 7 + pupilOffset.x, y: leftEyeRect.minY + 8 + pupilOffset.y, width: pw, height: ph)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 7 + pupilOffset.x, y: rightEyeRect.minY + 8 + pupilOffset.y, width: pw, height: ph)).fill()

            themePalette.eyeHighlightColor.nsColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 9 + pupilOffset.x, y: leftEyeRect.maxY - 20 + pupilOffset.y, width: pw * 0.8, height: ph * 0.45)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 9 + pupilOffset.x, y: rightEyeRect.maxY - 20 + pupilOffset.y, width: pw * 0.8, height: ph * 0.45)).fill()

            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 11 + pupilOffset.x, y: leftEyeRect.minY + 10 + pupilOffset.y, width: pw * 0.45, height: ph * 0.42)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 11 + pupilOffset.x, y: rightEyeRect.minY + 10 + pupilOffset.y, width: pw * 0.45, height: ph * 0.42)).fill()
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 22 + pupilOffset.x, y: leftEyeRect.maxY - 19 + pupilOffset.y, width: 5, height: 6)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 22 + pupilOffset.x, y: rightEyeRect.maxY - 19 + pupilOffset.y, width: 5, height: 6)).fill()
        } else {
            NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.55, alpha: 1).setStroke()
            let blink = NSBezierPath(); blink.lineWidth = 3; blink.lineCapStyle = .round
            blink.move(to: NSPoint(x: leftEyeRect.minX + 6, y: leftEyeRect.midY))
            blink.line(to: NSPoint(x: leftEyeRect.maxX - 6, y: leftEyeRect.midY))
            blink.move(to: NSPoint(x: rightEyeRect.minX + 6, y: rightEyeRect.midY))
            blink.line(to: NSPoint(x: rightEyeRect.maxX - 6, y: rightEyeRect.midY))
            blink.stroke()
        }
    }

    private func drawCreatureShadow() {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
        shadow.shadowBlurRadius = 7
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        NSColor.black.withAlphaComponent(0.10).setFill()
        NSBezierPath(ovalIn: NSRect(x: 28, y: 127, width: 94, height: 13)).fill()
        context.restoreGraphicsState()
    }

    private func drawRimHighlight() {
        NSColor.white.withAlphaComponent(0.12).setFill()
        let highlight = NSBezierPath()
        highlight.move(to: NSPoint(x: 42, y: 24))
        highlight.curve(to: NSPoint(x: 108, y: 24), controlPoint1: NSPoint(x: 58, y: 17), controlPoint2: NSPoint(x: 92, y: 17))
        highlight.curve(to: NSPoint(x: 116, y: 30), controlPoint1: NSPoint(x: 113, y: 26), controlPoint2: NSPoint(x: 115, y: 28))
        highlight.curve(to: NSPoint(x: 34, y: 30), controlPoint1: NSPoint(x: 65, y: 34), controlPoint2: NSPoint(x: 46, y: 33))
        highlight.curve(to: NSPoint(x: 42, y: 24), controlPoint1: NSPoint(x: 35, y: 28), controlPoint2: NSPoint(x: 38, y: 25))
        highlight.close()
        highlight.fill()
    }

    private func drawBirdFeathers(color: NSColor) {
        color.setStroke()
        let feathers = NSBezierPath(); feathers.lineWidth = 1.4; feathers.lineCapStyle = .round
        feathers.move(to: NSPoint(x: 10, y: 90)); feathers.curve(to: NSPoint(x: 27, y: 83), controlPoint1: NSPoint(x: 14, y: 87), controlPoint2: NSPoint(x: 20, y: 84))
        feathers.move(to: NSPoint(x: 10, y: 99)); feathers.curve(to: NSPoint(x: 28, y: 94), controlPoint1: NSPoint(x: 15, y: 97), controlPoint2: NSPoint(x: 21, y: 95))
        feathers.move(to: NSPoint(x: 140, y: 90)); feathers.curve(to: NSPoint(x: 123, y: 83), controlPoint1: NSPoint(x: 136, y: 87), controlPoint2: NSPoint(x: 130, y: 84))
        feathers.move(to: NSPoint(x: 140, y: 99)); feathers.curve(to: NSPoint(x: 122, y: 94), controlPoint1: NSPoint(x: 135, y: 97), controlPoint2: NSPoint(x: 129, y: 95)); feathers.stroke()
    }

    private func drawGiraffeMane(color: NSColor) {
        color.setFill()
        let mane = NSBezierPath()
        mane.move(to: NSPoint(x: 45, y: 34)); mane.line(to: NSPoint(x: 40, y: 40)); mane.line(to: NSPoint(x: 45, y: 45)); mane.line(to: NSPoint(x: 40, y: 51)); mane.line(to: NSPoint(x: 46, y: 57)); mane.close(); mane.fill()
        mane.move(to: NSPoint(x: 105, y: 34)); mane.line(to: NSPoint(x: 110, y: 40)); mane.line(to: NSPoint(x: 105, y: 45)); mane.line(to: NSPoint(x: 110, y: 51)); mane.line(to: NSPoint(x: 104, y: 57)); mane.close(); mane.fill()
    }

    private func drawFlightBreeze(intensity: CGFloat) {
        let breezeColor = NSColor.white.withAlphaComponent(0.35 * intensity)
        breezeColor.setStroke()
        let breeze = NSBezierPath()
        breeze.lineWidth = 2.0
        breeze.lineCapStyle = .round
        breeze.move(to: NSPoint(x: 14, y: 130))
        breeze.curve(to: NSPoint(x: 28, y: 135), controlPoint1: NSPoint(x: 18, y: 134), controlPoint2: NSPoint(x: 23, y: 135))
        breeze.move(to: NSPoint(x: 136, y: 130))
        breeze.curve(to: NSPoint(x: 122, y: 135), controlPoint1: NSPoint(x: 132, y: 134), controlPoint2: NSPoint(x: 127, y: 135))
        breeze.stroke()
    }

    private func drawSparkle(at point: NSPoint) {
        NSColor.systemYellow.setStroke()
        let sparkle = NSBezierPath(); sparkle.lineWidth = 2; sparkle.lineCapStyle = .round
        sparkle.move(to: NSPoint(x: point.x, y: point.y - 6)); sparkle.line(to: NSPoint(x: point.x, y: point.y + 6))
        sparkle.move(to: NSPoint(x: point.x - 6, y: point.y)); sparkle.line(to: NSPoint(x: point.x + 6, y: point.y)); sparkle.stroke()
    }

    private func drawWing(in frame: NSRect, angle: CGFloat, isLeft: Bool) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let anchor = isLeft ? NSPoint(x: frame.maxX - 4, y: frame.minY + 12) : NSPoint(x: frame.minX + 4, y: frame.minY + 12)
        let transform = NSAffineTransform()
        transform.translateX(by: anchor.x, yBy: anchor.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -anchor.x, yBy: -anchor.y)
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
