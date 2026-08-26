import AppKit

@MainActor final class MacroSettingsWindowController: NSWindowController {
    var onSave: ((UserMacro, UserMacro, [DragMacroBinding]) -> Void)?
    private var leftBuilder: MacroBuilderView
    private var rightBuilder: MacroBuilderView
    private let dragEditor: DragMacroEditorView
    private let leftName = NSTextField()
    private let rightName = NSTextField()

    init(settings: AppSettings) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 750),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Macros Workshop"
        window.minSize = NSSize(width: 680, height: 500)
        window.isReleasedWhenClosed = false
        leftBuilder = MacroBuilderView(steps: settings.leftBlushMacro.effectiveSteps)
        rightBuilder = MacroBuilderView(steps: settings.rightBlushMacro.effectiveSteps)
        dragEditor = DragMacroEditorView(bindings: settings.dragMacros)
        super.init(window: window)
        leftName.stringValue = settings.leftBlushMacro.name
        rightName.stringValue = settings.rightBlushMacro.name
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        
        let scrollView = NSScrollView(frame: content.bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        
        let heading = NSTextField(labelWithString: "Give Animal Buddy tiny superpowers")
        heading.font = .systemFont(ofSize: 20, weight: .bold)
        let note = NSTextField(wrappingLabelWithString: "Build a little Scratch-like sequence of blocks. Add an action, fill in its value, and the buddy will run the blocks from top to bottom.")
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 3
        
        let leftCard = makeCard(title: "Left blush", slot: .left, nameField: leftName, builder: leftBuilder)
        let rightCard = makeCard(title: "Right blush", slot: .right, nameField: rightName, builder: rightBuilder)
        let cards = NSStackView(views: [leftCard, rightCard])
        cards.orientation = .horizontal
        cards.spacing = 16
        cards.distribution = .fillEqually
        
        let dragCard = makeDragCard()
        
        let mainStack = NSStackView(views: [heading, note, cards, dragCard])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 18
        mainStack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(mainStack)
        
        let save = NSButton(title: "Save Macros", target: self, action: #selector(savePressed))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let bottomBar = NSStackView(views: [NSView(), cancel, save])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 10
        bottomBar.edgeInsets = NSEdgeInsets(top: 12, left: 28, bottom: 16, right: 28)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        content.addSubview(scrollView)
        content.addSubview(bottomBar)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            
            bottomBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 54),
            
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            
            mainStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            
            cards.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            dragCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56)
        ])
    }

    private func makeCard(title: String, slot: BlushSlot, nameField: NSTextField, builder: MacroBuilderView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        
        let presetPicker = NSPopUpButton()
        presetPicker.addItem(withTitle: "💡 Suggestions…")
        let presets = slot == .left ? MacroPresets.leftBlush : MacroPresets.rightBlush
        presets.forEach { presetPicker.addItem(withTitle: $0.title) }
        presetPicker.target = self
        presetPicker.action = slot == .left ? #selector(leftPresetChanged(_:)) : #selector(rightPresetChanged(_:))
        
        let header = NSStackView(views: [label, NSView(), presetPicker])
        header.orientation = .horizontal
        header.alignment = .centerY
        
        nameField.placeholderString = "Macro name"
        let nameLabel = NSTextField(labelWithString: "Name")
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [header, nameLabel, nameField, builder])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        header.translatesAutoresizingMaskIntoConstraints = false
        nameField.translatesAutoresizingMaskIntoConstraints = false
        builder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            builder.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    @objc private func leftPresetChanged(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem > 0 else { return }
        let preset = MacroPresets.leftBlush[sender.indexOfSelectedItem - 1]
        leftName.stringValue = preset.macro.name
        leftBuilder.loadSteps(preset.macro.effectiveSteps)
        sender.selectItem(at: 0)
    }

    @objc private func rightPresetChanged(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem > 0 else { return }
        let preset = MacroPresets.rightBlush[sender.indexOfSelectedItem - 1]
        rightName.stringValue = preset.macro.name
        rightBuilder.loadSteps(preset.macro.effectiveSteps)
        sender.selectItem(at: 0)
    }

    private func makeDragCard() -> NSView {
        let title = NSTextField(labelWithString: "Dragging macros")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        let note = NSTextField(wrappingLabelWithString: "Choose what happens when a particular kind of item is dropped on Animal Buddy. A configured dragging macro runs before the default action binding. Use {{path}}, {{paths}}, {{text}}, or {{category}} in values when needed.")
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 2
        let stack = NSStackView(views: [title, note, dragEditor])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        dragEditor.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dragEditor.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    @objc private func savePressed() {
        onSave?(UserMacro(name: leftName.stringValue, steps: leftBuilder.steps), UserMacro(name: rightName.stringValue, steps: rightBuilder.steps), dragEditor.bindings)
        close()
    }
    @objc private func cancelPressed() { close() }
}

@MainActor final class MacroBuilderView: NSView {
    private(set) var steps: [MacroStep] = []
    private let rows = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No blocks yet — add one below")

    init(steps: [MacroStep]) {
        self.steps = steps
        super.init(frame: .zero)
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 10
        emptyLabel.textColor = .tertiaryLabelColor
        let add = NSButton(title: "+ Add block", target: self, action: #selector(addStep))
        let stack = NSStackView(views: [rows, emptyLabel, add])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            rows.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        rebuildRows()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func addStep() { steps.append(MacroStep(kind: .shell)); rebuildRows() }
    func loadSteps(_ newSteps: [MacroStep]) {
        self.steps = newSteps
        rebuildRows()
    }
    private func rebuildRows() {
        rows.arrangedSubviews.forEach { rows.removeArrangedSubview($0); $0.removeFromSuperview() }
        emptyLabel.isHidden = !steps.isEmpty
        for index in steps.indices {
            rows.addArrangedSubview(
                MacroStepRow(
                    step: steps[index],
                    index: index,
                    onChange: { [weak self] index, step in
                        self?.steps[index] = step
                        self?.rebuildRows()
                    },
                    onRemove: { [weak self] index in
                        self?.steps.remove(at: index)
                        self?.rebuildRows()
                    }
                )
            )
        }
    }
}

@MainActor final class DragMacroEditorView: NSView {
    private static let categories: [InputCategory] = [.image, .directory, .application, .file, .url, .text, .mixed, .unknown]
    private var macros: [InputCategory: UserMacro]
    private let categoryPicker = NSPopUpButton()
    private let presetPicker = NSPopUpButton()
    private let categorySummary = NSTextField(labelWithString: "")
    private let nameField = NSTextField()
    private let builderHost = NSView()
    private var builder: MacroBuilderView?
    private var selectedCategory: InputCategory = .image

    init(bindings: [DragMacroBinding]) {
        macros = Dictionary(uniqueKeysWithValues: bindings.map { ($0.category, $0.macro) })
        super.init(frame: .zero)
        Self.categories.forEach { categoryPicker.addItem(withTitle: Self.displayName(for: $0)) }
        categoryPicker.target = self
        categoryPicker.action = #selector(categoryChanged)
        nameField.placeholderString = "Macro name (optional)"
        
        let triggerLabel = NSTextField(labelWithString: "When I drop:")
        triggerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        categorySummary.font = .systemFont(ofSize: 12, weight: .medium)
        categorySummary.textColor = .secondaryLabelColor
        
        presetPicker.target = self
        presetPicker.action = #selector(presetChanged)
        
        let pickerRow = NSStackView(views: [triggerLabel, categoryPicker, categorySummary, NSView(), presetPicker])
        pickerRow.orientation = .horizontal
        pickerRow.alignment = .centerY
        pickerRow.spacing = 10
        
        let nameLabel = NSTextField(labelWithString: "Macro name")
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .secondaryLabelColor
        
        let stack = NSStackView(views: [pickerRow, nameLabel, nameField, builderHost])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        pickerRow.translatesAutoresizingMaskIntoConstraints = false
        nameField.translatesAutoresizingMaskIntoConstraints = false
        builderHost.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            pickerRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            categoryPicker.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            builderHost.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        loadSelectedMacro()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var bindings: [DragMacroBinding] {
        saveSelectedMacro()
        return Self.categories.compactMap { category in
            guard let macro = macros[category], macro.isConfigured else { return nil }
            return DragMacroBinding(category: category, macro: macro)
        }
    }

    @objc private func categoryChanged() {
        saveSelectedMacro()
        let newIndex = min(max(categoryPicker.indexOfSelectedItem, 0), Self.categories.count - 1)
        selectedCategory = Self.categories[newIndex]
        loadSelectedMacro()
    }

    private func updatePresetsMenu() {
        presetPicker.removeAllItems()
        presetPicker.addItem(withTitle: "💡 Suggestions…")
        let categoryPresets = MacroPresets.presets(for: selectedCategory)
        categoryPresets.forEach { presetPicker.addItem(withTitle: $0.title) }
    }

    @objc private func presetChanged() {
        guard presetPicker.indexOfSelectedItem > 0 else { return }
        let categoryPresets = MacroPresets.presets(for: selectedCategory)
        let presetIndex = presetPicker.indexOfSelectedItem - 1
        guard categoryPresets.indices.contains(presetIndex) else { return }
        let preset = categoryPresets[presetIndex]
        nameField.stringValue = preset.macro.name
        builder?.loadSteps(preset.macro.effectiveSteps)
        presetPicker.selectItem(at: 0)
    }

    private func loadSelectedMacro() {
        if let idx = Self.categories.firstIndex(of: selectedCategory) {
            categoryPicker.selectItem(at: idx)
        }
        let macro = macros[selectedCategory] ?? UserMacro()
        categorySummary.stringValue = "Editing: \(Self.displayName(for: selectedCategory))"
        nameField.stringValue = macro.name
        updatePresetsMenu()
        builder?.removeFromSuperview()
        let newBuilder = MacroBuilderView(steps: macro.effectiveSteps)
        newBuilder.translatesAutoresizingMaskIntoConstraints = false
        builderHost.addSubview(newBuilder)
        NSLayoutConstraint.activate([
            newBuilder.leadingAnchor.constraint(equalTo: builderHost.leadingAnchor),
            newBuilder.trailingAnchor.constraint(equalTo: builderHost.trailingAnchor),
            newBuilder.topAnchor.constraint(equalTo: builderHost.topAnchor),
            newBuilder.bottomAnchor.constraint(equalTo: builderHost.bottomAnchor)
        ])
        builder = newBuilder
    }

    private func saveSelectedMacro() {
        guard let builder else { return }
        macros[selectedCategory] = UserMacro(name: nameField.stringValue, steps: builder.steps)
    }

    private static func displayName(for category: InputCategory) -> String {
        switch category {
        case .image: "Images"
        case .directory: "Folders"
        case .application: "Applications"
        case .file: "Files"
        case .url: "URLs"
        case .text: "Text"
        case .mixed: "Mixed items"
        case .unknown: "Unknown items"
        }
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
