import AppKit

public enum SpeechBubbleTailPosition: Sendable {
    case bottom
    case top
}

@MainActor final class SpeechBubbleBackgroundView: NSView {
    var tailPosition: SpeechBubbleTailPosition = .bottom {
        didSet { needsDisplay = true }
    }
    var tailCenterXOffset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds
        guard bounds.width > 20 && bounds.height > 20 else { return }

        let tailHeight: CGFloat = 8
        let tailWidth: CGFloat = 14
        let cornerRadius: CGFloat = 12

        let bodyRect: NSRect
        if tailPosition == .bottom {
            bodyRect = NSRect(x: bounds.minX, y: bounds.minY + tailHeight, width: bounds.width, height: bounds.height - tailHeight)
        } else {
            bodyRect = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height - tailHeight)
        }

        let path = NSBezierPath()
        let minX = bodyRect.minX + 1
        let maxX = bodyRect.maxX - 1
        let minY = bodyRect.minY + 1
        let maxY = bodyRect.maxY - 1

        // Clamped tail center X
        let rawTailX = bounds.midX + tailCenterXOffset
        let tailCenterX = min(max(rawTailX, minX + cornerRadius + tailWidth / 2), maxX - cornerRadius - tailWidth / 2)

        if tailPosition == .bottom {
            // Start at bottom left after corner
            path.move(to: NSPoint(x: minX + cornerRadius, y: minY))

            // Bottom edge with downward tail
            path.line(to: NSPoint(x: tailCenterX - tailWidth / 2, y: minY))
            path.line(to: NSPoint(x: tailCenterX, y: bounds.minY + 1))
            path.line(to: NSPoint(x: tailCenterX + tailWidth / 2, y: minY))
            path.line(to: NSPoint(x: maxX - cornerRadius, y: minY))

            // Bottom-right corner
            path.appendArc(withCenter: NSPoint(x: maxX - cornerRadius, y: minY + cornerRadius), radius: cornerRadius, startAngle: 270, endAngle: 360)
            // Right edge
            path.line(to: NSPoint(x: maxX, y: maxY - cornerRadius))
            // Top-right corner
            path.appendArc(withCenter: NSPoint(x: maxX - cornerRadius, y: maxY - cornerRadius), radius: cornerRadius, startAngle: 0, endAngle: 90)
            // Top edge
            path.line(to: NSPoint(x: minX + cornerRadius, y: maxY))
            // Top-left corner
            path.appendArc(withCenter: NSPoint(x: minX + cornerRadius, y: maxY - cornerRadius), radius: cornerRadius, startAngle: 90, endAngle: 180)
            // Left edge
            path.line(to: NSPoint(x: minX, y: minY + cornerRadius))
            // Bottom-left corner
            path.appendArc(withCenter: NSPoint(x: minX + cornerRadius, y: minY + cornerRadius), radius: cornerRadius, startAngle: 180, endAngle: 270)
        } else {
            // Start at bottom-left
            path.move(to: NSPoint(x: minX + cornerRadius, y: minY))
            path.line(to: NSPoint(x: maxX - cornerRadius, y: minY))
            path.appendArc(withCenter: NSPoint(x: maxX - cornerRadius, y: minY + cornerRadius), radius: cornerRadius, startAngle: 270, endAngle: 360)
            path.line(to: NSPoint(x: maxX, y: maxY - cornerRadius))
            path.appendArc(withCenter: NSPoint(x: maxX - cornerRadius, y: maxY - cornerRadius), radius: cornerRadius, startAngle: 0, endAngle: 90)

            // Top edge with upward tail
            path.line(to: NSPoint(x: tailCenterX + tailWidth / 2, y: maxY))
            path.line(to: NSPoint(x: tailCenterX, y: bounds.maxY - 1))
            path.line(to: NSPoint(x: tailCenterX - tailWidth / 2, y: maxY))
            path.line(to: NSPoint(x: minX + cornerRadius, y: maxY))

            path.appendArc(withCenter: NSPoint(x: minX + cornerRadius, y: maxY - cornerRadius), radius: cornerRadius, startAngle: 90, endAngle: 180)
            path.line(to: NSPoint(x: minX, y: minY + cornerRadius))
            path.appendArc(withCenter: NSPoint(x: minX + cornerRadius, y: minY + cornerRadius), radius: cornerRadius, startAngle: 180, endAngle: 270)
        }
        path.close()

        // Fill background
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let fillColor = isDark ? NSColor(white: 0.16, alpha: 0.95) : NSColor(white: 0.98, alpha: 0.95)
        fillColor.setFill()
        path.fill()

        // Stroke border
        let strokeColor = isDark ? NSColor(white: 1.0, alpha: 0.15) : NSColor(white: 0.0, alpha: 0.12)
        strokeColor.setStroke()
        path.lineWidth = 1.0
        path.stroke()
    }
}

@MainActor final class SpeechBubbleWindowController: NSWindowController {
    var onDismiss: (() -> Void)?
    var onFocusBubbleClicked: ((_ isWorkReminder: Bool) -> Void)?

    private let backgroundView = SpeechBubbleBackgroundView()
    private let emojiLabel = NSTextField(labelWithString: "💡")
    private let titleLabel = NSTextField(labelWithString: "Helpful Tip")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let closeButton = NSButton()
    private var autoDismissTimer: Timer?
    private(set) var isVisible = false
    private var activeFocusSoundItem: FocusSoundItem?
    private var isFocusSoundReminderMode: Bool = false
    private var currentPetFrame: NSRect = .zero
    private var currentScreen: NSScreen?

    private static let bubbleWidth: CGFloat = 236
    private static let bubbleHeight: CGFloat = 86

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.bubbleWidth, height: Self.bubbleHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false

        super.init(window: panel)
        buildUI(in: panel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI(in panel: NSPanel) {
        guard let contentView = panel.contentView else { return }

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Content stack
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 4
        contentStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 14, right: 10)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor)
        ])

        // Header Row
        emojiLabel.font = .systemFont(ofSize: 13)
        emojiLabel.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 11.5, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        closeButton.title = "✕"
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.font = .systemFont(ofSize: 10, weight: .semibold)
        closeButton.target = self
        closeButton.action = #selector(dismissPressed)
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        let headerRow = NSStackView(views: [emojiLabel, titleLabel, closeButton])
        headerRow.orientation = .horizontal
        headerRow.spacing = 5
        headerRow.alignment = .centerY
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(headerRow)

        // Body message
        messageLabel.font = .systemFont(ofSize: 11, weight: .regular)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 3
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(messageLabel)

        NSLayoutConstraint.activate([
            headerRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -22),
            messageLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -22)
        ])

        // Add gesture recognizer to handle click anywhere on the bubble
        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(bubbleClicked))
        backgroundView.addGestureRecognizer(clickRecognizer)
    }

    func show(tip: AppTip, relativeTo petFrame: NSRect, in screen: NSScreen?, duration: TimeInterval = 7.0) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        activeFocusSoundItem = nil

        currentPetFrame = petFrame
        currentScreen = screen

        emojiLabel.stringValue = tip.emoji
        titleLabel.stringValue = tip.title
        messageLabel.stringValue = tip.message

        guard let window else { return }

        let targetFrame = calculateFrame(relativeTo: petFrame, in: screen)
        window.setFrame(targetFrame, display: true)
        window.alphaValue = 0
        window.orderFront(nil)
        isVisible = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            window.animator().alphaValue = 1.0
        }

        if duration > 0 {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
            }
        }
    }

    func showFocusSound(item: FocusSoundItem, animal: AnimalKind, isWorkReminderMode: Bool, relativeTo petFrame: NSRect, in screen: NSScreen?, duration: TimeInterval = 8.0) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil

        activeFocusSoundItem = item
        isFocusSoundReminderMode = isWorkReminderMode
        currentPetFrame = petFrame
        currentScreen = screen

        emojiLabel.stringValue = item.emoji
        titleLabel.stringValue = "\(animal.nameWithoutEmoji)"
        let callToAction = isWorkReminderMode ? "Click me for focus!" : "Click me for love!"
        messageLabel.stringValue = "\(item.text)\n\(callToAction)"

        guard let window else { return }

        let targetFrame = calculateFrame(relativeTo: petFrame, in: screen)
        window.setFrame(targetFrame, display: true)
        window.alphaValue = 0
        window.orderFront(nil)
        isVisible = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            window.animator().alphaValue = 1.0
        }

        if duration > 0 {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
            }
        }
    }

    func updatePosition(relativeTo petFrame: NSRect, in screen: NSScreen?) {
        guard isVisible, let window else { return }
        currentPetFrame = petFrame
        currentScreen = screen
        let targetFrame = calculateFrame(relativeTo: petFrame, in: screen)
        window.setFrame(targetFrame, display: true, animate: false)
    }

    func dismiss(animated: Bool = true) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        activeFocusSoundItem = nil
        guard isVisible, let window else { return }
        isVisible = false

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.window?.orderOut(nil)
                    self?.onDismiss?()
                }
            })
        } else {
            window.alphaValue = 0
            window.orderOut(nil)
            onDismiss?()
        }
    }

    @objc private func dismissPressed() {
        dismiss()
    }

    @objc private func bubbleClicked() {
        if let _ = activeFocusSoundItem {
            let isReminder = isFocusSoundReminderMode
            activeFocusSoundItem = nil
            onFocusBubbleClicked?(isReminder)

            autoDismissTimer?.invalidate()
            autoDismissTimer = nil

            if isReminder {
                emojiLabel.stringValue = "🎯"
                titleLabel.stringValue = "Focus Time!"
                messageLabel.stringValue = FocusReminderCatalog.randomReminder()
                autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.dismiss()
                    }
                }
            } else {
                emojiLabel.stringValue = "💖"
                titleLabel.stringValue = "Cute Companion"
                messageLabel.stringValue = CuteReactionCatalog.randomReaction()
                autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.dismiss()
                    }
                }
            }
        } else {
            dismiss()
        }
    }

    private func calculateFrame(relativeTo petFrame: NSRect, in screen: NSScreen?) -> NSRect {
        let scr = screen ?? NSScreen.main
        let screenFrame = scr?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let bubbleW = Self.bubbleWidth
        let bubbleH = Self.bubbleHeight

        let bubbleX = petFrame.midX - (bubbleW / 2)
        var bubbleY = petFrame.maxY + 6
        var tailPos: SpeechBubbleTailPosition = .bottom

        // If too high on screen, flip bubble to appear below pet
        if bubbleY + bubbleH > screenFrame.maxY - 8 {
            bubbleY = petFrame.minY - bubbleH - 6
            tailPos = .top
        }

        // Clamp horizontal position so it stays fully inside screen
        let clampedX = min(max(bubbleX, screenFrame.minX + 12), screenFrame.maxX - bubbleW - 12)
        let tailOffset = petFrame.midX - (clampedX + bubbleW / 2)

        backgroundView.tailPosition = tailPos
        backgroundView.tailCenterXOffset = tailOffset

        return NSRect(x: clampedX, y: bubbleY, width: bubbleW, height: bubbleH)
    }
}
