import AppKit

@MainActor final class MacroSettingsWindowController: NSWindowController {
    var onSave: ((UserMacro, UserMacro) -> Void)?
    private var leftBuilder: MacroBuilderView
    private var rightBuilder: MacroBuilderView
    private let leftName = NSTextField()
    private let rightName = NSTextField()

    init(settings: AppSettings) {
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 700, height: 620), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Blush Macro Workshop"
        window.isReleasedWhenClosed = false
        leftBuilder = MacroBuilderView(steps: settings.leftBlushMacro.effectiveSteps)
        rightBuilder = MacroBuilderView(steps: settings.rightBlushMacro.effectiveSteps)
        super.init(window: window)
        leftName.stringValue = settings.leftBlushMacro.name
        rightName.stringValue = settings.rightBlushMacro.name
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let heading = NSTextField(labelWithString: "Give each blush a tiny superpower")
        heading.font = .systemFont(ofSize: 21, weight: .bold)
        let note = NSTextField(wrappingLabelWithString: "Build a little Scratch-like sequence of blocks. Add an action, fill in its value, and the buddy will run the blocks from top to bottom.")
        note.textColor = .secondaryLabelColor; note.maximumNumberOfLines = 3
        let leftCard = makeCard(title: "Left blush", nameField: leftName, builder: leftBuilder)
        let rightCard = makeCard(title: "Right blush", nameField: rightName, builder: rightBuilder)
        let cards = NSStackView(views: [leftCard, rightCard]); cards.orientation = .horizontal; cards.spacing = 18; cards.distribution = .fillEqually
        let help = NSTextField(wrappingLabelWithString: "Apple Shortcuts: add a “Run Apple Shortcut” block and enter the exact Shortcut name. Shell commands are run only because you explicitly configure them here.")
        help.textColor = .secondaryLabelColor; help.maximumNumberOfLines = 3
        let save = NSButton(title: "Save Macros", target: self, action: #selector(savePressed)); save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let buttons = NSStackView(views: [NSView(), cancel, save]); buttons.orientation = .horizontal; buttons.spacing = 10
        let stack = NSStackView(views: [heading, note, cards, help, buttons]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18; stack.edgeInsets = NSEdgeInsets(top: 32, left: 36, bottom: 32, right: 36)
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor), cards.widthAnchor.constraint(equalTo: stack.widthAnchor), cards.heightAnchor.constraint(equalToConstant: 360), help.widthAnchor.constraint(equalTo: stack.widthAnchor)])
    }

    private func makeCard(title: String, nameField: NSTextField, builder: MacroBuilderView) -> NSView {
        let label = NSTextField(labelWithString: title); label.font = .systemFont(ofSize: 15, weight: .semibold)
        nameField.placeholderString = "Macro name"
        nameField.translatesAutoresizingMaskIntoConstraints = false
        let nameLabel = NSTextField(labelWithString: "Name")
        let stack = NSStackView(views: [label, nameLabel, nameField, builder]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8; stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.wantsLayer = true; stack.layer?.cornerRadius = 12; stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        nameField.widthAnchor.constraint(equalToConstant: 270).isActive = true
        return stack
    }

    @objc private func savePressed() {
        onSave?(UserMacro(name: leftName.stringValue, steps: leftBuilder.steps), UserMacro(name: rightName.stringValue, steps: rightBuilder.steps)); close()
    }
    @objc private func cancelPressed() { close() }
}

@MainActor final class MacroBuilderView: NSView {
    private(set) var steps: [MacroStep] = []
    private let rows = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No blocks yet — add one below")

    init(steps: [MacroStep]) {
        self.steps = steps; super.init(frame: .zero)
        rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 8; emptyLabel.textColor = .tertiaryLabelColor
        let add = NSButton(title: "+ Add block", target: self, action: #selector(addStep))
        let stack = NSStackView(views: [rows, emptyLabel, add]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor), stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor), widthAnchor.constraint(equalToConstant: 300)])
        rebuildRows()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func addStep() { steps.append(MacroStep(kind: .shell)); rebuildRows() }
    private func rebuildRows() {
        rows.arrangedSubviews.forEach { rows.removeArrangedSubview($0); $0.removeFromSuperview() }; emptyLabel.isHidden = !steps.isEmpty
        for index in steps.indices { rows.addArrangedSubview(MacroStepRow(step: steps[index], index: index) { [weak self] index, step in self?.steps[index] = step; self?.rebuildRows() } onRemove: { [weak self] index in self?.steps.remove(at: index); self?.rebuildRows() }) }
    }
}

@MainActor final class MacroStepRow: NSView {
    private let kind = NSPopUpButton(); private let value = NSTextField(); private let stepIndex: Int
    private let onChange: (Int, MacroStep) -> Void; private let onRemove: (Int) -> Void
    init(step: MacroStep, index: Int, onChange: @escaping (Int, MacroStep) -> Void, onRemove: @escaping (Int) -> Void) {
        self.stepIndex = index; self.onChange = onChange; self.onRemove = onRemove; super.init(frame: .zero)
        for option in MacroStepKind.allCases { kind.addItem(withTitle: option.displayName) }; kind.selectItem(withTitle: step.kind.displayName); value.stringValue = step.value; value.placeholderString = step.kind.placeholder
        kind.target = self; kind.action = #selector(kindChanged); value.target = self; value.action = #selector(valueChanged)
        let remove = NSButton(title: "−", target: self, action: #selector(removePressed)); remove.bezelStyle = .texturedRounded; remove.toolTip = "Remove block"
        let stack = NSStackView(views: [kind, value, remove]); stack.orientation = .horizontal; stack.spacing = 6; stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor), stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor), kind.widthAnchor.constraint(equalToConstant: 150), value.widthAnchor.constraint(equalToConstant: 145)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func kindChanged() { value.placeholderString = selectedKind.placeholder; onChange(stepIndex, MacroStep(kind: selectedKind, value: value.stringValue)) }
    @objc private func valueChanged() { onChange(stepIndex, MacroStep(kind: selectedKind, value: value.stringValue)) }
    @objc private func removePressed() { onRemove(stepIndex) }
    private var selectedKind: MacroStepKind { MacroStepKind.allCases[kind.indexOfSelectedItem] }
}
