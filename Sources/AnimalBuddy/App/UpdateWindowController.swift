import AppKit

@MainActor final class UpdateWindowController: NSWindowController, NSWindowDelegate {
    var onSkipVersion: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let release: GitHubRelease
    private let currentVersion: String

    init(release: GitHubRelease, currentVersion: String) {
        self.release = release
        self.currentVersion = currentVersion

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Software Update"
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
        rootStack.spacing = 16
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // 1. Icon & Header
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64)
        ])

        if let iconURL = Bundle.main.url(forResource: "AnimalBuddyIcon", withExtension: "png"),
           let iconImg = NSImage(contentsOf: iconURL) {
            iconView.image = iconImg
        } else if let symbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .medium)
            iconView.image = symbol.withSymbolConfiguration(config)
            iconView.contentTintColor = .systemBlue
        }
        rootStack.addArrangedSubview(iconView)

        let titleLabel = NSTextField(labelWithString: "A new version of Animal Buddy is available!")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.alignment = .center
        rootStack.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Animal Buddy \(release.tagName) is now available to download (you have \(currentVersion)). Would you like to update now?")
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        rootStack.addArrangedSubview(subtitleLabel)

        // 2. Release Notes Box
        let notesScrollView = NSScrollView()
        notesScrollView.hasVerticalScroller = true
        notesScrollView.drawsBackground = true
        notesScrollView.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6)
        notesScrollView.wantsLayer = true
        notesScrollView.layer?.cornerRadius = 8
        notesScrollView.layer?.borderWidth = 1
        notesScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        notesScrollView.translatesAutoresizingMaskIntoConstraints = false

        let notesTextView = NSTextView()
        notesTextView.isEditable = false
        notesTextView.isSelectable = true
        notesTextView.drawsBackground = false
        notesTextView.font = .systemFont(ofSize: 12)
        notesTextView.textColor = .labelColor
        notesTextView.textContainerInset = NSSize(width: 12, height: 12)
        notesTextView.string = formattedReleaseNotes(from: release.body)
        notesScrollView.documentView = notesTextView

        rootStack.addArrangedSubview(notesScrollView)
        NSLayoutConstraint.activate([
            notesScrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            notesScrollView.heightAnchor.constraint(equalToConstant: 160)
        ])

        // 3. Actions Row
        let actionsRow = NSStackView()
        actionsRow.orientation = .horizontal
        actionsRow.alignment = .centerY
        actionsRow.spacing = 10
        actionsRow.distribution = .fill

        let skipBtn = NSButton(title: "Skip This Version", target: self, action: #selector(skipVersionPressed))
        skipBtn.bezelStyle = .rounded
        skipBtn.font = .systemFont(ofSize: 12)

        let laterBtn = NSButton(title: "Remind Me Later", target: self, action: #selector(laterPressed))
        laterBtn.bezelStyle = .rounded
        laterBtn.font = .systemFont(ofSize: 12)

        let downloadBtn = NSButton(title: "Download Update", target: self, action: #selector(downloadPressed))
        downloadBtn.bezelStyle = .rounded
        downloadBtn.keyEquivalent = "\r"
        downloadBtn.font = .systemFont(ofSize: 13, weight: .semibold)
        downloadBtn.bezelColor = .systemBlue

        actionsRow.addArrangedSubview(skipBtn)
        actionsRow.addArrangedSubview(NSView()) // flexible spacer
        actionsRow.addArrangedSubview(laterBtn)
        actionsRow.addArrangedSubview(downloadBtn)

        rootStack.addArrangedSubview(actionsRow)
        NSLayoutConstraint.activate([
            actionsRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])
    }

    private func formattedReleaseNotes(from body: String?) -> String {
        guard let body = body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No release notes provided for this update."
        }
        // Clean markdown heading markers for readable plain text display
        return body
            .replacingOccurrences(of: "### ", with: "• ")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    @objc private func downloadPressed() {
        if let url = release.primaryDownloadURL {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: release.htmlURL) {
            NSWorkspace.shared.open(fallback)
        }
        window?.close()
        onDismiss?()
    }

    @objc private func skipVersionPressed() {
        onSkipVersion?(release.tagName)
        window?.close()
        onDismiss?()
    }

    @objc private func laterPressed() {
        window?.close()
        onDismiss?()
    }

    func windowWillClose(_ notification: Notification) {
        onDismiss?()
    }
}
