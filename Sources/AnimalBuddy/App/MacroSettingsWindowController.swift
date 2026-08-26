import AppKit
import UniformTypeIdentifiers

@MainActor final class MacroSettingsWindowController: NSWindowController {
    var onSave: ((UserMacro, UserMacro, [DragMacroBinding], AnimalKind, PetThemePreset, PetThemePalette) -> Void)?
    var onThemeChanged: ((AnimalKind, PetThemePreset, PetThemePalette) -> Void)?

    private var leftBuilder: MacroBuilderView
    private var rightBuilder: MacroBuilderView
    private let dragEditor: DragMacroEditorView
    private let leftName = NSTextField()
    private let rightName = NSTextField()

    private var selectedAnimal: AnimalKind
    private var selectedTheme: PetThemePreset
    private var customPalette: PetThemePalette

    private let animalSegment = NSSegmentedControl(labels: AnimalKind.allCases.map { $0.displayName }, trackingMode: .selectOne, target: nil, action: nil)
    private let themeSegment = NSSegmentedControl(labels: ["Classic", "Dark", "Light", "Custom"], trackingMode: .selectOne, target: nil, action: nil)
    private let themeDescription = NSTextField(wrappingLabelWithString: "")

    private let bodyLabel = NSTextField(labelWithString: "Body & Feathers")
    private let bellyLabel = NSTextField(labelWithString: "Belly & Face")
    private let beakLabel = NSTextField(labelWithString: "Beak & Feet")
    private let blushLabel = NSTextField(labelWithString: "Blush Cheeks")
    private let eyeLabel = NSTextField(labelWithString: "Eye Glow")

    private let bodyColorWell = NSColorWell()
    private let bellyColorWell = NSColorWell()
    private let beakColorWell = NSColorWell()
    private let blushColorWell = NSColorWell()
    private let eyeHighlightColorWell = NSColorWell()
    private var previewPetView: PetView!

    private let tabSegment = NSSegmentedControl(labels: [
        "🎨 Plumage & Themes",
        "⚡️ Macros Workshop"
    ], trackingMode: .selectOne, target: nil, action: nil)
    private let tabContainer = NSView()
    private var appearanceView: NSView!
    private var macrosView: NSView!
    private let macroFileStatusLabel = NSTextField(labelWithString: "")

    private let triggerBannerTitle = NSTextField(labelWithString: "")
    private let triggerBannerSubtitle = NSTextField(wrappingLabelWithString: "")
    private let leftCardTitleLabel = NSTextField(labelWithString: "")
    private let leftCardSubtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let rightCardTitleLabel = NSTextField(labelWithString: "")
    private let rightCardSubtitleLabel = NSTextField(wrappingLabelWithString: "")

    init(settings: AppSettings, initialTab: Int = 0) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Animal Buddy Workshop"
        window.minSize = NSSize(width: 720, height: 560)
        window.isReleasedWhenClosed = false
        leftBuilder = MacroBuilderView(steps: settings.leftBlushMacro.effectiveSteps)
        rightBuilder = MacroBuilderView(steps: settings.rightBlushMacro.effectiveSteps)
        dragEditor = DragMacroEditorView(bindings: settings.dragMacros)
        selectedAnimal = settings.animalKind
        selectedTheme = settings.themePreset
        customPalette = settings.customPalette

        super.init(window: window)
        leftName.stringValue = settings.leftBlushMacro.name
        rightName.stringValue = settings.rightBlushMacro.name
        buildContent(initialTab: initialTab)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent(initialTab: Int) {
        guard let content = window?.contentView else { return }

        // Top Navigation Bar
        tabSegment.selectedSegment = initialTab
        tabSegment.target = self
        tabSegment.action = #selector(tabChanged)
        tabSegment.segmentStyle = .texturedRounded
        tabSegment.translatesAutoresizingMaskIntoConstraints = false

        let topBar = NSStackView(views: [tabSegment])
        topBar.orientation = .horizontal
        topBar.alignment = .centerY
        topBar.distribution = .gravityAreas
        topBar.edgeInsets = NSEdgeInsets(top: 14, left: 24, bottom: 8, right: 24)
        topBar.translatesAutoresizingMaskIntoConstraints = false

        tabContainer.translatesAutoresizingMaskIntoConstraints = false

        appearanceView = buildAppearanceTab()
        macrosView = buildMacrosTab()

        let save = NSButton(title: "Save Settings", target: self, action: #selector(savePressed))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let bottomBar = NSStackView(views: [NSView(), cancel, save])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 10
        bottomBar.edgeInsets = NSEdgeInsets(top: 10, left: 28, bottom: 16, right: 28)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(topBar)
        content.addSubview(tabContainer)
        content.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: content.topAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 46),

            tabContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tabContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 52)
        ])

        switchTab(to: initialTab)
        updateThemeSegmentLabels()
        updateColorLabels()
        updateColorWellsFromActivePalette()
        updateThemeDescription()
        updateMacroTabLabels()
    }

    @objc private func tabChanged() {
        switchTab(to: tabSegment.selectedSegment)
    }

    private func switchTab(to index: Int) {
        tabContainer.subviews.forEach { $0.removeFromSuperview() }
        let targetView = index == 0 ? appearanceView! : macrosView!
        targetView.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(targetView)
        NSLayoutConstraint.activate([
            targetView.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor),
            targetView.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor),
            targetView.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            targetView.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor)
        ])
    }

    // MARK: - Appearance Tab

    private func buildAppearanceTab() -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = doc

        let heading = NSTextField(labelWithString: "Animal Plumage & Appearance")
        heading.font = .systemFont(ofSize: 20, weight: .bold)
        let note = NSTextField(wrappingLabelWithString: "Choose your Animal Buddy, select signature themes, or personalize individual colors live!")
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 3

        let themeCard = makeThemeCard()
        let customCard = makePersonalCustomizationCard()
        let previewCard = makePreviewCard()

        let leftCol = NSStackView(views: [themeCard, customCard])
        leftCol.orientation = .vertical
        leftCol.spacing = 16
        leftCol.alignment = .leading

        let row = NSStackView(views: [leftCol, previewCard])
        row.orientation = .horizontal
        row.spacing = 20
        row.alignment = .top
        row.distribution = .fill

        let mainStack = NSStackView(views: [heading, note, row])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 28, bottom: 20, right: 28)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(mainStack)

        leftCol.translatesAutoresizingMaskIntoConstraints = false
        previewCard.translatesAutoresizingMaskIntoConstraints = false
        themeCard.translatesAutoresizingMaskIntoConstraints = false
        customCard.translatesAutoresizingMaskIntoConstraints = false
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),

            mainStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: doc.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),

            row.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            leftCol.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.62),
            themeCard.widthAnchor.constraint(equalTo: leftCol.widthAnchor),
            customCard.widthAnchor.constraint(equalTo: leftCol.widthAnchor),
            previewCard.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.35)
        ])

        return scrollView
    }

    private func makeThemeCard() -> NSView {
        let animalTitle = NSTextField(labelWithString: "Animal Choice")
        animalTitle.font = .systemFont(ofSize: 15, weight: .semibold)

        animalSegment.target = self
        animalSegment.action = #selector(animalSegmentChanged)
        animalSegment.segmentStyle = .texturedRounded
        animalSegment.selectedSegment = AnimalKind.allCases.firstIndex(of: selectedAnimal) ?? 0

        let themeTitle = NSTextField(labelWithString: "Theme Preset")
        themeTitle.font = .systemFont(ofSize: 15, weight: .semibold)

        themeSegment.target = self
        themeSegment.action = #selector(themeSegmentChanged)
        themeSegment.segmentStyle = .texturedRounded
        switch selectedTheme {
        case .classic: themeSegment.selectedSegment = 0
        case .dark: themeSegment.selectedSegment = 1
        case .light: themeSegment.selectedSegment = 2
        case .custom: themeSegment.selectedSegment = 3
        }

        themeDescription.font = .systemFont(ofSize: 12)
        themeDescription.textColor = .secondaryLabelColor
        themeDescription.maximumNumberOfLines = 3

        let stack = NSStackView(views: [animalTitle, animalSegment, themeTitle, themeSegment, themeDescription])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        animalSegment.translatesAutoresizingMaskIntoConstraints = false
        themeSegment.translatesAutoresizingMaskIntoConstraints = false
        themeDescription.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animalSegment.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            themeSegment.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            themeDescription.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    private let themeStatusLabel = NSTextField(wrappingLabelWithString: "")

    private func makePersonalCustomizationCard() -> NSView {
        let title = NSTextField(labelWithString: "Personal Customization")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let subtitle = NSTextField(wrappingLabelWithString: "Fine-tune individual colors, or import/export .json theme presets.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let bodyRow = makeColorRow(labelView: bodyLabel, well: bodyColorWell)
        let bellyRow = makeColorRow(labelView: bellyLabel, well: bellyColorWell)
        let beakRow = makeColorRow(labelView: beakLabel, well: beakColorWell)
        let blushRow = makeColorRow(labelView: blushLabel, well: blushColorWell)
        let eyeRow = makeColorRow(labelView: eyeLabel, well: eyeHighlightColorWell)

        let importBtn = NSButton(title: "📥 Import JSON…", target: self, action: #selector(importThemePressed))
        importBtn.bezelStyle = .accessoryBarAction
        let exportBtn = NSButton(title: "📤 Export JSON…", target: self, action: #selector(exportThemePressed))
        exportBtn.bezelStyle = .accessoryBarAction
        let resetBtn = NSButton(title: "Reset", target: self, action: #selector(resetColorsPressed))
        resetBtn.bezelStyle = .accessoryBarAction

        let btnRow = NSStackView(views: [importBtn, exportBtn, resetBtn])
        btnRow.orientation = .horizontal
        btnRow.spacing = 8

        themeStatusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        themeStatusLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, subtitle, bodyRow, bellyRow, beakRow, blushRow, eyeRow, btnRow, themeStatusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        bodyRow.translatesAutoresizingMaskIntoConstraints = false
        bellyRow.translatesAutoresizingMaskIntoConstraints = false
        beakRow.translatesAutoresizingMaskIntoConstraints = false
        blushRow.translatesAutoresizingMaskIntoConstraints = false
        eyeRow.translatesAutoresizingMaskIntoConstraints = false
        btnRow.translatesAutoresizingMaskIntoConstraints = false
        themeStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bodyRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            bellyRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            beakRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            blushRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            eyeRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            btnRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            themeStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    private func makeColorRow(labelView: NSTextField, well: NSColorWell) -> NSView {
        labelView.font = .systemFont(ofSize: 13, weight: .medium)

        well.target = self
        well.action = #selector(colorWellChanged(_:))
        well.translatesAutoresizingMaskIntoConstraints = false
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true
        well.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let row = NSStackView(views: [labelView, NSView(), well])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    private func makePreviewCard() -> NSView {
        let title = NSTextField(labelWithString: "Live Preview")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        previewPetView = PetView(frame: NSRect(x: 0, y: 0, width: 140, height: 140))
        previewPetView.translatesAutoresizingMaskIntoConstraints = false
        previewPetView.animalKind = selectedAnimal
        previewPetView.themePalette = currentPalette

        let flapBtn = NSButton(title: "Animate Movement", target: self, action: #selector(togglePreviewFlap))
        flapBtn.bezelStyle = .rounded
        let happyBtn = NSButton(title: "Celebrate 🎉", target: self, action: #selector(triggerPreviewCelebrate))
        happyBtn.bezelStyle = .rounded

        let actions = NSStackView(views: [flapBtn, happyBtn])
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.distribution = .fillEqually

        let stack = NSStackView(views: [title, previewPetView, actions])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        actions.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewPetView.widthAnchor.constraint(equalToConstant: 140),
            previewPetView.heightAnchor.constraint(equalToConstant: 140),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20)
        ])
        return stack
    }

    @objc private func togglePreviewFlap() {
        let isNowFlying = !previewPetView.isFlying
        previewPetView.setFlying(isNowFlying)
        if isNowFlying {
            previewPetView.updateFlightMovement(velocity: 0.8, deltaX: 10)
        }
    }

    @objc private func triggerPreviewCelebrate() {
        previewPetView.state = .success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.previewPetView.state = .idle
        }
    }

    @objc private func animalSegmentChanged() {
        let idx = animalSegment.selectedSegment
        guard idx >= 0 && idx < AnimalKind.allCases.count else { return }
        selectedAnimal = AnimalKind.allCases[idx]
        updateThemeSegmentLabels()
        updateColorLabels()
        updateColorWellsFromActivePalette()
        updateThemeDescription()
        updateMacroTabLabels()
        previewPetView.animalKind = selectedAnimal
        previewPetView.themePalette = currentPalette
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette)
    }

    @objc private func themeSegmentChanged() {
        switch themeSegment.selectedSegment {
        case 0:
            selectedTheme = .classic
        case 1:
            selectedTheme = .dark
        case 2:
            selectedTheme = .light
        case 3:
            selectedTheme = .custom
        default: break
        }
        updateColorWellsFromActivePalette()
        updateThemeDescription()
        previewPetView.animalKind = selectedAnimal
        previewPetView.themePalette = currentPalette
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette)
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        selectedTheme = .custom
        themeSegment.selectedSegment = 3
        customPalette = PetThemePalette(
            bodyColor: CodableColor(nsColor: bodyColorWell.color),
            bellyColor: CodableColor(nsColor: bellyColorWell.color),
            beakColor: CodableColor(nsColor: beakColorWell.color),
            blushColor: CodableColor(nsColor: blushColorWell.color),
            eyeHighlightColor: CodableColor(nsColor: eyeHighlightColorWell.color)
        )
        updateThemeDescription()
        previewPetView.themePalette = customPalette
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette)
    }

    @objc private func resetColorsPressed() {
        selectedTheme = .classic
        themeSegment.selectedSegment = 0
        customPalette = selectedAnimal.defaultPalette(for: .classic)
        updateColorWellsFromActivePalette()
        updateThemeDescription()
        previewPetView.animalKind = selectedAnimal
        previewPetView.themePalette = currentPalette
        themeStatusLabel.stringValue = "Restored classic colors for \(selectedAnimal.displayName)"
        themeStatusLabel.textColor = .secondaryLabelColor
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette)
    }

    @objc func exportThemePressed() {
        guard let window else { return }
        let savePanel = NSSavePanel()
        savePanel.title = "Export \(selectedAnimal.nameWithoutEmoji) Theme"
        savePanel.prompt = "Export"
        savePanel.allowedContentTypes = [UTType.json]
        let defaultFileName = "\(selectedAnimal.rawValue)-\(selectedTheme == .custom ? "custom" : selectedTheme.rawValue)-theme.json"
        savePanel.nameFieldStringValue = defaultFileName

        savePanel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = savePanel.url else { return }
            do {
                let themeName = self.selectedTheme == .custom ? "Custom \(self.selectedAnimal.nameWithoutEmoji) Theme" : self.selectedTheme.displayName(for: self.selectedAnimal)
                let doc = ThemeDocument(animal: self.selectedAnimal, name: themeName, version: 1, palette: self.currentPalette)
                let data = try doc.exportJSONData()
                try data.write(to: url)
                self.themeStatusLabel.stringValue = "✅ Theme exported to \(url.lastPathComponent)"
                self.themeStatusLabel.textColor = .systemGreen
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to export theme"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.beginSheetModal(for: window)
            }
        }
    }

    @objc func importThemePressed() {
        guard let window else { return }
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Animal Buddy Theme"
        openPanel.prompt = "Import"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = openPanel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let (animal, name, importedPalette) = try ThemeDocument.decode(from: data)
                self.selectedAnimal = animal
                self.animalSegment.selectedSegment = AnimalKind.allCases.firstIndex(of: animal) ?? 0
                self.customPalette = importedPalette
                self.selectedTheme = .custom
                self.themeSegment.selectedSegment = 3
                self.updateThemeSegmentLabels()
                self.updateColorLabels()
                self.updateColorWellsFromActivePalette()
                self.updateThemeDescription()
                self.updateMacroTabLabels()
                self.previewPetView.animalKind = animal
                self.previewPetView.themePalette = importedPalette
                self.onThemeChanged?(animal, .custom, importedPalette)
                self.themeStatusLabel.stringValue = "✅ Loaded \(animal.displayName) theme: \(name)"
                self.themeStatusLabel.textColor = .systemGreen
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could not import theme"
                alert.informativeText = "The file is not a valid Animal Buddy theme JSON: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.beginSheetModal(for: window)
            }
        }
    }

    private var currentPalette: PetThemePalette {
        selectedTheme == .custom ? customPalette : selectedAnimal.defaultPalette(for: selectedTheme)
    }

    private func updateThemeSegmentLabels() {
        let presets = selectedAnimal.themePresets
        for (i, p) in presets.enumerated() {
            if i < themeSegment.segmentCount {
                themeSegment.setLabel(p.displayName(for: selectedAnimal), forSegment: i)
            }
        }
    }

    private func updateColorLabels() {
        switch selectedAnimal {
        case .bird:
            bodyLabel.stringValue = "Body & Feathers"
            bellyLabel.stringValue = "Belly & Face"
            beakLabel.stringValue = "Beak & Feet"
            blushLabel.stringValue = "Blush Cheeks"
            eyeLabel.stringValue = "Eye Glow"
        case .dog:
            bodyLabel.stringValue = "Body & Fur"
            bellyLabel.stringValue = "Muzzle & Chest"
            beakLabel.stringValue = "Nose & Ears"
            blushLabel.stringValue = "Blush Cheeks"
            eyeLabel.stringValue = "Eye Iris"
        case .cat:
            bodyLabel.stringValue = "Body & Fur"
            bellyLabel.stringValue = "Muzzle & Chest"
            beakLabel.stringValue = "Nose & Inner Ears"
            blushLabel.stringValue = "Blush Cheeks"
            eyeLabel.stringValue = "Eye Iris"
        case .monkey:
            bodyLabel.stringValue = "Body & Fur"
            bellyLabel.stringValue = "Face Mask & Belly"
            beakLabel.stringValue = "Nose & Ears"
            blushLabel.stringValue = "Blush Cheeks"
            eyeLabel.stringValue = "Eye Iris"
        case .giraffe:
            bodyLabel.stringValue = "Body & Fur"
            bellyLabel.stringValue = "Muzzle & Belly"
            beakLabel.stringValue = "Spots & Horns"
            blushLabel.stringValue = "Blush Cheeks"
            eyeLabel.stringValue = "Eye Iris"
        }
    }

    private func updateColorWellsFromActivePalette() {
        let pal = currentPalette
        bodyColorWell.color = pal.bodyColor.nsColor
        bellyColorWell.color = pal.bellyColor.nsColor
        beakColorWell.color = pal.beakColor.nsColor
        blushColorWell.color = pal.blushColor.nsColor
        eyeHighlightColorWell.color = pal.eyeHighlightColor.nsColor
    }

    private func updateThemeDescription() {
        let themeName = selectedTheme.displayName(for: selectedAnimal)
        themeDescription.stringValue = "\(selectedAnimal.displayName) · \(themeName) theme active."
    }

    private func updateMacroTabLabels() {
        triggerBannerTitle.stringValue = "🎯 Touch & Drop Triggers for \(selectedAnimal.displayName)"
        triggerBannerSubtitle.stringValue = """
        • Left Touch: \(selectedAnimal.leftTriggerName) → triggers Left Macro
        • Right Touch: \(selectedAnimal.rightTriggerName) → triggers Right Macro
        • Drag & Drop: Drop files, URLs, or text onto \(selectedAnimal.nameWithoutEmoji) → triggers Dragging Macros
        """

        leftCardTitleLabel.stringValue = "👈 Left Trigger (\(selectedAnimal.leftTriggerName))"
        leftCardSubtitleLabel.stringValue = "Clicking the \(selectedAnimal.nameWithoutEmoji)'s \(selectedAnimal.leftTriggerName.lowercased()) runs this sequence:"

        rightCardTitleLabel.stringValue = "👉 Right Trigger (\(selectedAnimal.rightTriggerName))"
        rightCardSubtitleLabel.stringValue = "Clicking the \(selectedAnimal.nameWithoutEmoji)'s \(selectedAnimal.rightTriggerName.lowercased()) runs this sequence:"
    }

    // MARK: - Macros Tab

    private func buildMacrosTab() -> NSView {
        let scrollView = NSScrollView()
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

        let triggerBanner = makeTriggerBanner()
        let leftCard = makeCard(slot: .left, nameField: leftName, builder: leftBuilder)
        let rightCard = makeCard(slot: .right, nameField: rightName, builder: rightBuilder)
        let cards = NSStackView(views: [leftCard, rightCard])
        cards.orientation = .horizontal
        cards.spacing = 16
        cards.distribution = .fillEqually

        let dragCard = makeDragCard()

        let importButton = NSButton(title: "📥 Import Macros JSON…", target: self, action: #selector(importMacrosPressed))
        importButton.bezelStyle = .accessoryBarAction
        let exportButton = NSButton(title: "📤 Export Macros JSON…", target: self, action: #selector(exportMacrosPressed))
        exportButton.bezelStyle = .accessoryBarAction
        macroFileStatusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        macroFileStatusLabel.textColor = .secondaryLabelColor
        let fileButtons = NSStackView(views: [importButton, exportButton, macroFileStatusLabel])
        fileButtons.orientation = .horizontal
        fileButtons.alignment = .centerY
        fileButtons.spacing = 10

        let mainStack = NSStackView(views: [heading, note, triggerBanner, cards, dragCard, fileButtons])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 18
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 28, bottom: 24, right: 28)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),

            mainStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            triggerBanner.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            cards.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            dragCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56)
        ])

        return scrollView
    }

    private func makeTriggerBanner() -> NSView {
        triggerBannerTitle.font = .systemFont(ofSize: 14, weight: .bold)
        triggerBannerSubtitle.font = .systemFont(ofSize: 12, weight: .regular)
        triggerBannerSubtitle.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [triggerBannerTitle, triggerBannerSubtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor
        stack.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.30).cgColor
        stack.layer?.borderWidth = 1

        triggerBannerTitle.translatesAutoresizingMaskIntoConstraints = false
        triggerBannerSubtitle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            triggerBannerTitle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            triggerBannerSubtitle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32)
        ])
        return stack
    }

    private func makeCard(slot: BlushSlot, nameField: NSTextField, builder: MacroBuilderView) -> NSView {
        let label = slot == .left ? leftCardTitleLabel : rightCardTitleLabel
        label.font = .systemFont(ofSize: 15, weight: .semibold)

        let subtitle = slot == .left ? leftCardSubtitleLabel : rightCardSubtitleLabel
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

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
        let stack = NSStackView(views: [header, subtitle, nameLabel, nameField, builder])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        header.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        nameField.translatesAutoresizingMaskIntoConstraints = false
        builder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
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
        onSave?(
            UserMacro(name: leftName.stringValue, steps: leftBuilder.steps),
            UserMacro(name: rightName.stringValue, steps: rightBuilder.steps),
            dragEditor.bindings,
            selectedAnimal,
            selectedTheme,
            customPalette
        )
        close()
    }
    @objc private func cancelPressed() { close() }

    private func currentMacroDocument() -> MacroDocument {
        MacroDocument(
            left: UserMacro(name: leftName.stringValue, steps: leftBuilder.steps),
            right: UserMacro(name: rightName.stringValue, steps: rightBuilder.steps),
            dragMacros: dragEditor.bindings
        )
    }

    @objc private func exportMacrosPressed() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.title = "Export Animal Buddy Macros"
        panel.prompt = "Export"
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "animal-buddy-macros.json"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                try self.currentMacroDocument().exportJSONData().write(to: url, options: .atomic)
                self.macroFileStatusLabel.stringValue = "✅ Exported (url.lastPathComponent)"
                self.macroFileStatusLabel.textColor = .systemGreen
            } catch {
                self.showMacroFileError(title: "Could not export macros", error: error)
            }
        }
    }

    @objc private func importMacrosPressed() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "Import Animal Buddy Macros"
        panel.prompt = "Import"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                let document = try MacroDocument.decode(from: Data(contentsOf: url))
                self.leftName.stringValue = document.leftMacro.name
                self.leftBuilder.loadSteps(document.leftMacro.effectiveSteps)
                self.rightName.stringValue = document.rightMacro.name
                self.rightBuilder.loadSteps(document.rightMacro.effectiveSteps)
                self.dragEditor.load(bindings: document.dragMacros)
                self.macroFileStatusLabel.stringValue = "✅ Loaded (url.lastPathComponent) — press Save Settings to apply"
                self.macroFileStatusLabel.textColor = .systemGreen
            } catch {
                self.showMacroFileError(title: "Could not import macros", error: error)
            }
        }
    }

    private func showMacroFileError(title: String, error: Error) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window)
    }
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

    func load(bindings: [DragMacroBinding]) {
        saveSelectedMacro()
        macros = Dictionary(uniqueKeysWithValues: bindings.map { ($0.category, $0.macro) })
        loadSelectedMacro()
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
