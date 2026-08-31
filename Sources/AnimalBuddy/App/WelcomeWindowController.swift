import AppKit

@MainActor final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    var onDismiss: (() -> Void)?

    private let presentation: WelcomePresentationKind
    private let primaryButton = NSButton()

    init(presentation: WelcomePresentationKind) {
        self.presentation = presentation

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = presentation.isFirstLaunch ? "Welcome to Animal Buddy" : "What's New in Animal Buddy"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        super.init(window: window)
        window.delegate = self

        buildUI(in: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .centerX
        rootStack.spacing = 18
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // 1. Header Icon
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72)
        ])

        if let iconURL = Bundle.main.url(forResource: "AnimalBuddyIcon", withExtension: "png"),
           let iconImg = NSImage(contentsOf: iconURL) {
            iconView.image = iconImg
        } else if let symbol = NSImage(systemSymbolName: presentation.isFirstLaunch ? "pawprint.circle.fill" : "sparkles", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 52, weight: .regular)
            iconView.image = symbol.withSymbolConfiguration(config)
            iconView.contentTintColor = .systemBlue
        }
        rootStack.addArrangedSubview(iconView)

        // 2. Titles
        let headerStack = NSStackView()
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 6

        let titleLabel = NSTextField(labelWithString: presentation.headerTitle)
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        headerStack.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(wrappingLabelWithString: presentation.headerSubtitle)
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        headerStack.addArrangedSubview(subtitleLabel)

        rootStack.addArrangedSubview(headerStack)

        // 3. Scrollable Features Content
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentStack = NSStackView()
        documentStack.orientation = .vertical
        documentStack.alignment = .leading
        documentStack.spacing = 16
        documentStack.translatesAutoresizingMaskIntoConstraints = false
        documentStack.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 12)

        populateFeatures(into: documentStack)

        scrollView.documentView = documentStack

        rootStack.addArrangedSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -48),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            documentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -16)
        ])

        // 4. Footer Tip
        let tipLabel = NSTextField(wrappingLabelWithString: "💡 Tip: You can reopen this guide anytime from the Animal Buddy menu bar icon.")
        tipLabel.font = .systemFont(ofSize: 11, weight: .regular)
        tipLabel.textColor = .tertiaryLabelColor
        tipLabel.alignment = .center
        rootStack.addArrangedSubview(tipLabel)

        // 5. Action Button
        primaryButton.title = presentation.isFirstLaunch ? "Get Started" : "Continue"
        primaryButton.bezelStyle = .rounded
        primaryButton.controlSize = .large
        primaryButton.keyEquivalent = "\r"
        primaryButton.target = self
        primaryButton.action = #selector(primaryButtonClicked)
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            primaryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            primaryButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        rootStack.addArrangedSubview(primaryButton)
    }

    private func populateFeatures(into container: NSStackView) {
        switch presentation {
        case .firstLaunch(let features):
            for feature in features {
                container.addArrangedSubview(makeFeatureRow(feature: feature))
            }

        case .whatsNew(_, let releases):
            for release in releases {
                if releases.count > 1 {
                    let sectionHeader = NSTextField(labelWithString: "Version \(release.version) — \(release.releaseTitle)")
                    sectionHeader.font = .systemFont(ofSize: 12, weight: .semibold)
                    sectionHeader.textColor = .systemBlue
                    container.addArrangedSubview(sectionHeader)
                }

                for feature in release.features {
                    container.addArrangedSubview(makeFeatureRow(feature: feature))
                }
            }
        }
    }

    private func makeFeatureRow(feature: FeatureItem) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false

        // Icon badge
        let iconBadge = NSImageView()
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBadge.widthAnchor.constraint(equalToConstant: 28),
            iconBadge.heightAnchor.constraint(equalToConstant: 28)
        ])
        iconBadge.imageScaling = .scaleProportionallyUpOrDown

        if let symbol = NSImage(systemSymbolName: feature.iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            iconBadge.image = symbol.withSymbolConfiguration(config)
            iconBadge.contentTintColor = .controlAccentColor
        } else {
            let fallback = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)
            iconBadge.image = fallback
            iconBadge.contentTintColor = .controlAccentColor
        }
        row.addArrangedSubview(iconBadge)

        // Texts
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let titleField = NSTextField(labelWithString: feature.title)
        titleField.font = .systemFont(ofSize: 13, weight: .bold)
        titleField.textColor = .labelColor
        textStack.addArrangedSubview(titleField)

        let descField = NSTextField(wrappingLabelWithString: feature.description)
        descField.font = .systemFont(ofSize: 12, weight: .regular)
        descField.textColor = .secondaryLabelColor
        textStack.addArrangedSubview(descField)

        row.addArrangedSubview(textStack)
        return row
    }

    private var hasDismissed = false
    private func notifyDismissOnce() {
        guard !hasDismissed else { return }
        hasDismissed = true
        onDismiss?()
    }

    @objc private func primaryButtonClicked() {
        notifyDismissOnce()
        close()
    }

    func windowWillClose(_ notification: Notification) {
        notifyDismissOnce()
    }
}

extension WelcomePresentationKind {
    var isFirstLaunch: Bool {
        if case .firstLaunch = self { return true }
        return false
    }

    var headerTitle: String {
        switch self {
        case .firstLaunch:
            return "Welcome to Animal Buddy"
        case .whatsNew(let version, _):
            return "What's New in Animal Buddy \(version)"
        }
    }

    var headerSubtitle: String {
        switch self {
        case .firstLaunch:
            return "Your cheerful macOS desktop companion for drag-and-drop actions."
        case .whatsNew:
            return "Discover the new features and improvements in this update."
        }
    }
}
