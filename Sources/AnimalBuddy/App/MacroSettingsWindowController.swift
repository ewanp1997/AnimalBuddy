import AppKit

@MainActor final class MacroSettingsWindowController: NSWindowController {
    var onSave: ((UserMacro, UserMacro) -> Void)?
    private let leftName = NSTextField()
    private let leftCommand = NSTextField()
    private let rightName = NSTextField()
    private let rightCommand = NSTextField()

    init(settings: AppSettings) {
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 270), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Blush Macros"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        leftName.stringValue = settings.leftBlushMacro.name
        leftCommand.stringValue = settings.leftBlushMacro.command
        rightName.stringValue = settings.rightBlushMacro.name
        rightCommand.stringValue = settings.rightBlushMacro.command
        leftName.placeholderString = "e.g. Open Work Folder"
        rightName.placeholderString = "e.g. Start Focus Timer"
        leftCommand.placeholderString = "e.g. open ~/Documents/Work"
        rightCommand.placeholderString = "e.g. open -a 'Calendar'"
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let heading = NSTextField(labelWithString: "Give each blush a tiny superpower")
        heading.font = .systemFont(ofSize: 16, weight: .semibold)
        let note = NSTextField(wrappingLabelWithString: "Click a configured blush to run its command. Commands are only run after you explicitly add them here.")
        note.textColor = .secondaryLabelColor
        let leftLabel = NSTextField(labelWithString: "Left blush")
        let rightLabel = NSTextField(labelWithString: "Right blush")
        let nameLabel = NSTextField(labelWithString: "Name")
        let rightNameLabel = NSTextField(labelWithString: "Name")
        let commandLabel = NSTextField(labelWithString: "Command")
        let rightCommandLabel = NSTextField(labelWithString: "Command")
        let save = NSButton(title: "Save", target: self, action: #selector(savePressed))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))

        let stack = NSStackView(views: [heading, note, leftLabel, nameLabel, leftName, commandLabel, leftCommand, rightLabel, rightNameLabel, rightName, rightCommandLabel, rightCommand])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 7
        for field in [leftName, leftCommand, rightName, rightCommand] { field.translatesAutoresizingMaskIntoConstraints = false; field.widthAnchor.constraint(equalToConstant: 390).isActive = true }
        let buttons = NSStackView(views: [NSView(), cancel, save]); buttons.orientation = .horizontal; buttons.spacing = 8
        let outer = NSStackView(views: [stack, buttons]); outer.orientation = .vertical; outer.spacing = 12; outer.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        outer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(outer)
        NSLayoutConstraint.activate([outer.leadingAnchor.constraint(equalTo: content.leadingAnchor), outer.trailingAnchor.constraint(equalTo: content.trailingAnchor), outer.topAnchor.constraint(equalTo: content.topAnchor), outer.bottomAnchor.constraint(equalTo: content.bottomAnchor)])
    }

    @objc private func savePressed() {
        onSave?(UserMacro(name: leftName.stringValue, command: leftCommand.stringValue), UserMacro(name: rightName.stringValue, command: rightCommand.stringValue))
        close()
    }

    @objc private func cancelPressed() { close() }
}
