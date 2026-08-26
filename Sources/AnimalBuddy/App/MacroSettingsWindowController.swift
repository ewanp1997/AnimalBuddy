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
        let save = NSButton(title: "Save Macros", target: self, action: #selector(savePressed)); save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let buttons = NSStackView(views: [NSView(), cancel, save]); buttons.orientation = .horizontal; buttons.spacing = 10
        let stack = NSStackView(views: [heading, note, cards, buttons]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18; stack.edgeInsets = NSEdgeInsets(top: 32, left: 36, bottom: 32, right: 36)
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor), cards.widthAnchor.constraint(equalTo: stack.widthAnchor), cards.heightAnchor.constraint(equalToConstant: 360)])
    }

    private func makeCard(title: String, nameField: NSTextField, builder: MacroBuilderView) -> NSView {
        let label = NSTextField(labelWithString: title); label.font = .systemFont(ofSize: 15, weight: .semibold)
        nameField.placeholderString = "Macro name"
        nameField.translatesAutoresizingMaskIntoConstraints = false
        let nameLabel = NSTextField(labelWithString: "Name")
        let stack = NSStackView(views: [label, nameLabel, nameField, builder]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12; stack.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        stack.wantsLayer = true; stack.layer?.cornerRadius = 12; stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        nameField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -44).isActive = true
        builder.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -44).isActive = true
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
        rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 10; emptyLabel.textColor = .tertiaryLabelColor
        let add = NSButton(title: "+ Add block", target: self, action: #selector(addStep))
        let stack = NSStackView(views: [rows, emptyLabel, add]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor), stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor), rows.widthAnchor.constraint(equalTo: stack.widthAnchor)])
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
    private let kind = NSPopUpButton(); private let value = NSTextField(); private let choicePicker = NSPopUpButton(); private let stepIndex: Int
    private let onChange: (Int, MacroStep) -> Void; private let onRemove: (Int) -> Void
    init(step: MacroStep, index: Int, onChange: @escaping (Int, MacroStep) -> Void, onRemove: @escaping (Int) -> Void) {
        self.stepIndex = index; self.onChange = onChange; self.onRemove = onRemove; super.init(frame: .zero)
        for option in MacroStepKind.allCases { kind.addItem(withTitle: option.displayName) }; kind.selectItem(withTitle: step.kind.displayName); value.stringValue = step.value; value.placeholderString = step.kind.placeholder
        kind.target = self; kind.action = #selector(kindChanged); value.target = self; value.action = #selector(valueChanged); choicePicker.target = self; choicePicker.action = #selector(choiceChanged)
        let remove = NSButton(title: "−", target: self, action: #selector(removePressed)); remove.bezelStyle = .texturedRounded; remove.toolTip = "Remove block"
        let stack = NSStackView(views: [kind, value, choicePicker, remove]); stack.orientation = .horizontal; stack.spacing = 8; stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)
        value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        choicePicker.isHidden = true
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor), stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor), kind.widthAnchor.constraint(equalToConstant: 140), choicePicker.widthAnchor.constraint(equalToConstant: 190), remove.widthAnchor.constraint(equalToConstant: 28)])
        configureSelection(for: step.kind, currentValue: step.value, notify: false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func kindChanged() { configureSelection(for: selectedKind, currentValue: "", notify: true) }
    @objc private func valueChanged() { onChange(stepIndex, MacroStep(kind: selectedKind, value: value.stringValue)) }
    @objc private func choiceChanged() { onChange(stepIndex, MacroStep(kind: selectedKind, value: selectedChoiceValue)) }
    @objc private func removePressed() { onRemove(stepIndex) }
    private var selectedKind: MacroStepKind { MacroStepKind.allCases[kind.indexOfSelectedItem] }

    private var selectedChoiceValue: String {
        if selectedKind == .runBlushMacro { return choicePicker.indexOfSelectedItem == 1 ? BlushSlot.left.rawValue : BlushSlot.right.rawValue }
        let selectedTitle = choicePicker.titleOfSelectedItem ?? ""
        return selectedTitle == "No Shortcuts Found" || selectedTitle == "No Applications Found" ? "" : selectedTitle
    }

    private func configureSelection(for selected: MacroStepKind, currentValue: String, notify: Bool) {
        value.placeholderString = selected.placeholder
        let usesPicker = selected == .openApplication || selected == .runShortcut || selected == .runBlushMacro
        value.isHidden = usesPicker; choicePicker.isHidden = !usesPicker
        if selected == .openApplication {
            loadApplications(selecting: currentValue)
        } else if selected == .runBlushMacro {
            choicePicker.removeAllItems(); choicePicker.addItem(withTitle: "Right blush"); choicePicker.addItem(withTitle: "Left blush")
            choicePicker.selectItem(at: currentValue == BlushSlot.left.rawValue ? 1 : 0)
        } else if selected == .runShortcut {
            loadShortcuts(selecting: currentValue)
        }
        if notify { onChange(stepIndex, MacroStep(kind: selected, value: usesPicker ? selectedChoiceValue : value.stringValue)) }
    }

    private func loadApplications(selecting currentValue: String) {
        let applicationDirectories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        let names = Set(applicationDirectories.flatMap { directory in
            (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?
                .filter { $0.pathExtension.caseInsensitiveCompare("app") == .orderedSame }
                .map { $0.deletingPathExtension().lastPathComponent } ?? []
        }).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        choicePicker.removeAllItems()
        if names.isEmpty {
            choicePicker.addItem(withTitle: "No Applications Found")
        } else {
            names.forEach { choicePicker.addItem(withTitle: $0) }
            if !currentValue.isEmpty {
                if choicePicker.itemTitles.contains(currentValue) {
                    choicePicker.selectItem(withTitle: currentValue)
                } else {
                    choicePicker.insertItem(withTitle: currentValue, at: 0)
                    choicePicker.selectItem(at: 0)
                }
            }
        }
    }

    private func loadShortcuts(selecting currentValue: String) {
        choicePicker.removeAllItems(); choicePicker.addItem(withTitle: "Loading Shortcuts…")
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts"); process.arguments = ["list"]
        let output = Pipe(); process.standardOutput = output
        do {
            try process.run(); process.waitUntilExit()
            let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let names = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            choicePicker.removeAllItems()
            if names.isEmpty { choicePicker.addItem(withTitle: "No Shortcuts Found") }
            else { names.forEach { choicePicker.addItem(withTitle: $0) }; if choicePicker.itemTitles.contains(currentValue) { choicePicker.selectItem(withTitle: currentValue) } }
        } catch {
            choicePicker.removeAllItems(); choicePicker.addItem(withTitle: "No Shortcuts Found")
        }
    }
}
