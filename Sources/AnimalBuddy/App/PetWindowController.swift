import AppKit
import UniformTypeIdentifiers

final class PetWindowController: NSWindowController, NSWindowDelegate, NSDraggingDestination {
    private static let trackingRadius: CGFloat = 300
    private static let dismissRadius: CGFloat = 100
    private static let normalPetSize: CGFloat = 150
    private static let expandedPetSize: CGFloat = 210
    private let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
    private let registry: ActionRegistry
    private var settings: AppSettings
    private var mouseTrackingTimer: Timer?
    private var typingMonitor: Any?
    private var typingRestoreTimer: Timer?
    private var closeObserver: NSObjectProtocol?
    private var isMinimizing = false
    private var currentDragContext: DropContext?
    private var isAwaitingActionChoice = false
    private var isExternalDragHovering = false
    private let dragTargetOverlay = DragTargetOverlayController()
    private let actionPopover = DropActionPopoverController()
    init(settings: AppSettings, registry: ActionRegistry) {
        self.settings = settings; self.registry = registry
        let window = PetPanel(contentRect: NSRect(x: 120, y: 120, width: 150, height: 150), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true; window.level = settings.alwaysOnTop ? .floating : .normal; window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; window.isMovableByWindowBackground = true
        super.init(window: window); window.delegate = self; window.contentView = petView; petView.autoresizingMask = [.width, .height]; window.isMovableByWindowBackground = true
        window.onDragBegan = { [weak self] in
            self?.petView.setFlying(true)
            self?.dragTargetOverlay.show(at: NSEvent.mouseLocation, redness: 0)
            self?.updateDragFade(for: NSEvent.mouseLocation)
        }
        window.onDragChanged = { [weak self] point, velocity, deltaX in
            guard let self, let draggedWindow = self.window, let screen = draggedWindow.screen ?? NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return }
            self.petView.updateFlightMovement(velocity: velocity, deltaX: deltaX)
            let target = DragTargetOverlayController.targetCenter(for: point, in: screen.visibleFrame)
            let redness = DragTargetOverlayController.redness(for: draggedWindow.frame, target: target, boundaryRadius: Self.dismissRadius)
            self.dragTargetOverlay.show(at: point, redness: redness)
            self.updateDragFade(for: point)
        }
        window.onDragEnded = { [weak self] point, startFrame, endFrame, velocity in
            self?.finishPetDrag(at: point, startFrame: startFrame, endFrame: endFrame, velocity: velocity)
        }
        window.onDraggingEntered = { [weak self] sender in self?.draggingEntered(sender) ?? [] }
        window.onDraggingUpdated = { [weak self] sender in self?.draggingUpdated(sender) ?? [] }
        window.onDraggingExited = { [weak self] sender in self?.draggingExited(sender) }
        window.onPrepareForDragOperation = { [weak self] sender in self?.prepareForDragOperation(sender) ?? false }
        window.onPerformDragOperation = { [weak self] sender in self?.performDragOperation(sender) ?? false }
        petView.onDraggingEntered = { [weak self] sender in self?.draggingEntered(sender) ?? [] }
        petView.onDraggingUpdated = { [weak self] sender in self?.draggingUpdated(sender) ?? [] }
        petView.onDraggingExited = { [weak self] sender in self?.draggingExited(sender) }
        petView.onPrepareForDragOperation = { [weak self] sender in self?.prepareForDragOperation(sender) ?? false }
        petView.onPerformDragOperation = { [weak self] sender in self?.performDragOperation(sender) ?? false }
        petView.onMinimizeRequested = { [weak self] in self?.minimizePet() }
        petView.onBlushTapped = { [weak self] slot in self?.runMacro(for: slot) }
        petView.updateBlushMacroLabels(settings)
        petView.themePalette = settings.activePalette
        window.registerForDraggedTypes([.fileURL, .URL, .string])
        petView.registerForDraggedTypes([.fileURL, .URL, .string])
        startMouseTracking()
        startTypingAwareness()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(settings: AppSettings) {
        self.settings = settings
        window?.level = settings.alwaysOnTop ? .floating : .normal
        petView.themePalette = settings.activePalette
        petView.updateBlushMacroLabels(settings)
    }
    func minimizePet() {
        guard let window, !isMinimizing else { return }
        NSApp.setActivationPolicy(.regular)
        let originalFrame = window.frame
        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSScreen.main?.frame ?? originalFrame
        let targetSize = NSSize(width: 18, height: 18)
        let targetY = settings.minimizeDestination == .dock ? screenFrame.minY - 2 : screenFrame.maxY - targetSize.height + 2
        let targetFrame = NSRect(x: screenFrame.midX - targetSize.width / 2, y: targetY, width: targetSize.width, height: targetSize.height)
        isMinimizing = true

        let duration: TimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.12 : 0.48
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(targetFrame, display: true)
            window.animator().alphaValue = 0.05
        } completionHandler: { [weak self, weak window] in
            Task { @MainActor in
                window?.orderOut(nil)
                window?.setFrame(originalFrame, display: false)
                window?.alphaValue = 1
                self?.isMinimizing = false
            }
        }
    }
    func showPet() {
        if settings.minimizeDestination == .dock { NSApp.setActivationPolicy(.regular) }
        else { NSApp.setActivationPolicy(.regular) }
        showWindow(nil)
        window?.alphaValue = 1
        window?.orderFrontRegardless()
    }
    private func closePet() { window?.orderOut(nil) }

    private func startTypingAwareness() {
        typingMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.handleTypingBehindBuddy() }
        }
    }

    private func handleTypingBehindBuddy() {
        guard let window,
              window.isVisible,
              !isMinimizing,
              !isExternalDragHovering,
              NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        typingRestoreTimer?.invalidate()
        let typingAlpha: CGFloat = 0.32
        if window.alphaValue > typingAlpha {
            let duration: TimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : 0.12
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                window.animator().alphaValue = typingAlpha
            }
        }
        typingRestoreTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, let window = self.window, !self.isExternalDragHovering else { return }
                let duration: TimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : 0.24
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = duration
                    window.animator().alphaValue = 1
                }
            }
        }
    }

    private func stopTypingAwareness() {
        if let typingMonitor {
            NSEvent.removeMonitor(typingMonitor)
            self.typingMonitor = nil
        }
        typingRestoreTimer?.invalidate()
        typingRestoreTimer = nil
    }

    private func runMacro(for slot: BlushSlot) {
        let macro = slot == .left ? settings.leftBlushMacro : settings.rightBlushMacro
        guard macro.isConfigured else { return }
        let currentSettings = settings
        petView.state = .processing
        Task.detached {
            do {
                try MacroExecutor.run(macro, settings: currentSettings)
                await MainActor.run { [weak self] in self?.petView.state = .success; self?.resetSoon() }
            } catch {
                await MainActor.run { [weak self] in self?.petView.state = .failure; self?.resetSoon() }
            }
        }
    }

    private func finishPetDrag(at screenPoint: NSPoint, startFrame: NSRect, endFrame: NSRect, velocity: CGVector) {
        dragTargetOverlay.hide()
        guard let window, let screen = window.screen ?? NSScreen.screens.first(where: { $0.frame.contains(screenPoint) }) else {
            window?.alphaValue = 1
            petView.setFlying(false)
            return
        }
        let target = DragTargetOverlayController.targetCenter(for: screenPoint, in: screen.visibleFrame)
        let distance = hypot(endFrame.midX - target.x, endFrame.midY - target.y)
        guard distance <= Self.dismissRadius else {
            window.alphaValue = 1
            let speed = hypot(velocity.dx, velocity.dy)
            if speed > 60 {
                // Apply a very small, subtle inertia in the direction of the flick
                let inertiaFactor: CGFloat = 0.08
                let flingDistance = min(speed * inertiaFactor, 110.0)
                let flingDx = (velocity.dx / speed) * flingDistance
                let flingDy = (velocity.dy / speed) * flingDistance
                
                var targetFrame = endFrame.offsetBy(dx: flingDx, dy: flingDy)
                targetFrame.origin.x = min(max(targetFrame.origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - targetFrame.width)
                targetFrame.origin.y = min(max(targetFrame.origin.y, screen.visibleFrame.minY), screen.visibleFrame.maxY - targetFrame.height)
                
                if settings.snappingEnabled {
                    let edgeDistances: [(String, CGFloat)] = [
                        ("left", abs(targetFrame.minX - screen.visibleFrame.minX)),
                        ("right", abs(screen.visibleFrame.maxX - targetFrame.maxX)),
                        ("top", abs(screen.visibleFrame.maxY - targetFrame.maxY)),
                        ("bottom", abs(targetFrame.minY - screen.visibleFrame.minY))
                    ]
                    if let closest = edgeDistances.min(by: { $0.1 < $1.1 }), closest.1 < 80 {
                        switch closest.0 {
                        case "left": targetFrame.origin.x = screen.visibleFrame.minX
                        case "right": targetFrame.origin.x = screen.visibleFrame.maxX - targetFrame.width
                        case "top": targetFrame.origin.y = screen.visibleFrame.maxY - targetFrame.height
                        case "bottom": targetFrame.origin.y = screen.visibleFrame.minY
                        default: break
                        }
                    }
                    targetFrame.origin.x = min(max(targetFrame.origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - targetFrame.width)
                    targetFrame.origin.y = min(max(targetFrame.origin.y, screen.visibleFrame.minY), screen.visibleFrame.maxY - targetFrame.height)
                }
                
                let totalDx = targetFrame.origin.x - endFrame.origin.x
                petView.setFlying(true)
                petView.updateFlightMovement(velocity: min(speed / 600, 1.0), deltaX: totalDx > 0 ? 12 : (totalDx < 0 ? -12 : 0))
                
                let glideDuration: TimeInterval = min(max(Double(speed) / 1200.0, 0.22), 0.38)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = glideDuration
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                    window.animator().setFrame(targetFrame, display: true)
                } completionHandler: { [weak self] in
                    MainActor.assumeIsolated {
                        self?.petView.setFlying(false)
                    }
                }
            } else {
                if settings.snappingEnabled {
                    snapWindow(window, frame: endFrame, on: screen.visibleFrame)
                } else {
                    petView.setFlying(false)
                }
            }
            return
        }
        closePet()
        window.alphaValue = 1
        petView.setFlying(false)
    }

    private func snapWindow(_ window: NSWindow, frame: NSRect, on screenFrame: NSRect) {
        var target = frame
        let distances = [
            ("left", abs(frame.minX - screenFrame.minX)),
            ("right", abs(screenFrame.maxX - frame.maxX)),
            ("top", abs(screenFrame.maxY - frame.maxY)),
            ("bottom", abs(frame.minY - screenFrame.minY))
        ]
        switch distances.min(by: { $0.1 < $1.1 })?.0 {
        case "left": target.origin.x = screenFrame.minX
        case "right": target.origin.x = screenFrame.maxX - frame.width
        case "top": target.origin.y = screenFrame.maxY - frame.height
        case "bottom": target.origin.y = screenFrame.minY
        default: break
        }
        target.origin.x = min(max(target.origin.x, screenFrame.minX), screenFrame.maxX - target.width)
        target.origin.y = min(max(target.origin.y, screenFrame.minY), screenFrame.maxY - target.height)
        
        guard target != frame else {
            petView.setFlying(false)
            return
        }
        
        let deltaX = target.origin.x - frame.origin.x
        petView.setFlying(true)
        petView.updateFlightMovement(velocity: 0.6, deltaX: deltaX > 0 ? 8 : (deltaX < 0 ? -8 : 0))
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            window.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.petView.setFlying(false)
            }
        }
    }

    private func updateDragFade(for screenPoint: NSPoint) {
        guard let window, let screen = window.screen ?? NSScreen.screens.first(where: { $0.frame.contains(screenPoint) }) else { return }
        let target = DragTargetOverlayController.targetCenter(for: screenPoint, in: screen.visibleFrame)
        let distance = hypot(window.frame.midX - target.x, window.frame.midY - target.y)
        let fadeStart: CGFloat = 260
        let fadeEnd: CGFloat = 70
        let progress = min(max((fadeStart - distance) / (fadeStart - fadeEnd), 0), 1)
        window.alphaValue = 1 - progress * 0.88
    }
    override func windowDidLoad() {
        super.windowDidLoad()
        petView.setAccessibilityLabel("Animal Buddy desktop pet")
        petView.setAccessibilityRole(.image)
        if let window {
            closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopMouseTracking() }
            Task { @MainActor in self?.stopTypingAwareness() }
        }
        }
    }
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        beginExternalDragHover()
        _ = updateDragContext(from: sender)
        petView.state = .noticingDrag
        return .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        beginExternalDragHover()
        _ = updateDragContext(from: sender)
        petView.state = .waitingForDrop
        return .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        guard !isAwaitingActionChoice, petView.state != .processing else { return }
        endExternalDragHover()
        clearDragContext()
        petView.state = .idle
    }

    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let context = updateDragContext(from: sender)
        if let macro = settings.dragMacros.first(where: { $0.category == context.category })?.macro, macro.isConfigured {
            isAwaitingActionChoice = false
            endExternalDragHover()
            clearDragContext()
            execute(macro, for: context)
            return true
        }
        let configuredActions = registry.configuredActions(for: context.input, modifiers: context.modifiers)
        if let action = registry.action(for: context.input, modifiers: context.modifiers) ?? (configuredActions.count == 1 ? configuredActions.first : nil) {
            isAwaitingActionChoice = false
            endExternalDragHover()
            clearDragContext()
            execute(action, for: context)
            return true
        }
        guard configuredActions.count > 1 else {
            isAwaitingActionChoice = false
            endExternalDragHover()
            clearDragContext()
            petView.state = .dragRejected
            resetSoon()
            return false
        }
        isAwaitingActionChoice = true
        endExternalDragHover()
        showActionChooser(for: context, actions: configuredActions)
        return true
    }

    private func beginExternalDragHover() {
        guard !isExternalDragHovering, let window else { return }
        isExternalDragHovering = true
        petView.setDragHovering(true)
        petView.updateDragPresentation(DragPresentation(prop: .questionMark))
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let targetFrame = NSRect(x: center.x - Self.expandedPetSize / 2, y: center.y - Self.expandedPetSize / 2, width: Self.expandedPetSize, height: Self.expandedPetSize)
        animatePetFrame(to: targetFrame)
    }

    private func endExternalDragHover() {
        guard isExternalDragHovering, let window else { return }
        isExternalDragHovering = false
        petView.setDragHovering(false)
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let targetFrame = NSRect(x: center.x - Self.normalPetSize / 2, y: center.y - Self.normalPetSize / 2, width: Self.normalPetSize, height: Self.normalPetSize)
        animatePetFrame(to: targetFrame)
    }

    private func animatePetFrame(to targetFrame: NSRect) {
        let duration: TimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : 0.18
        guard let window else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }

    private func updateDragContext(from sender: NSDraggingInfo) -> DropContext {
        let pasteboard = sender.draggingPasteboard
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        let text = pasteboard.string(forType: .string)
        // AppKit exposes the drag source object, but not a reliable source-app
        // identity for every drag provider. Keep this metadata best-effort.
        let base = InputClassifier.detect(urls: urls, text: urls.isEmpty ? text : nil, modifiers: ModifierCombination(rawValue: currentModifierFlags()), sourceApplicationName: nil)
        let directAction = registry.action(for: base.input, modifiers: base.modifiers)
        let alternatives = registry.configuredActions(for: base.input, modifiers: base.modifiers)
        let proposedAction = directAction ?? (alternatives.count == 1 ? alternatives.first : nil)
        let presentation = DragPresentation(prop: base.presentation.prop, actionID: proposedAction?.descriptor.identifier, actionTitle: proposedAction?.descriptor.displayName)
        let context = base.withPresentation(presentation)
        currentDragContext = context
        petView.updateDragPresentation(presentation)
        return context
    }

    private func showActionChooser(for context: DropContext, actions: [any Action]) {
        actionPopover.show(actions: actions, context: context, relativeTo: petView) { [weak self] action in
            guard let self else { return }
            isAwaitingActionChoice = false
            clearDragContext()
            execute(action, for: context)
        } onCancel: { [weak self] in
            guard let self else { return }
            isAwaitingActionChoice = false
            clearDragContext()
            petView.state = .idle
        }
    }

    private func execute(_ action: any Action, for context: DropContext) {
        petView.state = .processing
        let destination = settings.destinationFolderPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        Task {
            do {
                try await action.execute(context: ActionContext(input: context.input, destinationFolder: destination))
                await MainActor.run { [weak self] in self?.petView.state = .success; self?.resetSoon() }
            } catch {
                await MainActor.run { [weak self] in self?.petView.state = .failure; self?.resetSoon() }
            }
        }
    }

    private func execute(_ macro: UserMacro, for context: DropContext) {
        petView.state = .processing
        let currentSettings = settings
        Task.detached {
            do {
                try MacroExecutor.run(macro, settings: currentSettings, input: context.input)
                await MainActor.run { [weak self] in self?.petView.state = .success; self?.resetSoon() }
            } catch {
                await MainActor.run { [weak self] in self?.petView.state = .failure; self?.resetSoon() }
            }
        }
    }

    private func clearDragContext() {
        currentDragContext = nil
        petView.updateDragPresentation(nil)
    }
    private func currentModifierFlags() -> Int { let flags = NSEvent.modifierFlags; var value = 0; if flags.contains(.option) { value |= ModifierCombination.option.rawValue }; if flags.contains(.command) { value |= ModifierCombination.command.rawValue }; if flags.contains(.shift) { value |= ModifierCombination.shift.rawValue }; if flags.contains(.control) { value |= ModifierCombination.control.rawValue }; return value }
    private func resetSoon() { DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self.petView.state = .idle } }

    private func startMouseTracking() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMouseTracking() }
        }
        if let mouseTrackingTimer { RunLoop.main.add(mouseTrackingTimer, forMode: .common) }
    }

    private func stopMouseTracking() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
    }

    private func updateMouseTracking() {
        guard let window else { return }
        let mouseLocation = NSEvent.mouseLocation
        let distance = Self.distance(from: mouseLocation, to: window.frame)
        guard distance <= Self.trackingRadius else {
            petView.setPupilOffset(.zero, animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
            return
        }

        let leftEyeCenter = NSPoint(x: petView.bounds.midX - 16, y: 48)
        let eyeInWindow = petView.convert(leftEyeCenter, to: nil)
        let eyeOnScreen = window.convertPoint(toScreen: eyeInWindow)
        let targetOffset = PetView.pupilOffset(towardScreenPoint: mouseLocation, fromScreenEyeCenter: eyeOnScreen)
        petView.setPupilOffset(targetOffset, animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    static func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(0, max(rect.minX - point.x, point.x - rect.maxX))
        let dy = max(0, max(rect.minY - point.y, point.y - rect.maxY))
        return hypot(dx, dy)
    }
}
