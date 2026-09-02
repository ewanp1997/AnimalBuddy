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
    var googlyEyesEnabled: Bool = true {
        didSet { needsDisplay = true }
    }
    private var leftGooglyPupilPos = NSPoint(x: 0, y: 4.5)
    private var leftGooglyPupilVel = NSPoint.zero
    private var rightGooglyPupilPos = NSPoint(x: 0, y: 4.5)
    private var rightGooglyPupilVel = NSPoint.zero
    private var lastHeadBob: CGFloat = 0
    private var headBobVel: CGFloat = 0
    private var lastFlightTilt: CGFloat = 0
    private var leftStalkPos = NSPoint.zero
    private var leftStalkVel = NSPoint.zero
    private var rightStalkPos = NSPoint.zero
    private var rightStalkVel = NSPoint.zero
    private var googlyVigor: CGFloat = 0.0
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
    private(set) var isDiscoMode: Bool = false
    private var discoEndsAt: Date = .distantPast
    private var discoPhase: Double = 0
    var isDancingToMusic: Bool = false {
        didSet {
            if oldValue != isDancingToMusic {
                needsDisplay = true
            }
        }
    }
    private var musicDancePhase: Double = 0
    override var isFlipped: Bool { true }

    func startDiscoMode(duration: TimeInterval = 8.5) {
        isDiscoMode = true
        discoEndsAt = Date().addingTimeInterval(duration)
        state = .disco
        needsDisplay = true
    }

    func stopDiscoMode() {
        isDiscoMode = false
        if state == .disco {
            state = .idle
        }
        needsDisplay = true
    }

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

    static func eyeRects(for kind: AnimalKind, in bounds: NSRect) -> (left: NSRect, right: NSRect) {
        let designSize: CGFloat = 150
        let scale = min(bounds.width / designSize, bounds.height / designSize)
        let originX = bounds.midX - (designSize * scale) / 2
        let originY = bounds.midY - (designSize * scale) / 2

        let (leftDesign, rightDesign): (NSRect, NSRect) = switch kind {
        case .bird:
            (NSRect(x: 29, y: 38, width: 39, height: 45),
             NSRect(x: 82, y: 38, width: 39, height: 45))
        case .dog:
            (NSRect(x: 32, y: 38, width: 37, height: 43),
             NSRect(x: 81, y: 38, width: 37, height: 43))
        case .cat:
            (NSRect(x: 30, y: 38, width: 38, height: 43),
             NSRect(x: 82, y: 38, width: 38, height: 43))
        case .monkey:
            (NSRect(x: 34, y: 38, width: 35, height: 40),
             NSRect(x: 81, y: 38, width: 35, height: 40))
        case .giraffe:
            (NSRect(x: 34, y: 32, width: 35, height: 40),
             NSRect(x: 81, y: 32, width: 35, height: 40))
        case .slinky:
            (NSRect(x: 34, y: 39, width: 34, height: 38),
             NSRect(x: 82, y: 39, width: 34, height: 38))
        }

        let leftRect = NSRect(
            x: originX + leftDesign.origin.x * scale,
            y: originY + leftDesign.origin.y * scale,
            width: leftDesign.width * scale,
            height: leftDesign.height * scale
        )
        let rightRect = NSRect(
            x: originX + rightDesign.origin.x * scale,
            y: originY + rightDesign.origin.y * scale,
            width: rightDesign.width * scale,
            height: rightDesign.height * scale
        )
        return (leftRect, rightRect)
    }

    override func layout() {
        super.layout()
        minimizeButton.frame = NSRect(x: bounds.maxX - 34, y: 10, width: 24, height: 24)
        let eyes = Self.eyeRects(for: animalKind, in: bounds)
        leftBlushButton.frame = eyes.left
        rightBlushButton.frame = eyes.right
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
        let localPoint: NSPoint
        if let superview {
            localPoint = convert(point, from: superview)
        } else if window != nil {
            localPoint = convert(point, from: nil)
        } else {
            localPoint = point
        }
        guard bounds.contains(localPoint) else { return nil }
        if !minimizeButton.isHidden && minimizeButton.frame.contains(localPoint) {
            return minimizeButton
        }
        if leftBlushButton.frame.contains(localPoint) {
            return leftBlushButton
        }
        if rightBlushButton.frame.contains(localPoint) {
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
        button.setAccessibilityLabel("\(slot == .left ? "Left" : "Right") eye macro trigger")
    }

    func updateBlushMacroLabels(_ settings: AppSettings) {
        leftBlushButton.toolTip = settings.leftBlushMacro.isConfigured ? settings.leftBlushMacro.name : "Configure left eye macro"
        rightBlushButton.toolTip = settings.rightBlushMacro.isConfigured ? settings.rightBlushMacro.name : "Configure right eye macro"
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
        googlyVigor = 1.0
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
        
        if isDiscoMode {
            if now >= discoEndsAt {
                isDiscoMode = false
                if state == .disco { state = .idle }
            } else {
                discoPhase += dt * 8.0
            }
        }

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
        } else if isDiscoMode {
            // Groovy dancing movements during Disco Mode!
            let discoBob = CGFloat(sin(discoPhase * 2.0)) * (animalKind == .slinky ? 7.0 : 4.5)
            bobOffset = discoBob
            leftWingFlap = CGFloat(sin(discoPhase * 2.5)) * 32.0
            rightWingFlap = CGFloat(cos(discoPhase * 2.5)) * 32.0
            flightTiltAngle = CGFloat(sin(discoPhase * 1.2)) * 14.0
        } else if isDancingToMusic {
            // Cheerful rhythmic bounce & groove when listening to music!
            musicDancePhase += dt * 7.2
            let musicBob = CGFloat(sin(musicDancePhase)) * (animalKind == .slinky ? 5.8 : 3.8)
            bobOffset = musicBob
            leftWingFlap = CGFloat(sin(musicDancePhase * 1.5)) * 14.0
            rightWingFlap = CGFloat(cos(musicDancePhase * 1.5)) * 14.0
            flightTiltAngle = CGFloat(sin(musicDancePhase * 0.5)) * 5.0
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

        // Update Googly Eyes physics coordinated with Slinky gravity, bounce acceleration, and flight tilt
        if googlyEyesEnabled {
            // Decay googly vigor down to baseline after movement stops
            let isActivelyMoving = isFlying || (now.timeIntervalSince(lastMovementTime) < 0.35)
            let targetVigor: CGFloat = isActivelyMoving ? 1.0 : 0.0
            if targetVigor > googlyVigor {
                googlyVigor += (targetVigor - googlyVigor) * 0.40
            } else {
                googlyVigor = max(0.0, googlyVigor - CGFloat(dt) * 0.75) // Graceful decay over ~1.3s
            }

            let headBounce = (animalKind == .slinky)
                ? (CGFloat(sin(wingPhase * 0.8)) * (isFlying ? 7.5 : 2.5) * 0.45)
                : (bobOffset * 0.45)
            
            let safeDt = CGFloat(max(dt, 0.002))
            let headVel = (headBounce - lastHeadBob) / safeDt
            let headAccel = (headVel - headBobVel) / safeDt
            headBobVel = headVel
            lastHeadBob = headBounce

            let tiltVel = (flightTiltAngle - lastFlightTilt) / safeDt
            lastFlightTilt = flightTiltAngle

            // Gravity vector in flipped view space (down is +Y):
            let tiltRad = Double(flightTiltAngle) * .pi / 180.0
            let gravityStrength: CGFloat = 220.0 // points/sec^2
            let gravityX = CGFloat(sin(tiltRad)) * gravityStrength
            let gravityY = CGFloat(cos(tiltRad)) * gravityStrength

            // Vigor-scaled dynamic gains (high energy during movement, calm at baseline)
            let bounceGain: CGFloat = 0.5 + googlyVigor * 2.1
            let tiltGain: CGFloat = 0.3 + googlyVigor * 1.5
            let jiggleGain: CGFloat = 0.12 + googlyVigor * 0.88
            let dampingRate: CGFloat = 6.8 - googlyVigor * 3.2
            let rimRestitution: CGFloat = 1.15 + googlyVigor * 0.47
            let stalkWobbleGain: CGFloat = 0.20 + googlyVigor * 0.80

            let bounceInertiaY = -headAccel * bounceGain
            let tiltInertiaX = -tiltVel * tiltGain

            // Micro-jiggle vibrations derived from the spring's natural bounce frequency
            let jiggleL_X = CGFloat(sin(wingPhase * 2.4)) * (isFlying ? 3.8 : 1.6) * jiggleGain
            let jiggleL_Y = CGFloat(cos(wingPhase * 3.1)) * (isFlying ? 4.8 : 2.2) * jiggleGain
            let jiggleR_X = CGFloat(cos(wingPhase * 2.7 + 0.8)) * (isFlying ? 3.8 : 1.6) * jiggleGain
            let jiggleR_Y = CGFloat(sin(wingPhase * 2.9 + 1.2)) * (isFlying ? 4.8 : 2.2) * jiggleGain

            // Magnetic gaze influence (curious look towards cursor)
            let gazePullX = pupilOffset.x * 45.0
            let gazePullY = pupilOffset.y * 32.0

            // Physics step for Left Eye
            let netForceLX = gravityX + tiltInertiaX + gazePullX + (jiggleL_X * 28.0) - (leftGooglyPupilPos.x * 16.0) - (leftGooglyPupilVel.x * dampingRate)
            let netForceLY = gravityY + bounceInertiaY + gazePullY + (jiggleL_Y * 34.0) - (leftGooglyPupilPos.y * 12.0) - (leftGooglyPupilVel.y * dampingRate)

            leftGooglyPupilVel.x += netForceLX * safeDt
            leftGooglyPupilVel.y += netForceLY * safeDt
            leftGooglyPupilPos.x += leftGooglyPupilVel.x * safeDt
            leftGooglyPupilPos.y += leftGooglyPupilVel.y * safeDt

            // Physics step for Right Eye (varied mass & resonance for independent rattling)
            let rightDamping = dampingRate * 0.92
            let netForceRX = gravityX + tiltInertiaX + gazePullX + (jiggleR_X * 26.0) - (rightGooglyPupilPos.x * 14.0) - (rightGooglyPupilVel.x * rightDamping)
            let netForceRY = gravityY + bounceInertiaY + gazePullY + (jiggleR_Y * 32.0) - (rightGooglyPupilPos.y * 11.0) - (rightGooglyPupilVel.y * rightDamping)

            rightGooglyPupilVel.x += netForceRX * safeDt
            rightGooglyPupilVel.y += netForceRY * safeDt
            rightGooglyPupilPos.x += rightGooglyPupilVel.x * safeDt
            rightGooglyPupilPos.y += rightGooglyPupilVel.y * safeDt

            // Capsule elliptical boundaries: chamber width 34, height 38; pupil size 17.5 x 18.5
            let maxRx: CGFloat = 7.6
            let maxRy: CGFloat = 9.2

            // Left Eye boundary collision & crisp elastic ping-pong bounce
            let lNormX = leftGooglyPupilPos.x / maxRx
            let lNormY = leftGooglyPupilPos.y / maxRy
            let lDist = hypot(lNormX, lNormY)
            if lDist > 1.0 {
                leftGooglyPupilPos.x = (lNormX / lDist) * maxRx
                leftGooglyPupilPos.y = (lNormY / lDist) * maxRy
                let normalX = lNormX / lDist
                let normalY = lNormY / lDist
                let dot = leftGooglyPupilVel.x * normalX + leftGooglyPupilVel.y * normalY
                if dot > 0 {
                    leftGooglyPupilVel.x -= rimRestitution * dot * normalX
                    leftGooglyPupilVel.y -= rimRestitution * dot * normalY
                }
            }

            // Right Eye boundary collision & crisp elastic ping-pong bounce
            let rNormX = rightGooglyPupilPos.x / maxRx
            let rNormY = rightGooglyPupilPos.y / maxRy
            let rDist = hypot(rNormX, rNormY)
            if rDist > 1.0 {
                rightGooglyPupilPos.x = (rNormX / rDist) * maxRx
                rightGooglyPupilPos.y = (rNormY / rDist) * maxRy
                let normalX = rNormX / rDist
                let normalY = rNormY / rDist
                let dot = rightGooglyPupilVel.x * normalX + rightGooglyPupilVel.y * normalY
                if dot > 0 {
                    rightGooglyPupilVel.x -= rimRestitution * dot * normalX
                    rightGooglyPupilVel.y -= rimRestitution * dot * normalY
                }
            }

            // Spring stalk pop-out & boing wobble physics (eyeball popping out of socket)
            let stalkTargetLX = pupilOffset.x * 0.40 + CGFloat(sin(wingPhase * 1.5)) * (isFlying ? 3.5 : 1.4) * stalkWobbleGain
            let stalkTargetLY = -4.5 + (bounceInertiaY * 0.035) + pupilOffset.y * 0.25

            let stalkTargetRX = pupilOffset.x * 0.40 + CGFloat(cos(wingPhase * 1.4 + 0.6)) * (isFlying ? 3.5 : 1.4) * stalkWobbleGain
            let stalkTargetRY = -4.5 + (bounceInertiaY * 0.035) + pupilOffset.y * 0.25

            let stalkDamping: CGFloat = 9.5 - googlyVigor * 2.0
            let stalkForceLX = (stalkTargetLX - leftStalkPos.x) * 145.0 - (leftStalkVel.x * stalkDamping)
            let stalkForceLY = (stalkTargetLY - leftStalkPos.y) * 145.0 - (leftStalkVel.y * stalkDamping)
            leftStalkVel.x += stalkForceLX * safeDt
            leftStalkVel.y += stalkForceLY * safeDt
            leftStalkPos.x += leftStalkVel.x * safeDt
            leftStalkPos.y += leftStalkVel.y * safeDt

            let stalkForceRX = (stalkTargetRX - rightStalkPos.x) * 130.0 - (rightStalkVel.x * (stalkDamping * 0.92))
            let stalkForceRY = (stalkTargetRY - rightStalkPos.y) * 130.0 - (rightStalkVel.y * (stalkDamping * 0.92))
            rightStalkVel.x += stalkForceRX * safeDt
            rightStalkVel.y += stalkForceRY * safeDt
            rightStalkPos.x += rightStalkVel.x * safeDt
            rightStalkPos.y += rightStalkVel.y * safeDt

            let maxStalkRadius: CGFloat = 8.5
            let lStalkDist = hypot(leftStalkPos.x, leftStalkPos.y + 4.5)
            if lStalkDist > maxStalkRadius {
                let scale = maxStalkRadius / lStalkDist
                leftStalkPos.x *= scale
                leftStalkPos.y = -4.5 + (leftStalkPos.y + 4.5) * scale
                leftStalkVel.x *= 0.5
                leftStalkVel.y *= 0.5
            }
            let rStalkDist = hypot(rightStalkPos.x, rightStalkPos.y + 4.5)
            if rStalkDist > maxStalkRadius {
                let scale = maxStalkRadius / rStalkDist
                rightStalkPos.x *= scale
                rightStalkPos.y = -4.5 + (rightStalkPos.y + 4.5) * scale
                rightStalkVel.x *= 0.5
                rightStalkVel.y *= 0.5
            }
        }

        needsDisplay = true
    }

    func setPupilOffset(_ target: NSPoint, animated: Bool) {
        let bounded = Self.clampPupilOffset(target)
        let gazeDelta = hypot(bounded.x - pupilOffset.x, bounded.y - pupilOffset.y)
        if gazeDelta > 0.6 {
            googlyVigor = min(1.0, googlyVigor + gazeDelta * 0.12)
        }
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
        let discoRainbowColor = NSColor(
            calibratedHue: CGFloat(fmod(discoPhase * 0.15, 1.0)),
            saturation: 0.85,
            brightness: 0.95,
            alpha: 1.0
        )
        let bodyColor: NSColor = switch state {
        case .idle, .sleeping: defaultBodyColor
        case .noticingDrag, .waitingForDrop: .systemOrange
        case .dragAccepted, .processing: .systemPurple
        case .success: .systemGreen
        case .dragRejected, .failure: .systemRed
        case .disco: isDiscoMode ? discoRainbowColor : defaultBodyColor
        }
        let bellyColor = isDiscoMode ? themePalette.bellyColor.nsColor.blended(withFraction: 0.25, of: discoRainbowColor) ?? themePalette.bellyColor.nsColor : themePalette.bellyColor.nsColor
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
        if isDiscoMode { drawDiscoMode(discoPhase: discoPhase) }
        if isDancingToMusic {
            drawHeadphones(for: animalKind, accentColor: accentColor)
            drawFloatingMusicNotes(phase: musicDancePhase)
        }
        if let dragPresentation { drawDragPresentation(dragPresentation) }
        if state == .success { drawSparkle(at: NSPoint(x: 20, y: 30)); drawSparkle(at: NSPoint(x: bounds.maxX - 20, y: 28)) }
        if state != .idle {
            let title = (state == .disco) ? "🪩 Disco!" : state.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
            title.draw(at: NSPoint(x: 12, y: bounds.height - 28), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: NSColor.white])
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawDiscoMode(discoPhase: Double) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        // 1. Rotating Disco Spotlights
        let ballCenter = NSPoint(x: 75, y: 22)
        let beamColors: [NSColor] = [
            NSColor(calibratedRed: 1.0, green: 0.15, blue: 0.80, alpha: 0.26), // Neon Magenta
            NSColor(calibratedRed: 0.0, green: 0.90, blue: 1.00, alpha: 0.26), // Cyan
            NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.10, alpha: 0.24), // Gold
            NSColor(calibratedRed: 0.65, green: 0.20, blue: 1.00, alpha: 0.26), // Purple
            NSColor(calibratedRed: 0.20, green: 1.00, blue: 0.40, alpha: 0.24)  // Neon Green
        ]

        for i in 0..<5 {
            let beamAngle = discoPhase * 1.5 + Double(i) * (.pi * 2.0 / 5.0)
            let length: CGFloat = 160
            let spread: CGFloat = 0.32

            let leftAngle = beamAngle - Double(spread)
            let rightAngle = beamAngle + Double(spread)

            let p1 = NSPoint(x: ballCenter.x + CGFloat(sin(leftAngle)) * length, y: ballCenter.y + CGFloat(cos(leftAngle)) * length)
            let p2 = NSPoint(x: ballCenter.x + CGFloat(sin(rightAngle)) * length, y: ballCenter.y + CGFloat(cos(rightAngle)) * length)

            let beamPath = NSBezierPath()
            beamPath.move(to: ballCenter)
            beamPath.line(to: p1)
            beamPath.line(to: p2)
            beamPath.close()

            beamColors[i % beamColors.count].setFill()
            beamPath.fill()
        }

        // 2. Disco Ball Chain
        let chain = NSBezierPath()
        chain.move(to: NSPoint(x: ballCenter.x, y: 0))
        chain.line(to: NSPoint(x: ballCenter.x, y: ballCenter.y - 12))
        chain.lineWidth = 1.8
        chain.lineCapStyle = .round
        NSColor(white: 0.88, alpha: 0.95).setStroke()
        chain.stroke()

        // 3. Disco Ball Sphere
        let ballRadius: CGFloat = 13.0
        let ballRect = NSRect(x: ballCenter.x - ballRadius, y: ballCenter.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)

        let ballBase = NSGradient(starting: NSColor(white: 0.98, alpha: 1.0), ending: NSColor(white: 0.38, alpha: 1.0))
        ballBase?.draw(in: NSBezierPath(ovalIn: ballRect), angle: 45)

        // Shimmering facets on disco ball
        let facetCols = 6
        let facetRows = 5
        for r in 0..<facetRows {
            for c in 0..<facetCols {
                let u = Double(c) / Double(facetCols)
                let v = Double(r) / Double(facetRows)
                let sparkleVal = sin(discoPhase * 4.5 + u * 10.0 + v * 7.0)
                let facetAlpha = CGFloat(0.35 + max(0, sparkleVal) * 0.65)
                let facetColor = (sparkleVal > 0.35) ? NSColor.white.withAlphaComponent(facetAlpha) : NSColor(white: 0.22, alpha: 0.35)

                let fx = ballRect.minX + CGFloat(u) * (ballRect.width - 4) + 1.8
                let fy = ballRect.minY + CGFloat(v) * (ballRect.height - 4) + 1.8
                let facetPath = NSBezierPath(roundedRect: NSRect(x: fx, y: fy, width: 3.2, height: 3.2), xRadius: 0.6, yRadius: 0.6)
                facetColor.setFill()
                facetPath.fill()
            }
        }

        // Glint on top corner of disco ball
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: ballCenter.x - 7, y: ballCenter.y - 8, width: 4.5, height: 3.5)).fill()

        // Outer ring
        NSColor.white.withAlphaComponent(0.7).setStroke()
        let ringPath = NSBezierPath(ovalIn: ballRect.insetBy(dx: 0.5, dy: 0.5))
        ringPath.lineWidth = 1.0
        ringPath.stroke()

        // 4. Floating Musical Notes & Party Sparkles
        let icons = ["🪩", "✨", "🎵", "🎶", "⭐️"]
        let positions: [(CGFloat, CGFloat)] = [
            (18, 38), (116, 34), (12, 88), (118, 92), (92, 24)
        ]

        for (idx, pos) in positions.enumerated() {
            let offsetPhase = discoPhase * 2.2 + Double(idx) * 1.4
            let floatY = pos.1 + CGFloat(sin(offsetPhase)) * 5.5
            let icon = icons[idx % icons.count]
            let str = NSAttributedString(string: icon, attributes: [.font: NSFont.systemFont(ofSize: 13)])
            str.draw(at: NSPoint(x: pos.0, y: floatY))
        }

        context.restoreGraphicsState()
    }

    private func drawGradientPath(_ path: NSBezierPath, topColor: NSColor, bottomColor: NSColor, angle: CGFloat = 90) {
        let gradient = NSGradient(starting: topColor, ending: bottomColor)
        gradient?.draw(in: path, angle: angle)
    }

    private func drawBird(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        let bodyTop = bodyColor.blended(withFraction: 0.28, of: .white) ?? bodyColor
        let bodyBottom = bodyColor.blended(withFraction: 0.18, of: .black) ?? bodyColor

        // Bouncy Head Feather Crest (3 tufts)
        let crestColor = bodyTop.blended(withFraction: 0.15, of: .white) ?? bodyTop
        crestColor.setFill()
        let crest1 = NSBezierPath(ovalIn: NSRect(x: 43, y: 1, width: 27, height: 28))
        let crest2 = NSBezierPath(ovalIn: NSRect(x: 61, y: -3, width: 29, height: 35))
        let crest3 = NSBezierPath(ovalIn: NSRect(x: 81, y: 2, width: 27, height: 28))
        crest1.fill(); crest2.fill(); crest3.fill()

        // Soft crest shine highlight
        NSColor.white.withAlphaComponent(0.25).setFill()
        NSBezierPath(ovalIn: NSRect(x: 66, y: 2, width: 18, height: 12)).fill()

        // Wings (layered wing rendering with feather tip highlights)
        drawWing(in: NSRect(x: 5 + leftWingFlap * 0.22, y: 73, width: 34, height: 53), angle: leftWingFlap, isLeft: true, bodyColor: bodyColor)
        drawWing(in: NSRect(x: 111 - rightWingFlap * 0.22, y: 73, width: 34, height: 53), angle: -rightWingFlap, isLeft: false, bodyColor: bodyColor)

        // Main Bird Body Gradient
        let bodyRect = NSRect(x: 17, y: 23, width: 116, height: 113)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 45, yRadius: 45)
        drawGradientPath(bodyPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)

        // Feathers texture lines on side body
        drawBirdFeathers(color: bodyTop.withAlphaComponent(0.40))

        // Belly Patch Gradient (plush 3D chest)
        let bellyTop = bellyColor.blended(withFraction: 0.10, of: .white) ?? bellyColor
        let bellyBottom = bellyColor.blended(withFraction: 0.12, of: .black) ?? bellyColor
        let bellyPath1 = NSBezierPath(ovalIn: NSRect(x: 19, y: 29, width: 112, height: 83))
        let bellyPath2 = NSBezierPath(ovalIn: NSRect(x: 42, y: 88, width: 66, height: 47))
        drawGradientPath(bellyPath1, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)
        drawGradientPath(bellyPath2, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        // Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 29, y: 38, width: 39, height: 45), rightEyeRect: NSRect(x: 82, y: 38, width: 39, height: 45))

        // Brows
        NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.72, alpha: 1).setStroke()
        let brows = NSBezierPath(); brows.lineWidth = 3.5; brows.lineCapStyle = .round
        brows.move(to: NSPoint(x: 38, y: 31)); brows.curve(to: NSPoint(x: 53, y: 29), controlPoint1: NSPoint(x: 42, y: 27), controlPoint2: NSPoint(x: 49, y: 27))
        brows.move(to: NSPoint(x: 97, y: 29)); brows.curve(to: NSPoint(x: 112, y: 31), controlPoint1: NSPoint(x: 101, y: 27), controlPoint2: NSPoint(x: 108, y: 27)); brows.stroke()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 49, y: 82, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 31, y: 82, width: 18, height: 10)).fill()

        // 3D Beak with Specular Catchlight
        let beakTop = accentColor.blended(withFraction: 0.25, of: .white) ?? accentColor
        let beakBottom = accentColor.blended(withFraction: 0.22, of: .black) ?? accentColor
        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: bounds.midX, y: 68))
        beak.curve(to: NSPoint(x: bounds.midX + 11, y: 76), controlPoint1: NSPoint(x: bounds.midX + 7, y: 68), controlPoint2: NSPoint(x: bounds.midX + 11, y: 72))
        beak.curve(to: NSPoint(x: bounds.midX, y: 82), controlPoint1: NSPoint(x: bounds.midX + 7, y: 80), controlPoint2: NSPoint(x: bounds.midX + 3, y: 82))
        beak.curve(to: NSPoint(x: bounds.midX - 11, y: 76), controlPoint1: NSPoint(x: bounds.midX - 3, y: 82), controlPoint2: NSPoint(x: bounds.midX - 7, y: 80))
        beak.close()
        drawGradientPath(beak, topColor: beakTop, bottomColor: beakBottom, angle: 90)

        // Beak Mouth line & Gloss
        NSColor(calibratedRed: 0.72, green: 0.20, blue: 0.25, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 5, y: 76, width: 10, height: 7)).fill()
        NSColor.white.withAlphaComponent(0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 4, y: 71, width: 6, height: 3)).fill()

        // Feet / Claws with highlights
        let feetTuck = flightIntensity * 6.0
        accentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 30, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 84, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 98, y: 123 - feetTuck, width: 22, height: 15 - flightIntensity * 3)).fill()

        // Toe Highlights
        NSColor.white.withAlphaComponent(0.40).setFill()
        NSBezierPath(ovalIn: NSRect(x: 35, y: 125 - feetTuck, width: 6, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 89, y: 125 - feetTuck, width: 6, height: 4)).fill()
    }

    private func drawDog(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        let bodyTop = bodyColor.blended(withFraction: 0.22, of: .white) ?? bodyColor
        let bodyBottom = bodyColor.blended(withFraction: 0.16, of: .black) ?? bodyColor

        // Wagging Tail with Gradient Shading
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let tailAnchor = NSPoint(x: 116, y: 94)
        let tailTransform = NSAffineTransform()
        tailTransform.translateX(by: tailAnchor.x, yBy: tailAnchor.y)
        tailTransform.rotate(byDegrees: rightWingFlap * 1.1)
        tailTransform.translateX(by: -tailAnchor.x, yBy: -tailAnchor.y)
        tailTransform.concat()

        let tailPath = NSBezierPath()
        tailPath.move(to: NSPoint(x: 114, y: 92))
        tailPath.curve(to: NSPoint(x: 136, y: 68), controlPoint1: NSPoint(x: 124, y: 88), controlPoint2: NSPoint(x: 136, y: 78))
        tailPath.curve(to: NSPoint(x: 118, y: 100), controlPoint1: NSPoint(x: 130, y: 78), controlPoint2: NSPoint(x: 124, y: 96))
        tailPath.close()
        drawGradientPath(tailPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 45)
        context.restoreGraphicsState()

        // Puppy Body Gradient
        let bodyPath = NSBezierPath(roundedRect: NSRect(x: 18, y: 24, width: 114, height: 110), xRadius: 46, yRadius: 46)
        drawGradientPath(bodyPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)

        // Cream Chest Patch (soft gradient)
        let bellyTop = bellyColor.blended(withFraction: 0.08, of: .white) ?? bellyColor
        let bellyBottom = bellyColor.blended(withFraction: 0.12, of: .black) ?? bellyColor
        let chestPath = NSBezierPath(ovalIn: NSRect(x: 34, y: 58, width: 82, height: 72))
        drawGradientPath(chestPath, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        // Floppy Puppy Ears with Soft Ear Shadow
        drawDogEar(in: NSRect(x: 10 + leftWingFlap * 0.18, y: 24, width: 34, height: 60), angle: leftWingFlap * 0.7, color: accentColor, isLeft: true)
        drawDogEar(in: NSRect(x: 106 - rightWingFlap * 0.18, y: 24, width: 34, height: 60), angle: -rightWingFlap * 0.7, color: accentColor, isLeft: false)

        // Cream Muzzle Patch
        let muzzlePath = NSBezierPath(ovalIn: NSRect(x: 44, y: 64, width: 62, height: 46))
        drawGradientPath(muzzlePath, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        // Puppy Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 32, y: 38, width: 37, height: 43), rightEyeRect: NSRect(x: 81, y: 38, width: 37, height: 43))

        // Puppy Brows
        accentColor.withAlphaComponent(0.85).setStroke()
        let brows = NSBezierPath(); brows.lineWidth = 3; brows.lineCapStyle = .round
        brows.move(to: NSPoint(x: 40, y: 32)); brows.curve(to: NSPoint(x: 54, y: 30), controlPoint1: NSPoint(x: 44, y: 28), controlPoint2: NSPoint(x: 50, y: 28))
        brows.move(to: NSPoint(x: 96, y: 30)); brows.curve(to: NSPoint(x: 110, y: 32), controlPoint1: NSPoint(x: 100, y: 28), controlPoint2: NSPoint(x: 106, y: 28)); brows.stroke()

        // 3D Wet Button Nose
        let noseTop = accentColor.blended(withFraction: 0.25, of: .white) ?? accentColor
        let noseBottom = accentColor.blended(withFraction: 0.30, of: .black) ?? accentColor
        let nosePath = NSBezierPath(roundedRect: NSRect(x: 67, y: 68, width: 16, height: 12), xRadius: 5, yRadius: 5)
        drawGradientPath(nosePath, topColor: noseTop, bottomColor: noseBottom, angle: 90)

        // Specular Catchlight on Nose
        NSColor.white.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 70, y: 69, width: 5, height: 3)).fill()

        // Puppy Smile & Tongue
        accentColor.setStroke()
        let mouth = NSBezierPath(); mouth.lineWidth = 2.5; mouth.lineCapStyle = .round
        mouth.move(to: NSPoint(x: 75, y: 80)); mouth.line(to: NSPoint(x: 75, y: 84))
        mouth.move(to: NSPoint(x: 66, y: 84)); mouth.curve(to: NSPoint(x: 75, y: 86), controlPoint1: NSPoint(x: 68, y: 87), controlPoint2: NSPoint(x: 72, y: 87))
        mouth.curve(to: NSPoint(x: 84, y: 84), controlPoint1: NSPoint(x: 78, y: 87), controlPoint2: NSPoint(x: 82, y: 87)); mouth.stroke()

        // Cute Pink Tongue
        NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.55, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 85, width: 7, height: 8)).fill()
        NSColor.white.withAlphaComponent(0.40).setFill()
        NSBezierPath(ovalIn: NSRect(x: 74, y: 86, width: 3, height: 3)).fill()

        // Glossy Leather Collar & Medal Pendant
        let collarColor = NSColor(calibratedRed: 0.88, green: 0.22, blue: 0.28, alpha: 1.0)
        collarColor.setStroke()
        let collar = NSBezierPath(); collar.lineWidth = 4.2; collar.lineCapStyle = .round
        collar.move(to: NSPoint(x: 47, y: 103)); collar.curve(to: NSPoint(x: 103, y: 103), controlPoint1: NSPoint(x: 62, y: 109), controlPoint2: NSPoint(x: 88, y: 109)); collar.stroke()

        // Gold Shiny Medal
        NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 71, y: 101, width: 9, height: 9)).fill()
        NSColor.white.withAlphaComponent(0.70).setFill()
        NSBezierPath(ovalIn: NSRect(x: 73, y: 102, width: 3, height: 3)).fill()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 48, y: 80, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 30, y: 80, width: 18, height: 10)).fill()

        // Paws with Paw Pads
        let feetTuck = flightIntensity * 6.0
        let pawTop = accentColor.blended(withFraction: 0.15, of: .white) ?? accentColor
        let pawBottom = accentColor.blended(withFraction: 0.15, of: .black) ?? accentColor
        let leftPaw = NSBezierPath(roundedRect: NSRect(x: 36, y: 123 - feetTuck, width: 26, height: 16), xRadius: 8, yRadius: 8)
        let rightPaw = NSBezierPath(roundedRect: NSRect(x: 88, y: 123 - feetTuck, width: 26, height: 16), xRadius: 8, yRadius: 8)
        drawGradientPath(leftPaw, topColor: pawTop, bottomColor: pawBottom, angle: 90)
        drawGradientPath(rightPaw, topColor: pawTop, bottomColor: pawBottom, angle: 90)

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

        let earTop = color.blended(withFraction: 0.25, of: .white) ?? color
        let earBottom = color.blended(withFraction: 0.20, of: .black) ?? color
        let earPath = NSBezierPath(roundedRect: frame, xRadius: 16, yRadius: 16)
        drawGradientPath(earPath, topColor: earTop, bottomColor: earBottom, angle: 90)

        // Inner ear fold highlight
        color.blended(withFraction: 0.35, of: .white)?.setFill()
        NSBezierPath(ovalIn: NSRect(x: frame.minX + 7, y: frame.minY + 8, width: 8, height: 12)).fill()
        context.restoreGraphicsState()
    }

    private func drawCat(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        let bodyTop = bodyColor.blended(withFraction: 0.25, of: .white) ?? bodyColor
        let bodyBottom = bodyColor.blended(withFraction: 0.18, of: .black) ?? bodyColor

        // Swishing Cat Tail with Gradient Shading
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let tailAnchor = NSPoint(x: 114, y: 96)
        let tailTransform = NSAffineTransform()
        tailTransform.translateX(by: tailAnchor.x, yBy: tailAnchor.y)
        tailTransform.rotate(byDegrees: rightWingFlap * 0.9)
        tailTransform.translateX(by: -tailAnchor.x, yBy: -tailAnchor.y)
        tailTransform.concat()

        bodyTop.setStroke()
        let tail = NSBezierPath()
        tail.lineWidth = 11; tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 112, y: 94))
        tail.curve(to: NSPoint(x: 136, y: 58), controlPoint1: NSPoint(x: 128, y: 90), controlPoint2: NSPoint(x: 140, y: 74))
        tail.stroke()

        // Tail tip highlight
        bodyTop.blended(withFraction: 0.40, of: .white)?.setFill()
        NSBezierPath(ovalIn: NSRect(x: 131, y: 54, width: 8, height: 8)).fill()
        context.restoreGraphicsState()

        // Pointy Cat Ears
        drawCatEar(tip: NSPoint(x: 36 + leftWingFlap * 0.12, y: 6), baseLeft: NSPoint(x: 18, y: 40), baseRight: NSPoint(x: 54, y: 30), bodyColor: bodyColor, innerColor: accentColor)
        drawCatEar(tip: NSPoint(x: 114 - rightWingFlap * 0.12, y: 6), baseLeft: NSPoint(x: 96, y: 30), baseRight: NSPoint(x: 132, y: 40), bodyColor: bodyColor, innerColor: accentColor)

        // Cat Body Gradient
        let bodyPath = NSBezierPath(roundedRect: NSRect(x: 20, y: 28, width: 110, height: 106), xRadius: 44, yRadius: 44)
        drawGradientPath(bodyPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)

        // Cream Chest
        let bellyTop = bellyColor.blended(withFraction: 0.08, of: .white) ?? bellyColor
        let bellyBottom = bellyColor.blended(withFraction: 0.10, of: .black) ?? bellyColor
        let chestPath = NSBezierPath(ovalIn: NSRect(x: 36, y: 62, width: 78, height: 68))
        drawGradientPath(chestPath, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        // Muzzle Mounds
        let muzzleLeft = NSBezierPath(ovalIn: NSRect(x: 48, y: 68, width: 28, height: 22))
        let muzzleRight = NSBezierPath(ovalIn: NSRect(x: 74, y: 68, width: 28, height: 22))
        drawGradientPath(muzzleLeft, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)
        drawGradientPath(muzzleRight, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        // Forehead Tuft
        let catHighlight = bodyColor.blended(withFraction: 0.28, of: .white) ?? bodyColor
        catHighlight.setFill()
        let foreheadTuft = NSBezierPath()
        foreheadTuft.move(to: NSPoint(x: 65, y: 28))
        foreheadTuft.curve(to: NSPoint(x: 75, y: 39), controlPoint1: NSPoint(x: 67, y: 31), controlPoint2: NSPoint(x: 70, y: 36))
        foreheadTuft.curve(to: NSPoint(x: 85, y: 28), controlPoint1: NSPoint(x: 80, y: 36), controlPoint2: NSPoint(x: 83, y: 31))
        foreheadTuft.curve(to: NSPoint(x: 75, y: 33), controlPoint1: NSPoint(x: 81, y: 28), controlPoint2: NSPoint(x: 77, y: 30))
        foreheadTuft.curve(to: NSPoint(x: 65, y: 28), controlPoint1: NSPoint(x: 72, y: 30), controlPoint2: NSPoint(x: 68, y: 28))
        foreheadTuft.fill()

        // Cat Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 30, y: 38, width: 38, height: 43), rightEyeRect: NSRect(x: 82, y: 38, width: 38, height: 43))

        // Pink Heart/Triangle Nose with Specular Highlight
        let noseTop = accentColor.blended(withFraction: 0.25, of: .white) ?? accentColor
        let noseBottom = accentColor.blended(withFraction: 0.20, of: .black) ?? accentColor
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 70, y: 70)); nose.curve(to: NSPoint(x: 75, y: 76), controlPoint1: NSPoint(x: 71, y: 74), controlPoint2: NSPoint(x: 73, y: 76)); nose.curve(to: NSPoint(x: 80, y: 70), controlPoint1: NSPoint(x: 77, y: 76), controlPoint2: NSPoint(x: 79, y: 74)); nose.curve(to: NSPoint(x: 75, y: 69), controlPoint1: NSPoint(x: 79, y: 68), controlPoint2: NSPoint(x: 76, y: 68)); nose.curve(to: NSPoint(x: 70, y: 70), controlPoint1: NSPoint(x: 74, y: 68), controlPoint2: NSPoint(x: 71, y: 68))
        drawGradientPath(nose, topColor: noseTop, bottomColor: noseBottom, angle: 90)

        NSColor.white.withAlphaComponent(0.70).setFill()
        NSBezierPath(ovalIn: NSRect(x: 73.5, y: 70, width: 3, height: 2)).fill()

        // Mouth & Whisker Dots
        accentColor.setStroke()
        let mouth = NSBezierPath(); mouth.lineWidth = 2; mouth.lineCapStyle = .round
        mouth.move(to: NSPoint(x: 75, y: 76)); mouth.line(to: NSPoint(x: 75, y: 80))
        mouth.move(to: NSPoint(x: 75, y: 80)); mouth.curve(to: NSPoint(x: 67, y: 80), controlPoint1: NSPoint(x: 72, y: 84), controlPoint2: NSPoint(x: 69, y: 83))
        mouth.move(to: NSPoint(x: 75, y: 80)); mouth.curve(to: NSPoint(x: 83, y: 80), controlPoint1: NSPoint(x: 81, y: 83), controlPoint2: NSPoint(x: 78, y: 84)); mouth.stroke()

        accentColor.withAlphaComponent(0.62).setFill()
        for point in [NSPoint(x: 49, y: 77), NSPoint(x: 54, y: 81), NSPoint(x: 101, y: 77), NSPoint(x: 96, y: 81)] {
            NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: 2.5, height: 2.5)).fill()
        }

        // Cat Whiskers
        NSColor(calibratedWhite: 0.2, alpha: 0.55).setStroke()
        let whiskers = NSBezierPath(); whiskers.lineWidth = 1.6; whiskers.lineCapStyle = .round
        whiskers.move(to: NSPoint(x: 24, y: 74)); whiskers.line(to: NSPoint(x: 50, y: 76))
        whiskers.move(to: NSPoint(x: 22, y: 82)); whiskers.line(to: NSPoint(x: 49, y: 80))
        whiskers.move(to: NSPoint(x: 126, y: 74)); whiskers.line(to: NSPoint(x: 100, y: 76))
        whiskers.move(to: NSPoint(x: 128, y: 82)); whiskers.line(to: NSPoint(x: 101, y: 80)); whiskers.stroke()

        // Tabby Stripes
        accentColor.withAlphaComponent(0.58).setStroke()
        let stripes = NSBezierPath(); stripes.lineWidth = 2.2; stripes.lineCapStyle = .round
        stripes.move(to: NSPoint(x: 61, y: 31)); stripes.line(to: NSPoint(x: 65, y: 40))
        stripes.move(to: NSPoint(x: 75, y: 28)); stripes.line(to: NSPoint(x: 75, y: 39))
        stripes.move(to: NSPoint(x: 89, y: 31)); stripes.line(to: NSPoint(x: 85, y: 40)); stripes.stroke()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 48, y: 86, width: 18, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 30, y: 86, width: 18, height: 10)).fill()

        // Dainty Cat Paws & Toe Beans
        let feetTuck = flightIntensity * 6.0
        let pawTop = accentColor.blended(withFraction: 0.15, of: .white) ?? accentColor
        let pawBottom = accentColor.blended(withFraction: 0.15, of: .black) ?? accentColor
        let leftPaw = NSBezierPath(roundedRect: NSRect(x: 38, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7)
        let rightPaw = NSBezierPath(roundedRect: NSRect(x: 88, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7)
        drawGradientPath(leftPaw, topColor: pawTop, bottomColor: pawBottom, angle: 90)
        drawGradientPath(rightPaw, topColor: pawTop, bottomColor: pawBottom, angle: 90)

        bellyColor.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 128 - feetTuck, width: 6, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 100, y: 128 - feetTuck, width: 6, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 51, y: 130 - feetTuck, width: 4, height: 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 95, y: 130 - feetTuck, width: 4, height: 3)).fill()
    }

    private func drawCatEar(tip: NSPoint, baseLeft: NSPoint, baseRight: NSPoint, bodyColor: NSColor, innerColor: NSColor) {
        let earTop = bodyColor.blended(withFraction: 0.25, of: .white) ?? bodyColor
        let earBottom = bodyColor.blended(withFraction: 0.15, of: .black) ?? bodyColor
        let ear = NSBezierPath()
        ear.move(to: baseLeft); ear.line(to: tip); ear.line(to: baseRight); ear.close()
        drawGradientPath(ear, topColor: earTop, bottomColor: earBottom, angle: 90)

        let innerTop = innerColor.blended(withFraction: 0.20, of: .white) ?? innerColor
        let innerBottom = innerColor.blended(withFraction: 0.10, of: .black) ?? innerColor
        let inner = NSBezierPath()
        let innerTip = NSPoint(x: tip.x, y: tip.y + 7)
        let innerLeft = NSPoint(x: baseLeft.x + (tip.x - baseLeft.x) * 0.3 + 3, y: baseLeft.y - 3)
        let innerRight = NSPoint(x: baseRight.x + (tip.x - baseRight.x) * 0.3 - 3, y: baseRight.y - 3)
        inner.move(to: innerLeft); inner.line(to: innerTip); inner.line(to: innerRight); inner.close()
        drawGradientPath(inner, topColor: innerTop, bottomColor: innerBottom, angle: 90)
    }

    private func drawMonkey(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        let bodyTop = bodyColor.blended(withFraction: 0.25, of: .white) ?? bodyColor
        let bodyBottom = bodyColor.blended(withFraction: 0.18, of: .black) ?? bodyColor

        // Curled Monkey Tail with Gradient Stroke
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let tailAnchor = NSPoint(x: 112, y: 92)
        let tailTransform = NSAffineTransform()
        tailTransform.translateX(by: tailAnchor.x, yBy: tailAnchor.y)
        tailTransform.rotate(byDegrees: rightWingFlap * 0.9)
        tailTransform.translateX(by: -tailAnchor.x, yBy: -tailAnchor.y)
        tailTransform.concat()

        bodyTop.setStroke()
        let tail = NSBezierPath()
        tail.lineWidth = 9; tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 110, y: 90))
        tail.curve(to: NSPoint(x: 138, y: 58), controlPoint1: NSPoint(x: 126, y: 88), controlPoint2: NSPoint(x: 140, y: 72))
        tail.curve(to: NSPoint(x: 130, y: 50), controlPoint1: NSPoint(x: 136, y: 50), controlPoint2: NSPoint(x: 132, y: 48))
        tail.stroke()
        context.restoreGraphicsState()

        // Big Round Monkey Ears
        let earLeftPath = NSBezierPath(ovalIn: NSRect(x: 8 + leftWingFlap * 0.15, y: 42, width: 32, height: 32))
        let earRightPath = NSBezierPath(ovalIn: NSRect(x: 110 - rightWingFlap * 0.15, y: 42, width: 32, height: 32))
        drawGradientPath(earLeftPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)
        drawGradientPath(earRightPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)

        let bellyTop = bellyColor.blended(withFraction: 0.10, of: .white) ?? bellyColor
        let bellyBottom = bellyColor.blended(withFraction: 0.10, of: .black) ?? bellyColor
        let innerEarLeft = NSBezierPath(ovalIn: NSRect(x: 14 + leftWingFlap * 0.15, y: 47, width: 20, height: 20))
        let innerEarRight = NSBezierPath(ovalIn: NSRect(x: 116 - rightWingFlap * 0.15, y: 47, width: 20, height: 20))
        drawGradientPath(innerEarLeft, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)
        drawGradientPath(innerEarRight, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        accentColor.withAlphaComponent(0.28).setStroke()
        let earDetail = NSBezierPath(); earDetail.lineWidth = 1.5
        earDetail.appendArc(withCenter: NSPoint(x: 24 + leftWingFlap * 0.15, y: 57), radius: 7, startAngle: 205, endAngle: 335)
        earDetail.appendArc(withCenter: NSPoint(x: 126 - rightWingFlap * 0.15, y: 57), radius: 7, startAngle: 25, endAngle: 155)
        earDetail.stroke()

        // Monkey Body Gradient
        let bodyPath = NSBezierPath(roundedRect: NSRect(x: 22, y: 26, width: 106, height: 108), xRadius: 44, yRadius: 44)
        drawGradientPath(bodyPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)

        // Peach Heart Face Mask (Soft Gradient)
        let maskCircleL = NSBezierPath(ovalIn: NSRect(x: 28, y: 28, width: 50, height: 50))
        let maskCircleR = NSBezierPath(ovalIn: NSRect(x: 72, y: 28, width: 50, height: 50))
        let maskLower = NSBezierPath(ovalIn: NSRect(x: 36, y: 52, width: 78, height: 52))
        drawGradientPath(maskCircleL, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)
        drawGradientPath(maskCircleR, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)
        drawGradientPath(maskLower, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        // Belly Patch Gradient
        let bellyPath = NSBezierPath(ovalIn: NSRect(x: 42, y: 84, width: 66, height: 46))
        drawGradientPath(bellyPath, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

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
        let pawTop = accentColor.blended(withFraction: 0.15, of: .white) ?? accentColor
        let pawBottom = accentColor.blended(withFraction: 0.15, of: .black) ?? accentColor
        let leftPaw = NSBezierPath(roundedRect: NSRect(x: 36, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7)
        let rightPaw = NSBezierPath(roundedRect: NSRect(x: 90, y: 123 - feetTuck, width: 24, height: 15), xRadius: 7, yRadius: 7)
        drawGradientPath(leftPaw, topColor: pawTop, bottomColor: pawBottom, angle: 90)
        drawGradientPath(rightPaw, topColor: pawTop, bottomColor: pawBottom, angle: 90)
    }

    private func drawGiraffe(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        let bodyTop = bodyColor.blended(withFraction: 0.25, of: .white) ?? bodyColor
        let bodyBottom = bodyColor.blended(withFraction: 0.18, of: .black) ?? bodyColor

        // Giraffe Ossicones (3D Horns with Specular Ball Tops)
        let hornColor = accentColor
        hornColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 52, y: 8, width: 7, height: 22), xRadius: 3, yRadius: 3).fill()
        NSBezierPath(roundedRect: NSRect(x: 91, y: 8, width: 7, height: 22), xRadius: 3, yRadius: 3).fill()

        let ballTop = accentColor.blended(withFraction: 0.30, of: .white) ?? accentColor
        let ballBottom = accentColor.blended(withFraction: 0.20, of: .black) ?? accentColor
        let leftBall = NSBezierPath(ovalIn: NSRect(x: 48, y: 3, width: 15, height: 15))
        let rightBall = NSBezierPath(ovalIn: NSRect(x: 87, y: 3, width: 15, height: 15))
        drawGradientPath(leftBall, topColor: ballTop, bottomColor: ballBottom, angle: 90)
        drawGradientPath(rightBall, topColor: ballTop, bottomColor: ballBottom, angle: 90)

        NSColor.white.withAlphaComponent(0.60).setFill()
        NSBezierPath(ovalIn: NSRect(x: 51, y: 5, width: 4, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 90, y: 5, width: 4, height: 4)).fill()

        // Gentle Leaf Ears
        drawGiraffeEar(at: NSPoint(x: 24 + leftWingFlap * 0.15, y: 28), angle: leftWingFlap * 0.5, color: bodyColor, isLeft: true)
        drawGiraffeEar(at: NSPoint(x: 112 - rightWingFlap * 0.15, y: 28), angle: -rightWingFlap * 0.5, color: bodyColor, isLeft: false)

        // Long Neck & Head Gradient
        let neckPath = NSBezierPath(roundedRect: NSRect(x: 46, y: 64, width: 58, height: 72), xRadius: 20, yRadius: 20)
        let headPath = NSBezierPath(roundedRect: NSRect(x: 30, y: 18, width: 90, height: 74), xRadius: 36, yRadius: 36)
        drawGradientPath(neckPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)
        drawGradientPath(headPath, topColor: bodyTop, bottomColor: bodyBottom, angle: 90)

        // Fluffy Layered Mane
        drawGiraffeMane(color: accentColor.withAlphaComponent(0.85))

        // Giraffe Spots on Neck & Cheeks
        let spotColor = accentColor.blended(withFraction: 0.10, of: .white) ?? accentColor
        spotColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 52, y: 76, width: 18, height: 16), xRadius: 6, yRadius: 6).fill()
        NSBezierPath(roundedRect: NSRect(x: 78, y: 88, width: 20, height: 18), xRadius: 7, yRadius: 7).fill()
        NSBezierPath(roundedRect: NSRect(x: 54, y: 108, width: 18, height: 16), xRadius: 6, yRadius: 6).fill()
        NSBezierPath(ovalIn: NSRect(x: 32, y: 44, width: 10, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: 108, y: 44, width: 10, height: 10)).fill()

        // Soft Cream Muzzle
        let bellyTop = bellyColor.blended(withFraction: 0.08, of: .white) ?? bellyColor
        let bellyBottom = bellyColor.blended(withFraction: 0.10, of: .black) ?? bellyColor
        let muzzlePath = NSBezierPath(ovalIn: NSRect(x: 42, y: 52, width: 66, height: 42))
        drawGradientPath(muzzlePath, topColor: bellyTop, bottomColor: bellyBottom, angle: 90)

        // Eyes
        drawStandardEyes(leftEyeRect: NSRect(x: 34, y: 32, width: 35, height: 40), rightEyeRect: NSRect(x: 81, y: 32, width: 35, height: 40))

        // Nostrils & Smile
        accentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 66, y: 62, width: 5, height: 4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 79, y: 62, width: 5, height: 4)).fill()
        NSColor.white.withAlphaComponent(0.40).setFill()
        NSBezierPath(ovalIn: NSRect(x: 67.5, y: 62.5, width: 2, height: 1.5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 80.5, y: 62.5, width: 2, height: 1.5)).fill()

        accentColor.setStroke()
        let smile = NSBezierPath(); smile.lineWidth = 2.2; smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 68, y: 74)); smile.curve(to: NSPoint(x: 82, y: 74), controlPoint1: NSPoint(x: 72, y: 79), controlPoint2: NSPoint(x: 78, y: 79)); smile.stroke()

        // Blush Cheeks
        themePalette.blushColor.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 45, y: 66, width: 17, height: 9)).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX + 28, y: 66, width: 17, height: 9)).fill()

        // Cute Hooves
        let feetTuck = flightIntensity * 6.0
        let hoofTop = accentColor.blended(withFraction: 0.20, of: .white) ?? accentColor
        let hoofBottom = accentColor.blended(withFraction: 0.20, of: .black) ?? accentColor
        let leftHoof = NSBezierPath(roundedRect: NSRect(x: 48, y: 124 - feetTuck, width: 22, height: 14), xRadius: 5, yRadius: 5)
        let rightHoof = NSBezierPath(roundedRect: NSRect(x: 80, y: 124 - feetTuck, width: 22, height: 14), xRadius: 5, yRadius: 5)
        drawGradientPath(leftHoof, topColor: hoofTop, bottomColor: hoofBottom, angle: 90)
        drawGradientPath(rightHoof, topColor: hoofTop, bottomColor: hoofBottom, angle: 90)
    }

    private func drawGiraffeEar(at point: NSPoint, angle: CGFloat, color: NSColor, isLeft: Bool) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: point.x, yBy: point.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -point.x, yBy: -point.y)
        transform.concat()
        let earTop = color.blended(withFraction: 0.25, of: .white) ?? color
        let earBottom = color.blended(withFraction: 0.15, of: .black) ?? color
        let ear = NSBezierPath(ovalIn: NSRect(x: point.x - 14, y: point.y - 8, width: 28, height: 16))
        drawGradientPath(ear, topColor: earTop, bottomColor: earBottom, angle: 90)
        context.restoreGraphicsState()
    }

    private func drawSlinky(bodyColor: NSColor, bellyColor: NSColor, accentColor: NSColor) {
        // A friendly little spring: broad rounded coils make the silhouette read
        // clearly even at the compact 150-point buddy size.
        let highlight = bodyColor.blended(withFraction: 0.28, of: .white) ?? bodyColor
        let shadow = bodyColor.blended(withFraction: 0.22, of: .black) ?? bodyColor

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        let isRainbow = (themePreset == .rainbow)
        let rainbowCoilColors: [NSColor] = [
            NSColor(calibratedRed: 1.00, green: 0.20, blue: 0.28, alpha: 1.0), // 0: Vivid Red
            NSColor(calibratedRed: 1.00, green: 0.53, blue: 0.00, alpha: 1.0), // 1: Tangerine Orange
            NSColor(calibratedRed: 1.00, green: 0.85, blue: 0.00, alpha: 1.0), // 2: Sunshine Yellow
            NSColor(calibratedRed: 0.16, green: 0.82, blue: 0.38, alpha: 1.0), // 3: Emerald Green
            NSColor(calibratedRed: 0.00, green: 0.65, blue: 1.00, alpha: 1.0), // 4: Cyan Blue
            NSColor(calibratedRed: 0.66, green: 0.32, blue: 0.98, alpha: 1.0)  // 5: Electric Purple
        ]

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
        coil.stroke()

        let seg0 = NSBezierPath()
        seg0.move(to: NSPoint(x: 39, y: y0))
        seg0.curve(to: NSPoint(x: 111, y: y0), controlPoint1: NSPoint(x: 55, y: y0 - 13), controlPoint2: NSPoint(x: 95, y: y0 - 13))

        let seg1 = NSBezierPath()
        seg1.move(to: NSPoint(x: 111, y: y0))
        seg1.curve(to: NSPoint(x: 40, y: y1), controlPoint1: NSPoint(x: 126, y: y1 - 1), controlPoint2: NSPoint(x: 25, y: y1 + 1))

        let seg2 = NSBezierPath()
        seg2.move(to: NSPoint(x: 40, y: y1))
        seg2.curve(to: NSPoint(x: 110, y: y2), controlPoint1: NSPoint(x: 126, y: y2), controlPoint2: NSPoint(x: 24, y: y2 + 1))

        let seg3 = NSBezierPath()
        seg3.move(to: NSPoint(x: 110, y: y2))
        seg3.curve(to: NSPoint(x: 40, y: y3), controlPoint1: NSPoint(x: 126, y: y3), controlPoint2: NSPoint(x: 25, y: y3 + 1))

        let seg4 = NSBezierPath()
        seg4.move(to: NSPoint(x: 40, y: y3))
        seg4.curve(to: NSPoint(x: 110, y: y4), controlPoint1: NSPoint(x: 126, y: y4), controlPoint2: NSPoint(x: 25, y: y4 + 1))

        let seg5 = NSBezierPath()
        seg5.move(to: NSPoint(x: 110, y: y4))
        seg5.curve(to: NSPoint(x: 48, y: y5), controlPoint1: NSPoint(x: 119, y: y5), controlPoint2: NSPoint(x: 80, y: y5 + 10))

        let segments = [seg0, seg1, seg2, seg3, seg4, seg5]
        for (i, seg) in segments.enumerated() {
            seg.lineWidth = 15
            seg.lineCapStyle = .round
            seg.lineJoinStyle = .round
            if isRainbow {
                rainbowCoilColors[i].setStroke()
            } else {
                bodyColor.setStroke()
            }
            seg.stroke()
        }

        // Tubular Specular Highlight line on coils
        for (_, seg) in segments.enumerated() {
            seg.lineWidth = 2.8
            seg.lineCapStyle = .round
            NSColor.white.withAlphaComponent(0.35).setStroke()
            seg.stroke()
        }

        // Extra inner turns give the spring its playful swirl.
        let iy0: CGFloat = 39
        let iy1: CGFloat = 55 + bounce * 0.25
        let iy2: CGFloat = 72 + bounce * 0.5
        let iy3: CGFloat = 89 + bounce * 0.75
        let iy4: CGFloat = 105 + bounce * 1.0

        let iseg0 = NSBezierPath()
        iseg0.move(to: NSPoint(x: 45, y: iy0))
        iseg0.curve(to: NSPoint(x: 105, y: iy0), controlPoint1: NSPoint(x: 59, y: iy0 - 10), controlPoint2: NSPoint(x: 91, y: iy0 - 10))

        let iseg1 = NSBezierPath()
        iseg1.move(to: NSPoint(x: 105, y: iy0))
        iseg1.curve(to: NSPoint(x: 47, y: iy1), controlPoint1: NSPoint(x: 116, y: iy1 - 2), controlPoint2: NSPoint(x: 34, y: iy1))

        let iseg2 = NSBezierPath()
        iseg2.move(to: NSPoint(x: 47, y: iy1))
        iseg2.curve(to: NSPoint(x: 104, y: iy2), controlPoint1: NSPoint(x: 116, y: iy2), controlPoint2: NSPoint(x: 34, y: iy2 + 1))

        let iseg3 = NSBezierPath()
        iseg3.move(to: NSPoint(x: 104, y: iy2))
        iseg3.curve(to: NSPoint(x: 47, y: iy3), controlPoint1: NSPoint(x: 116, y: iy3), controlPoint2: NSPoint(x: 34, y: iy3 + 1))

        let iseg4 = NSBezierPath()
        iseg4.move(to: NSPoint(x: 47, y: iy3))
        iseg4.curve(to: NSPoint(x: 101, y: iy4), controlPoint1: NSPoint(x: 116, y: iy4), controlPoint2: NSPoint(x: 69, y: iy4 + 10))

        let innerSegments = [iseg0, iseg1, iseg2, iseg3, iseg4]
        for (i, iseg) in innerSegments.enumerated() {
            iseg.lineWidth = 4.2
            iseg.lineCapStyle = .round
            if isRainbow {
                rainbowCoilColors[i].blended(withFraction: 0.45, of: .white)?.setStroke() ?? rainbowCoilColors[i].setStroke()
            } else {
                highlight.withAlphaComponent(0.58).setStroke()
            }
            iseg.stroke()
        }

        // Curled tips peek out from either side
        if isRainbow {
            rainbowCoilColors[0].withAlphaComponent(0.85).setStroke()
        } else {
            accentColor.withAlphaComponent(0.7).setStroke()
        }
        let curls = NSBezierPath()
        curls.lineWidth = 3
        curls.lineCapStyle = .round
        curls.appendArc(withCenter: NSPoint(x: 28, y: 37 + bounce * 0.1), radius: 8, startAngle: 240, endAngle: 65)
        curls.appendArc(withCenter: NSPoint(x: 122, y: 37 + bounce * 0.1), radius: 8, startAngle: 115, endAngle: 300)
        curls.stroke()

        // Soft face plate
        let faceYOffset = bounce * 0.45
        let facePath = NSBezierPath(roundedRect: NSRect(x: 29, y: 27 + faceYOffset, width: 92, height: 67), xRadius: 30, yRadius: 30)
        let faceTop = bellyColor.blended(withFraction: 0.05, of: .white) ?? bellyColor
        let faceBottom = bellyColor.blended(withFraction: 0.08, of: .black) ?? bellyColor
        drawGradientPath(facePath, topColor: faceTop, bottomColor: faceBottom, angle: 90)

        highlight.withAlphaComponent(0.42).setStroke()
        let shine = NSBezierPath(); shine.lineWidth = 3; shine.lineCapStyle = .round
        shine.move(to: NSPoint(x: 42, y: 111 + bounce * 1.0))
        shine.curve(to: NSPoint(x: 105, y: 111 + bounce * 1.0), controlPoint1: NSPoint(x: 57, y: 120 + bounce * 1.0), controlPoint2: NSPoint(x: 91, y: 120 + bounce * 1.0))
        shine.stroke()

        let leftEyeRect = NSRect(x: 34, y: 39 + faceYOffset, width: 34, height: 38)
        let rightEyeRect = NSRect(x: 82, y: 39 + faceYOffset, width: 34, height: 38)
        let eyeAccent = isRainbow ? rainbowCoilColors[5] : accentColor
        if googlyEyesEnabled {
            drawGooglyEyes(leftEyeRect: leftEyeRect, rightEyeRect: rightEyeRect, accentColor: accentColor)
            drawGooglyEyes(leftEyeRect: leftEyeRect, rightEyeRect: rightEyeRect, accentColor: eyeAccent)
        } else {
            drawStandardEyes(leftEyeRect: leftEyeRect, rightEyeRect: rightEyeRect)
        }

        // Tiny center nub and a happy smile
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
        if isRainbow {
            rainbowCoilColors[4].setFill()
            NSBezierPath(ovalIn: NSRect(x: 38, y: 119 + bounce * 1.1 - feetTuck, width: 26, height: 17)).fill()
            rainbowCoilColors[5].setFill()
            NSBezierPath(ovalIn: NSRect(x: 86, y: 119 + bounce * 1.1 - feetTuck, width: 26, height: 17)).fill()
        } else {
            shadow.setFill()
            NSBezierPath(ovalIn: NSRect(x: 38, y: 119 + bounce * 1.1 - feetTuck, width: 26, height: 17)).fill()
            NSBezierPath(ovalIn: NSRect(x: 86, y: 119 + bounce * 1.1 - feetTuck, width: 26, height: 17)).fill()
        }
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 44, y: 123 + bounce * 1.1 - feetTuck, width: 14, height: 7)).fill()
        NSBezierPath(ovalIn: NSRect(x: 92, y: 123 + bounce * 1.1 - feetTuck, width: 14, height: 7)).fill()
        context.restoreGraphicsState()
    }

    private func drawGooglyEyes(leftEyeRect: NSRect, rightEyeRect: NSRect, accentColor: NSColor) {
        drawSingleGooglyEye(in: leftEyeRect, pupilOffset: leftGooglyPupilPos, stalkOffset: leftStalkPos, accentColor: accentColor)
        drawSingleGooglyEye(in: rightEyeRect, pupilOffset: rightGooglyPupilPos, stalkOffset: rightStalkPos, accentColor: accentColor)
    }

    private func drawSingleGooglyEye(in eyeRect: NSRect, pupilOffset: NSPoint, stalkOffset: NSPoint, accentColor: NSColor) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        let baseCenter = NSPoint(x: eyeRect.midX, y: eyeRect.midY + 3.0)
        let eyeCenter = NSPoint(x: eyeRect.midX + stalkOffset.x, y: eyeRect.midY - 5.0 + stalkOffset.y)
        let poppedRect = NSRect(x: eyeCenter.x - eyeRect.width / 2, y: eyeCenter.y - eyeRect.height / 2, width: eyeRect.width, height: eyeRect.height)

        // 1. Socket Base Gasket & Well (sunken metal ring on face plate)
        NSColor(calibratedWhite: 0.08, alpha: 0.40).setFill()
        NSBezierPath(ovalIn: NSRect(x: baseCenter.x - 14, y: baseCenter.y - 7, width: 28, height: 15)).fill()

        accentColor.withAlphaComponent(0.92).setStroke()
        let socketRim = NSBezierPath(ovalIn: NSRect(x: baseCenter.x - 14, y: baseCenter.y - 7, width: 28, height: 15))
        socketRim.lineWidth = 2.4
        socketRim.stroke()

        // 2. Coiled Micro-Spring Stalk
        let p0 = baseCenter
        let p1 = NSPoint(x: eyeCenter.x, y: eyeCenter.y + 11.0)
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        let coils = 3

        let springShadow = NSBezierPath()
        springShadow.lineWidth = 3.6
        springShadow.lineCapStyle = .round
        springShadow.lineJoinStyle = .round
        springShadow.move(to: p0)
        for i in 1...coils {
            let t = CGFloat(i) / CGFloat(coils)
            let prevT = CGFloat(i - 1) / CGFloat(coils)
            let midT = (t + prevT) / 2.0
            let side: CGFloat = (i % 2 == 1) ? 7.0 : -7.0
            let cx = p0.x + dx * midT + side
            let cy = p0.y + dy * midT
            let endX = p0.x + dx * t
            let endY = p0.y + dy * t
            springShadow.curve(to: NSPoint(x: endX, y: endY), controlPoint1: NSPoint(x: cx, y: cy - 2), controlPoint2: NSPoint(x: cx, y: cy + 2))
        }
        NSColor(calibratedWhite: 0.10, alpha: 0.55).setStroke()
        springShadow.stroke()

        let springBody = NSBezierPath()
        springBody.lineWidth = 2.2
        springBody.lineCapStyle = .round
        springBody.lineJoinStyle = .round
        springBody.move(to: p0)
        for i in 1...coils {
            let t = CGFloat(i) / CGFloat(coils)
            let prevT = CGFloat(i - 1) / CGFloat(coils)
            let midT = (t + prevT) / 2.0
            let side: CGFloat = (i % 2 == 1) ? 7.0 : -7.0
            let cx = p0.x + dx * midT + side
            let cy = p0.y + dy * midT
            let endX = p0.x + dx * t
            let endY = p0.y + dy * t
            springBody.curve(to: NSPoint(x: endX, y: endY), controlPoint1: NSPoint(x: cx, y: cy - 2), controlPoint2: NSPoint(x: cx, y: cy + 2))
        }
        accentColor.withAlphaComponent(0.95).setStroke()
        springBody.stroke()

        // 3. Drop Shadow of Elevated Eyeball on the face
        NSColor.black.withAlphaComponent(0.24).setFill()
        NSBezierPath(ovalIn: NSRect(x: baseCenter.x - 14 + stalkOffset.x * 0.25, y: baseCenter.y - 5 + stalkOffset.y * 0.25, width: 28, height: 14)).fill()

        // 4. White plastic backing disk
        NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: poppedRect).fill()

        // 5. Plastic capsule outer bevel wall
        NSColor(calibratedWhite: 0.12, alpha: 0.52).setStroke()
        let outerRim = NSBezierPath(ovalIn: poppedRect.insetBy(dx: 0.8, dy: 0.8))
        outerRim.lineWidth = 1.8
        outerRim.stroke()

        // Inner rim shadow for 3D depth inside the plastic chamber
        NSColor(calibratedWhite: 0.0, alpha: 0.10).setStroke()
        let innerRim = NSBezierPath(ovalIn: poppedRect.insetBy(dx: 2.2, dy: 2.2))
        innerRim.lineWidth = 1.2
        innerRim.stroke()

        // 6. Free-floating black disc pupil
        let pupilSize = NSSize(width: 17.5, height: 18.5)
        let pCenter = NSPoint(
            x: poppedRect.midX + pupilOffset.x,
            y: poppedRect.midY + pupilOffset.y
        )
        let pupilRect = NSRect(
            x: pCenter.x - pupilSize.width / 2,
            y: pCenter.y - pupilSize.height / 2,
            width: pupilSize.width,
            height: pupilSize.height
        )
        NSColor(calibratedWhite: 0.06, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: pupilRect).fill()

        // Specular highlight on the black disc pupil
        NSColor.white.withAlphaComponent(0.88).setFill()
        NSBezierPath(ovalIn: NSRect(x: pupilRect.minX + 3.2, y: pupilRect.minY + 3.2, width: 4.5, height: 4.5)).fill()

        // 7. Glossy clear plastic dome reflections
        NSColor.white.withAlphaComponent(0.40).setFill()
        NSBezierPath(ovalIn: NSRect(
            x: poppedRect.minX + 4.5,
            y: poppedRect.minY + 3.5,
            width: poppedRect.width * 0.50,
            height: poppedRect.height * 0.32
        )).fill()

        NSColor.white.withAlphaComponent(0.70).setFill()
        NSBezierPath(ovalIn: NSRect(
            x: poppedRect.minX + 7.5,
            y: poppedRect.minY + 5.0,
            width: 3.5,
            height: 2.2
        )).fill()

        NSColor.white.withAlphaComponent(0.18).setStroke()
        let botRim = NSBezierPath()
        botRim.lineWidth = 1.2
        botRim.appendArc(
            withCenter: NSPoint(x: poppedRect.midX, y: poppedRect.midY),
            radius: poppedRect.width * 0.42,
            startAngle: 300,
            endAngle: 40
        )
        botRim.stroke()

        context.restoreGraphicsState()
    }

    private func drawStandardEyes(leftEyeRect: NSRect, rightEyeRect: NSRect) {
        if eyesAreOpen {
            // Soft eye socket background shadow
            NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.28, alpha: 0.48).setStroke()
            let eyeOutline = NSBezierPath(); eyeOutline.lineWidth = 1.8
            eyeOutline.appendOval(in: leftEyeRect.insetBy(dx: 0.9, dy: 0.9))
            eyeOutline.appendOval(in: rightEyeRect.insetBy(dx: 0.9, dy: 0.9)); eyeOutline.stroke()

            // Eyeball Base Fill (soft gradient from bright white down)
            let eyeBaseTop = NSColor(white: 1.0, alpha: 1.0)
            let eyeBaseBottom = NSColor(white: 0.92, alpha: 1.0)
            drawGradientPath(NSBezierPath(ovalIn: leftEyeRect), topColor: eyeBaseTop, bottomColor: eyeBaseBottom, angle: 90)
            drawGradientPath(NSBezierPath(ovalIn: rightEyeRect), topColor: eyeBaseTop, bottomColor: eyeBaseBottom, angle: 90)

            // Upper Eyelid Soft Shadow
            NSColor(white: 0.0, alpha: 0.08).setFill()
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX, y: leftEyeRect.minY, width: leftEyeRect.width, height: leftEyeRect.height * 0.35)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX, y: rightEyeRect.minY, width: rightEyeRect.width, height: rightEyeRect.height * 0.35)).fill()

            // Rich Pupil Fill with Iris Gradient Depth
            let pupilTop = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.26, alpha: 1.0)
            let pupilBottom = NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.52, alpha: 1.0)
            let pw = leftEyeRect.width * 0.64
            let ph = leftEyeRect.height * 0.68

            let leftPupilRect = NSRect(x: leftEyeRect.minX + 7 + pupilOffset.x, y: leftEyeRect.minY + 8 + pupilOffset.y, width: pw, height: ph)
            let rightPupilRect = NSRect(x: rightEyeRect.minX + 7 + pupilOffset.x, y: rightEyeRect.minY + 8 + pupilOffset.y, width: pw, height: ph)
            drawGradientPath(NSBezierPath(ovalIn: leftPupilRect), topColor: pupilTop, bottomColor: pupilBottom, angle: 90)
            drawGradientPath(NSBezierPath(ovalIn: rightPupilRect), topColor: pupilTop, bottomColor: pupilBottom, angle: 90)

            // Eye Highlight Arc / Gradient
            themePalette.eyeHighlightColor.nsColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 9 + pupilOffset.x, y: leftEyeRect.maxY - 20 + pupilOffset.y, width: pw * 0.8, height: ph * 0.45)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 9 + pupilOffset.x, y: rightEyeRect.maxY - 20 + pupilOffset.y, width: pw * 0.8, height: ph * 0.45)).fill()

            // Primary & Secondary Catchlight Sparkles (anime/Disney style sparkle eyes)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 11 + pupilOffset.x, y: leftEyeRect.minY + 10 + pupilOffset.y, width: pw * 0.45, height: ph * 0.42)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 11 + pupilOffset.x, y: rightEyeRect.minY + 10 + pupilOffset.y, width: pw * 0.45, height: ph * 0.42)).fill()

            // Secondary cute catchlight dot
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 22 + pupilOffset.x, y: leftEyeRect.maxY - 19 + pupilOffset.y, width: 5, height: 6)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 22 + pupilOffset.x, y: rightEyeRect.maxY - 19 + pupilOffset.y, width: 5, height: 6)).fill()

            // Extra micro sparkle dot bottom right
            NSColor.white.withAlphaComponent(0.75).setFill()
            NSBezierPath(ovalIn: NSRect(x: leftEyeRect.minX + 24 + pupilOffset.x, y: leftEyeRect.minY + 14 + pupilOffset.y, width: 3.5, height: 3.5)).fill()
            NSBezierPath(ovalIn: NSRect(x: rightEyeRect.minX + 24 + pupilOffset.x, y: rightEyeRect.minY + 14 + pupilOffset.y, width: 3.5, height: 3.5)).fill()
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
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()
        NSColor.black.withAlphaComponent(0.12).setFill()
        NSBezierPath(ovalIn: NSRect(x: 26, y: 126, width: 98, height: 14)).fill()
        context.restoreGraphicsState()
    }

    private func drawRimHighlight() {
        NSColor.white.withAlphaComponent(0.18).setFill()
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

    private func drawHeadphones(for kind: AnimalKind, accentColor: NSColor) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        let (leftCenter, rightCenter, archTopY): (NSPoint, NSPoint, CGFloat) = switch kind {
        case .bird:
            (NSPoint(x: 27, y: 55), NSPoint(x: 123, y: 55), 14)
        case .dog:
            (NSPoint(x: 28, y: 55), NSPoint(x: 122, y: 55), 14)
        case .cat:
            (NSPoint(x: 29, y: 56), NSPoint(x: 121, y: 56), 16)
        case .monkey:
            (NSPoint(x: 21, y: 62), NSPoint(x: 129, y: 62), 16)
        case .giraffe:
            (NSPoint(x: 30, y: 56), NSPoint(x: 120, y: 56), 20)
        case .slinky:
            (NSPoint(x: 28, y: 56), NSPoint(x: 122, y: 56), 14)
        }

        // 1. Headband Arch (outer chassis)
        let headband = NSBezierPath()
        headband.move(to: NSPoint(x: leftCenter.x + 3, y: leftCenter.y - 6))
        headband.curve(
            to: NSPoint(x: rightCenter.x - 3, y: rightCenter.y - 6),
            controlPoint1: NSPoint(x: leftCenter.x + 14, y: archTopY),
            controlPoint2: NSPoint(x: rightCenter.x - 14, y: archTopY)
        )
        headband.lineCapStyle = .round

        // Outer dark chassis
        NSColor(calibratedWhite: 0.16, alpha: 0.98).setStroke()
        headband.lineWidth = 6.0
        headband.stroke()

        // Metallic accent stripe
        accentColor.withAlphaComponent(0.85).setStroke()
        headband.lineWidth = 1.8
        headband.stroke()

        // Soft underside cushion on the crown
        let innerCushion = NSBezierPath()
        innerCushion.move(to: NSPoint(x: 52, y: archTopY + 2.5))
        innerCushion.curve(
            to: NSPoint(x: 98, y: archTopY + 2.5),
            controlPoint1: NSPoint(x: 65, y: archTopY + 1.0),
            controlPoint2: NSPoint(x: 85, y: archTopY + 1.0)
        )
        NSColor(calibratedWhite: 0.28, alpha: 0.9).setStroke()
        innerCushion.lineWidth = 3.2
        innerCushion.lineCapStyle = .round
        innerCushion.stroke()

        // 2. Ear Cups (Padded DJ style cups)
        let cupWidth: CGFloat = 17
        let cupHeight: CGFloat = 28
        let leftCupRect = NSRect(x: leftCenter.x - cupWidth / 2, y: leftCenter.y - cupHeight / 2, width: cupWidth, height: cupHeight)
        let rightCupRect = NSRect(x: rightCenter.x - cupWidth / 2, y: rightCenter.y - cupHeight / 2, width: cupWidth, height: cupHeight)

        drawSingleEarCup(in: leftCupRect, isLeft: true, accentColor: accentColor)
        drawSingleEarCup(in: rightCupRect, isLeft: false, accentColor: accentColor)

        context.restoreGraphicsState()
    }

    private func drawSingleEarCup(in rect: NSRect, isLeft: Bool, accentColor: NSColor) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        let tilt: CGFloat = isLeft ? 5.0 : -5.0
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: tilt)
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        transform.concat()

        // A. Inner Soft Foam Cushion (contacts the ear)
        let cushionFrame = isLeft
            ? NSRect(x: rect.minX + 3, y: rect.minY + 2, width: rect.width - 4, height: rect.height - 4)
            : NSRect(x: rect.minX + 1, y: rect.minY + 2, width: rect.width - 4, height: rect.height - 4)
        let cushionPath = NSBezierPath(roundedRect: cushionFrame, xRadius: 7, yRadius: 7)
        NSColor(calibratedWhite: 0.12, alpha: 0.98).setFill()
        cushionPath.fill()

        // B. Outer Metallic Cup Shell
        let shellFrame = isLeft
            ? NSRect(x: rect.minX - 1, y: rect.minY, width: rect.width - 3, height: rect.height)
            : NSRect(x: rect.minX + 4, y: rect.minY, width: rect.width - 3, height: rect.height)
        let shellPath = NSBezierPath(roundedRect: shellFrame, xRadius: 8, yRadius: 8)
        let shellTop = NSColor(calibratedWhite: 0.36, alpha: 1.0)
        let shellBottom = NSColor(calibratedWhite: 0.18, alpha: 1.0)
        drawGradientPath(shellPath, topColor: shellTop, bottomColor: shellBottom, angle: 90)

        // C. Accent Ring on Outer Face
        accentColor.withAlphaComponent(0.92).setStroke()
        let ringPath = NSBezierPath(roundedRect: shellFrame.insetBy(dx: 2.2, dy: 3.0), xRadius: 5.5, yRadius: 5.5)
        ringPath.lineWidth = 1.6
        ringPath.stroke()

        // D. Aluminum Center Hub / Swivel Disc
        let hubCenter = NSPoint(x: shellFrame.midX, y: shellFrame.midY)
        let hubRect = NSRect(x: hubCenter.x - 3.5, y: hubCenter.y - 3.5, width: 7, height: 7)
        NSColor(calibratedWhite: 0.82, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: hubRect).fill()
        NSColor(calibratedWhite: 0.40, alpha: 0.8).setStroke()
        let hubBorder = NSBezierPath(ovalIn: hubRect)
        hubBorder.lineWidth = 0.8
        hubBorder.stroke()

        context.restoreGraphicsState()
    }

    private func drawFloatingMusicNotes(phase: Double) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()

        let notes: [(symbol: String, baseX: CGFloat, baseY: CGFloat, speed: Double, offset: Double, color: NSColor)] = [
            ("♪", 16.0, 22.0, 6.0, 0.0, NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.75, alpha: 1.0)),
            ("♫", 126.0, 20.0, 7.2, 2.4, NSColor(calibratedRed: 0.35, green: 0.75, blue: 1.0, alpha: 1.0)),
            ("♩", 100.0, 10.0, 5.5, 4.2, NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.25, alpha: 1.0))
        ]

        for note in notes {
            let cycle = fmod(phase * note.speed + note.offset, 28.0)
            let progress = cycle / 28.0
            let alpha = CGFloat(sin(progress * .pi)) * 0.92
            guard alpha > 0.05 else { continue }

            let sway = CGFloat(sin(phase * 2.0 + note.offset)) * 3.5
            let x = note.baseX + sway
            let y = note.baseY - CGFloat(cycle)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: note.color.withAlphaComponent(alpha)
            ]
            (note.symbol as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        }

        context.restoreGraphicsState()
    }

    private func drawSparkle(at point: NSPoint) {
        NSColor.systemYellow.setStroke()
        let sparkle = NSBezierPath(); sparkle.lineWidth = 2; sparkle.lineCapStyle = .round
        sparkle.move(to: NSPoint(x: point.x, y: point.y - 6)); sparkle.line(to: NSPoint(x: point.x, y: point.y + 6))
        sparkle.move(to: NSPoint(x: point.x - 6, y: point.y)); sparkle.line(to: NSPoint(x: point.x + 6, y: point.y)); sparkle.stroke()
    }

    private func drawWing(in frame: NSRect, angle: CGFloat, isLeft: Bool, bodyColor: NSColor = .systemBlue) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        let anchor = isLeft ? NSPoint(x: frame.maxX - 4, y: frame.minY + 12) : NSPoint(x: frame.minX + 4, y: frame.minY + 12)
        let transform = NSAffineTransform()
        transform.translateX(by: anchor.x, yBy: anchor.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -anchor.x, yBy: -anchor.y)
        transform.concat()

        let wingTop = bodyColor.blended(withFraction: 0.35, of: .white) ?? bodyColor
        let wingBottom = bodyColor.blended(withFraction: 0.15, of: .black) ?? bodyColor

        let wingPath = NSBezierPath(ovalIn: frame)
        drawGradientPath(wingPath, topColor: wingTop, bottomColor: wingBottom, angle: 90)

        let innerFrame = frame.insetBy(dx: 4, dy: 6)
        let innerWing = NSBezierPath(ovalIn: innerFrame)
        wingTop.withAlphaComponent(0.45).setFill()
        innerWing.fill()

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
