import AppKit
import UniformTypeIdentifiers

@MainActor final class MacroSettingsWindowController: NSWindowController {
    var onSave: ((UserMacro, UserMacro, [DragMacroBinding], AnimalKind, PetThemePreset, PetThemePalette, Bool, Bool, Bool, Bool, String?, Bool, [InboxSubfolderRule], Bool, Bool, MinimizeDestination, Bool, Bool, Int, Bool, Bool, [CustomMonitoredApp]) -> Void)?
    var onThemeChanged: ((AnimalKind, PetThemePreset, PetThemePalette, Bool) -> Void)?
    var onCheckForUpdates: (() -> Void)?
    var onShowTipPreview: (() -> Void)?
    var onShowFocusSoundPreview: (() -> Void)?
    var onToggleMusicPreview: (() -> Void)?

    private var leftBuilder: MacroBuilderView
    private var rightBuilder: MacroBuilderView
    private let dragEditor: DragMacroEditorView
    private let leftName = NSTextField()
    private let rightName = NSTextField()

    private var selectedAnimal: AnimalKind
    private var selectedTheme: PetThemePreset
    private var customPalette: PetThemePalette
    private var hoverTranslucencyEnabled: Bool
    private var googlyEyesEnabled: Bool
    private var automaticallyCheckForUpdates: Bool
    private var helpfulTipsEnabled: Bool
    private var focusModeEnabled: Bool
    private var focusModeWorkRemindersEnabled: Bool
    private var focusModeIntervalMinutes: Int
    private var soundEffectsEnabled: Bool
    private var musicDancingEnabled: Bool
    private var customMusicApps: [CustomMonitoredApp]
    private let customAppsStack = NSStackView()
    private var destinationFolderPath: String?
    private var organizeInboxByFileType: Bool
    private var inboxSubfolderRules: [InboxSubfolderRule]
    private var subfolderSheetController: SubfolderRulesSheetController?
    private var alwaysOnTop: Bool
    private var snappingEnabled: Bool
    private var minimizeDestination: MinimizeDestination
    private let updateStatusLabel = NSTextField(labelWithString: "Animal Buddy a0.66")
    private let folderPathLabel = NSTextField(wrappingLabelWithString: "")

    private let focusModeToggle = NSButton(checkboxWithTitle: "Enable Focus Mode & Cute Sounds (off by default)", target: nil, action: nil)
    private let focusModeSegment = NSSegmentedControl(labels: ["🎯 Help Me Focus", "💖 Just Cute (For Nothing)"], trackingMode: .selectOne, target: nil, action: nil)
    private let focusModeDesc = NSTextField(wrappingLabelWithString: "")
    private let soundEffectsToggle = NSButton(checkboxWithTitle: "Play audio sound effects with bubble", target: nil, action: nil)
    private let focusIntervalPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let musicDancingToggle = NSButton(checkboxWithTitle: "Wear headphones & dance when listening to music", target: nil, action: nil)

    private let animalPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let themePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let themeDescription = NSTextField(wrappingLabelWithString: "")
    private let bodyLabel = NSTextField(labelWithString: "Body & Feathers")
    private let bellyLabel = NSTextField(labelWithString: "Belly & Face")
    private let beakLabel = NSTextField(labelWithString: "Beak & Feet")
    private let blushLabel = NSTextField(labelWithString: "Blush Cheeks")
    private let eyeLabel = NSTextField(labelWithString: "Eye Glow")
    private let googlyEyesToggle = NSButton(checkboxWithTitle: "Enable googly eyes (loose jiggling craft pupils)", target: nil, action: nil)
    private var googlyEyesRow: NSView!

    private let bodyColorWell = NSColorWell()
    private let bellyColorWell = NSColorWell()
    private let beakColorWell = NSColorWell()
    private let blushColorWell = NSColorWell()
    private let eyeHighlightColorWell = NSColorWell()
    private var previewPetView: PetView!

    private let tabSegment = NSSegmentedControl(labels: [
        "⚙️ General",
        "🎨 Plumage & Themes",
        "⚡️ Macros Workshop"
    ], trackingMode: .selectOne, target: nil, action: nil)
    private let tabContainer = NSView()
    private var generalView: NSView!
    private var appearanceView: NSView!
    private var macrosView: NSView!
    private let macroFileStatusLabel = NSTextField(labelWithString: "")

    private let triggerBannerTitle = NSTextField(labelWithString: "")
    private let triggerBannerSubtitle = NSTextField(wrappingLabelWithString: "")
    private let leftCardTitleLabel = NSTextField(labelWithString: "👈 Left Eye Macro")
    private let leftCardSubtitleLabel = NSTextField(wrappingLabelWithString: "Triggered by clicking the left eye")
    private let rightCardTitleLabel = NSTextField(labelWithString: "👉 Right Eye Macro")
    private let rightCardSubtitleLabel = NSTextField(wrappingLabelWithString: "Triggered by clicking the right eye")

    init(settings: AppSettings, initialTab: Int = 0) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 690),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Animal Buddy Settings"
        window.isReleasedWhenClosed = false
        leftBuilder = MacroBuilderView(steps: settings.leftBlushMacro.effectiveSteps)
        rightBuilder = MacroBuilderView(steps: settings.rightBlushMacro.effectiveSteps)
        dragEditor = DragMacroEditorView(bindings: settings.dragMacros)
        selectedAnimal = settings.animalKind
        selectedTheme = settings.themePreset
        customPalette = settings.customPalette
        hoverTranslucencyEnabled = settings.hoverTranslucencyEnabled
        googlyEyesEnabled = settings.googlyEyesEnabled
        automaticallyCheckForUpdates = settings.automaticallyCheckForUpdates
        helpfulTipsEnabled = settings.helpfulTipsEnabled
        focusModeEnabled = settings.focusModeEnabled
        focusModeWorkRemindersEnabled = settings.focusModeWorkRemindersEnabled
        focusModeIntervalMinutes = settings.focusModeIntervalMinutes
        soundEffectsEnabled = settings.soundEffectsEnabled
        musicDancingEnabled = settings.musicDancingEnabled
        customMusicApps = settings.customMusicApps
        destinationFolderPath = settings.destinationFolderPath
        organizeInboxByFileType = settings.organizeInboxByFileType
        inboxSubfolderRules = settings.inboxSubfolderRules
        alwaysOnTop = settings.alwaysOnTop
        snappingEnabled = settings.snappingEnabled
        minimizeDestination = settings.minimizeDestination

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

        generalView = buildGeneralTab()
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
        updateThemePopUpItems()
        updateColorLabels()
        updateColorWellsFromActivePalette()
        updateMacroTabLabels()
        updateFolderPathDisplay()
    }

    @objc private func tabChanged() {
        switchTab(to: tabSegment.selectedSegment)
    }

    func selectTab(_ index: Int) {
        let validIndex = min(max(index, 0), tabSegment.segmentCount - 1)
        tabSegment.selectedSegment = validIndex
        switchTab(to: validIndex)
    }

    private func switchTab(to index: Int) {
        tabContainer.subviews.forEach { $0.removeFromSuperview() }
        let targetView: NSView
        switch index {
        case 0: targetView = generalView!
        case 1: targetView = appearanceView!
        default: targetView = macrosView!
        }
        targetView.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(targetView)
        NSLayoutConstraint.activate([
            targetView.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor),
            targetView.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor),
            targetView.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            targetView.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor)
        ])
    }

    // MARK: - General Tab

    private func buildGeneralTab() -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = doc

        let heading = NSTextField(labelWithString: "General Settings")
        heading.font = .systemFont(ofSize: 20, weight: .bold)
        let note = NSTextField(wrappingLabelWithString: "Configure your desktop inbox folder, window presence, helpful tips, and software updates.")
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 3

        let inboxCard = makeInboxFolderCard()
        let windowCard = makeWindowBehaviorCard()
        let tipsCard = makeHelpfulTipsCard()
        let focusCard = makeFocusModeCard()
        let musicCard = makeMusicDancingCard()
        let updatesCard = makeSoftwareUpdatesCard()

        let mainStack = NSStackView(views: [heading, note, inboxCard, windowCard, tipsCard, focusCard, musicCard, updatesCard])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 28, bottom: 20, right: 28)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(mainStack)

        inboxCard.translatesAutoresizingMaskIntoConstraints = false
        windowCard.translatesAutoresizingMaskIntoConstraints = false
        tipsCard.translatesAutoresizingMaskIntoConstraints = false
        focusCard.translatesAutoresizingMaskIntoConstraints = false
        musicCard.translatesAutoresizingMaskIntoConstraints = false
        updatesCard.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),

            mainStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: doc.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),

            inboxCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            windowCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            tipsCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            focusCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            musicCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56),
            updatesCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -56)
        ])

        return scrollView
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

        animalPopUp.removeAllItems()
        animalPopUp.addItems(withTitles: AnimalKind.allCases.map { $0.displayName })
        animalPopUp.target = self
        animalPopUp.action = #selector(animalPopUpChanged)
        if let idx = AnimalKind.allCases.firstIndex(of: selectedAnimal) {
            animalPopUp.selectItem(at: idx)
        }

        let themeTitle = NSTextField(labelWithString: "Theme Preset")
        themeTitle.font = .systemFont(ofSize: 15, weight: .semibold)

        themePopUp.target = self
        themePopUp.action = #selector(themePopUpChanged)
        updateThemePopUpItems()

        themeDescription.font = .systemFont(ofSize: 12)
        themeDescription.textColor = .secondaryLabelColor
        themeDescription.maximumNumberOfLines = 3

        let stack = NSStackView(views: [animalTitle, animalPopUp, themeTitle, themePopUp, themeDescription])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        animalPopUp.translatesAutoresizingMaskIntoConstraints = false
        themePopUp.translatesAutoresizingMaskIntoConstraints = false
        themeDescription.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animalPopUp.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            themePopUp.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
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

        let googlyLabel = NSTextField(labelWithString: "Googly Eyes")
        googlyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        googlyEyesToggle.target = self
        googlyEyesToggle.action = #selector(toggleGooglyEyes(_:))
        googlyEyesToggle.state = googlyEyesEnabled ? .on : .off
        googlyEyesToggle.font = .systemFont(ofSize: 13)

        let googlyStack = NSStackView(views: [googlyLabel, NSView(), googlyEyesToggle])
        googlyStack.orientation = .horizontal
        googlyStack.alignment = .centerY
        googlyEyesRow = googlyStack
        googlyEyesRow.isHidden = (selectedAnimal != .slinky)

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

        let stack = NSStackView(views: [title, subtitle, bodyRow, bellyRow, beakRow, blushRow, eyeRow, googlyEyesRow, btnRow, themeStatusLabel])
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
        googlyEyesRow.translatesAutoresizingMaskIntoConstraints = false
        btnRow.translatesAutoresizingMaskIntoConstraints = false
        themeStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bodyRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            bellyRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            beakRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            blushRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            eyeRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            googlyEyesRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
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
        previewPetView.themePreset = selectedTheme
        previewPetView.themePalette = currentPalette
        previewPetView.googlyEyesEnabled = googlyEyesEnabled

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

    // MARK: - General Tab Cards & Actions

    private func makeInboxFolderCard() -> NSView {
        let title = NSTextField(labelWithString: "📁 Desktop Inbox Folder")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let desc = NSTextField(wrappingLabelWithString: "Items dragged and dropped onto Animal Buddy without a custom drop macro are safely stored in this folder.")
        desc.font = .systemFont(ofSize: 11)
        desc.textColor = .secondaryLabelColor

        folderPathLabel.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        folderPathLabel.textColor = .labelColor
        folderPathLabel.isSelectable = true

        let chooseBtn = NSButton(title: "Choose Folder…", target: self, action: #selector(chooseFolderPressed))
        chooseBtn.bezelStyle = .rounded
        chooseBtn.font = .systemFont(ofSize: 12)

        let revealBtn = NSButton(title: "Reveal in Finder", target: self, action: #selector(revealFolderPressed))
        revealBtn.bezelStyle = .rounded
        revealBtn.font = .systemFont(ofSize: 12)

        let resetBtn = NSButton(title: "Reset to Default", target: self, action: #selector(resetFolderPressed))
        resetBtn.bezelStyle = .rounded
        resetBtn.font = .systemFont(ofSize: 12)

        let btnRow = NSStackView(views: [chooseBtn, revealBtn, resetBtn])
        btnRow.orientation = .horizontal
        btnRow.spacing = 10

        let organizeToggle = NSButton(checkboxWithTitle: "Sort dropped files into subfolders by type", target: self, action: #selector(toggleOrganizeSubfolders(_:)))
        organizeToggle.state = organizeInboxByFileType ? .on : .off
        organizeToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let organizeDesc = NSTextField(wrappingLabelWithString: "When enabled, Animal Buddy automatically sorts items into Images, Documents, Audio, Videos, Archives, Code, Applications, Notes, and Links subfolders inside your inbox.")
        organizeDesc.font = .systemFont(ofSize: 11)
        organizeDesc.textColor = .secondaryLabelColor

        let customizeRulesBtn = NSButton(title: "⚙️ Customize Subfolder Types & Regex Rules…", target: self, action: #selector(customizeRulesPressed))
        customizeRulesBtn.bezelStyle = .rounded
        customizeRulesBtn.font = .systemFont(ofSize: 12, weight: .medium)

        let stack = NSStackView(views: [title, desc, folderPathLabel, btnRow, organizeToggle, organizeDesc, customizeRulesBtn])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        desc.translatesAutoresizingMaskIntoConstraints = false
        folderPathLabel.translatesAutoresizingMaskIntoConstraints = false
        btnRow.translatesAutoresizingMaskIntoConstraints = false
        organizeToggle.translatesAutoresizingMaskIntoConstraints = false
        organizeDesc.translatesAutoresizingMaskIntoConstraints = false
        customizeRulesBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            desc.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            folderPathLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            btnRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            organizeToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            organizeDesc.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            customizeRulesBtn.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    private func makeWindowBehaviorCard() -> NSView {
        let title = NSTextField(labelWithString: "🪟 Window Behavior & Snapping")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let floatingToggle = NSButton(checkboxWithTitle: "Always on top (floats above all regular windows and spaces)", target: self, action: #selector(toggleAlwaysOnTop(_:)))
        floatingToggle.state = alwaysOnTop ? .on : .off
        floatingToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let transToggle = NSButton(checkboxWithTitle: "Enable subtle translucency at rest (dims to 35% opacity when idle, 100% on hover)", target: self, action: #selector(toggleHoverTranslucency(_:)))
        transToggle.state = hoverTranslucencyEnabled ? .on : .off
        transToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let transDesc = NSTextField(wrappingLabelWithString: "When enabled, Animal Buddy floats transparently over your windows and text editors so it never blocks your view, then instantly becomes solid the moment you move your cursor over it.")
        transDesc.font = .systemFont(ofSize: 11)
        transDesc.textColor = .secondaryLabelColor

        let snapToggle = NSButton(checkboxWithTitle: "Snap to screen edges when dropped", target: self, action: #selector(toggleSnapping(_:)))
        snapToggle.state = snappingEnabled ? .on : .off
        snapToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let minTitle = NSTextField(labelWithString: "Minimize Pet To:")
        minTitle.font = .systemFont(ofSize: 12, weight: .medium)

        let minSegment = NSSegmentedControl(labels: ["Menu Bar", "Dock"], trackingMode: .selectOne, target: self, action: #selector(minimizeDestinationChanged(_:)))
        minSegment.selectedSegment = (minimizeDestination == .dock ? 1 : 0)

        let minRow = NSStackView(views: [minTitle, minSegment])
        minRow.orientation = .horizontal
        minRow.spacing = 10
        minRow.alignment = .centerY

        let stack = NSStackView(views: [title, floatingToggle, transToggle, transDesc, snapToggle, minRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        floatingToggle.translatesAutoresizingMaskIntoConstraints = false
        transToggle.translatesAutoresizingMaskIntoConstraints = false
        transDesc.translatesAutoresizingMaskIntoConstraints = false
        snapToggle.translatesAutoresizingMaskIntoConstraints = false
        minRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            floatingToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            transToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            transDesc.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            snapToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            minRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    private func makeHelpfulTipsCard() -> NSView {
        let title = NSTextField(labelWithString: "💡 Helpful Tips & Discovery")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let tipsToggle = NSButton(checkboxWithTitle: "Show random helpful tips in a speech bubble (off by default)", target: self, action: #selector(toggleHelpfulTips(_:)))
        tipsToggle.state = helpfulTipsEnabled ? .on : .off
        tipsToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let tipsDesc = NSTextField(wrappingLabelWithString: "Occasionally displays friendly, non-intrusive speech bubble tips above your buddy while resting to help you discover shortcuts, drop modifiers, and macros.")
        tipsDesc.font = .systemFont(ofSize: 11)
        tipsDesc.textColor = .secondaryLabelColor

        let showTipBtn = NSButton(title: "Show a Tip Now", target: self, action: #selector(showTipNowPressed))
        showTipBtn.bezelStyle = .rounded
        showTipBtn.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [title, tipsToggle, tipsDesc, showTipBtn])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        tipsToggle.translatesAutoresizingMaskIntoConstraints = false
        tipsDesc.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tipsToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            tipsDesc.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    private func makeFocusModeCard() -> NSView {
        let title = NSTextField(labelWithString: "🎯 Focus Mode & Cute Sounds")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        focusModeToggle.target = self
        focusModeToggle.action = #selector(toggleFocusModeCheckbox(_:))
        focusModeToggle.state = focusModeEnabled ? .on : .off
        focusModeToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let introDesc = NSTextField(wrappingLabelWithString: "Your animal companion periodically makes adorable noises in a speech bubble to keep you company while working at your desk.")
        introDesc.font = .systemFont(ofSize: 11)
        introDesc.textColor = .secondaryLabelColor

        focusModeSegment.selectedSegment = focusModeWorkRemindersEnabled ? 0 : 1
        focusModeSegment.target = self
        focusModeSegment.action = #selector(focusModeSegmentChanged)
        focusModeSegment.segmentStyle = .texturedRounded

        updateFocusModeDesc()
        focusModeDesc.font = .systemFont(ofSize: 11)
        focusModeDesc.textColor = .secondaryLabelColor

        soundEffectsToggle.target = self
        soundEffectsToggle.action = #selector(toggleSoundEffectsCheckbox(_:))
        soundEffectsToggle.state = soundEffectsEnabled ? .on : .off
        soundEffectsToggle.font = .systemFont(ofSize: 12)

        let intervalLabel = NSTextField(labelWithString: "Sound & Bubble Interval:")
        intervalLabel.font = .systemFont(ofSize: 12, weight: .medium)

        focusIntervalPopUp.removeAllItems()
        let intervalOptions = [5, 10, 15, 20, 30]
        for m in intervalOptions {
            focusIntervalPopUp.addItem(withTitle: "Every \(m) minutes")
        }
        focusIntervalPopUp.target = self
        focusIntervalPopUp.action = #selector(focusIntervalChanged)
        if let idx = intervalOptions.firstIndex(of: focusModeIntervalMinutes) {
            focusIntervalPopUp.selectItem(at: idx)
        } else {
            focusIntervalPopUp.selectItem(at: 1)
        }

        let intervalRow = NSStackView(views: [intervalLabel, focusIntervalPopUp])
        intervalRow.orientation = .horizontal
        intervalRow.alignment = .centerY
        intervalRow.spacing = 10

        let tryBtn = NSButton(title: "Try Sound & Bubble Now", target: self, action: #selector(tryFocusSoundPressed))
        tryBtn.bezelStyle = .rounded
        tryBtn.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [title, focusModeToggle, introDesc, focusModeSegment, focusModeDesc, soundEffectsToggle, intervalRow, tryBtn])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        focusModeToggle.translatesAutoresizingMaskIntoConstraints = false
        introDesc.translatesAutoresizingMaskIntoConstraints = false
        focusModeSegment.translatesAutoresizingMaskIntoConstraints = false
        focusModeDesc.translatesAutoresizingMaskIntoConstraints = false
        soundEffectsToggle.translatesAutoresizingMaskIntoConstraints = false
        intervalRow.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            focusModeToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            introDesc.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            focusModeSegment.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            focusModeDesc.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            soundEffectsToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            intervalRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    private func makeMusicDancingCard() -> NSView {
        let title = NSTextField(labelWithString: "🎧 Music Companion & Headphones")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        musicDancingToggle.target = self
        musicDancingToggle.action = #selector(toggleMusicDancingCheckbox(_:))
        musicDancingToggle.state = musicDancingEnabled ? .on : .off
        musicDancingToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let desc = NSTextField(wrappingLabelWithString: "Puts headphones on your pet and grooves along when music or audio is playing from your music apps and browsers. When paused, your buddy immediately takes off the headphones.")
        desc.font = .systemFont(ofSize: 11)
        desc.textColor = .secondaryLabelColor

        let appsHeader = NSTextField(labelWithString: "Monitored Music & Media Apps:")
        appsHeader.font = .systemFont(ofSize: 12, weight: .bold)

        let builtInSummary = NSTextField(wrappingLabelWithString: "Built-in: Apple Music, Spotify, Safari, Chrome, Arc, Brave, Firefox, Edge, VLC, Podcasts, Tidal, and common media players.")
        builtInSummary.font = .systemFont(ofSize: 11)
        builtInSummary.textColor = .secondaryLabelColor

        customAppsStack.orientation = .vertical
        customAppsStack.alignment = .leading
        customAppsStack.spacing = 6
        refreshCustomAppsList()

        let addAppBtn = NSButton(title: "+ Add App…", target: self, action: #selector(addCustomAppPressed))
        addAppBtn.bezelStyle = .rounded
        addAppBtn.font = .systemFont(ofSize: 12)

        let previewBtn = NSButton(title: "Preview Headphones & Dance", target: self, action: #selector(previewMusicDancingPressed))
        previewBtn.bezelStyle = .rounded
        previewBtn.font = .systemFont(ofSize: 12)

        let btnRow = NSStackView(views: [addAppBtn, previewBtn])
        btnRow.orientation = .horizontal
        btnRow.alignment = .centerY
        btnRow.spacing = 10

        let stack = NSStackView(views: [title, musicDancingToggle, desc, appsHeader, builtInSummary, customAppsStack, btnRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        musicDancingToggle.translatesAutoresizingMaskIntoConstraints = false
        desc.translatesAutoresizingMaskIntoConstraints = false
        builtInSummary.translatesAutoresizingMaskIntoConstraints = false
        customAppsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            musicDancingToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            desc.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            builtInSummary.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            customAppsStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    private func makeSoftwareUpdatesCard() -> NSView {
        let title = NSTextField(labelWithString: "🚀 Software Updates")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let autoUpdateToggle = NSButton(checkboxWithTitle: "Automatically check for updates on startup", target: self, action: #selector(toggleAutoUpdates(_:)))
        autoUpdateToggle.state = automaticallyCheckForUpdates ? .on : .off
        autoUpdateToggle.font = .systemFont(ofSize: 13, weight: .medium)

        let checkNowBtn = NSButton(title: "Check for Updates Now…", target: self, action: #selector(checkNowPressed))
        checkNowBtn.bezelStyle = .rounded
        checkNowBtn.font = .systemFont(ofSize: 12)

        updateStatusLabel.font = .systemFont(ofSize: 11)
        updateStatusLabel.textColor = .secondaryLabelColor

        let updateRow = NSStackView(views: [checkNowBtn, updateStatusLabel])
        updateRow.orientation = .horizontal
        updateRow.alignment = .centerY
        updateRow.spacing = 12

        let stack = NSStackView(views: [title, autoUpdateToggle, updateRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        autoUpdateToggle.translatesAutoresizingMaskIntoConstraints = false
        updateRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            autoUpdateToggle.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            updateRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
        return stack
    }

    // MARK: - Folder & Behavior Actions

    private var effectiveFolderPath: String {
        destinationFolderPath ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("Animal Buddy Inbox", isDirectory: true).path ?? "~/Desktop/Animal Buddy Inbox"
    }

    private func updateFolderPathDisplay() {
        let path = effectiveFolderPath
        let isCustom = (destinationFolderPath != nil)
        folderPathLabel.stringValue = "\(isCustom ? "📍 Custom: " : "🏠 Default: ")\(path)"
    }

    @objc private func chooseFolderPressed() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose a destination folder for Animal Buddy drops"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.destinationFolderPath = url.path
            self.updateFolderPathDisplay()
        }
    }

    @objc private func revealFolderPressed() {
        let path = effectiveFolderPath
        let url = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    @objc private func resetFolderPressed() {
        destinationFolderPath = nil
        updateFolderPathDisplay()
    }

    @objc private func toggleOrganizeSubfolders(_ sender: NSButton) {
        organizeInboxByFileType = (sender.state == .on)
    }

    @objc private func customizeRulesPressed() {
        guard let window else { return }
        let sheet = SubfolderRulesSheetController(rules: inboxSubfolderRules)
        sheet.onSave = { [weak self] updated in
            self?.inboxSubfolderRules = updated
        }
        self.subfolderSheetController = sheet
        window.beginSheet(sheet.window!) { [weak self] _ in
            self?.subfolderSheetController = nil
        }
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSButton) {
        alwaysOnTop = (sender.state == .on)
    }

    @objc private func toggleHoverTranslucency(_ sender: NSButton) {
        hoverTranslucencyEnabled = (sender.state == .on)
    }

    @objc private func toggleSnapping(_ sender: NSButton) {
        snappingEnabled = (sender.state == .on)
    }

    @objc private func minimizeDestinationChanged(_ sender: NSSegmentedControl) {
        minimizeDestination = (sender.selectedSegment == 1) ? .dock : .menubar
    }

    @objc private func toggleAutoUpdates(_ sender: NSButton) {
        automaticallyCheckForUpdates = (sender.state == .on)
    }

    @objc private func checkNowPressed() {
        onCheckForUpdates?()
    }

    @objc private func toggleHelpfulTips(_ sender: NSButton) {
        helpfulTipsEnabled = (sender.state == .on)
    }

    @objc private func showTipNowPressed() {
        onShowTipPreview?()
    }

    private func updateFocusModeDesc() {
        if focusModeWorkRemindersEnabled {
            focusModeDesc.stringValue = "🎯 Help Me Focus: Clicking the sound bubble prompts you with an encouraging reminder to stay in the zone and get back to work!"
        } else {
            focusModeDesc.stringValue = "💖 Just Cute (For Nothing): Clicking the sound bubble triggers a warm loving reaction (*purrs happily*) without any work reminders."
        }
    }

    @objc private func toggleFocusModeCheckbox(_ sender: NSButton) {
        focusModeEnabled = (sender.state == .on)
    }

    @objc private func focusModeSegmentChanged(_ sender: NSSegmentedControl) {
        focusModeWorkRemindersEnabled = (sender.selectedSegment == 0)
        updateFocusModeDesc()
    }

    @objc private func toggleSoundEffectsCheckbox(_ sender: NSButton) {
        soundEffectsEnabled = (sender.state == .on)
    }

    @objc private func focusIntervalChanged(_ sender: NSPopUpButton) {
        let intervalOptions = [5, 10, 15, 20, 30]
        let idx = sender.indexOfSelectedItem
        if idx >= 0 && idx < intervalOptions.count {
            focusModeIntervalMinutes = intervalOptions[idx]
        }
    }

    @objc private func tryFocusSoundPressed() {
        onShowFocusSoundPreview?()
    }

    @objc private func toggleMusicDancingCheckbox(_ sender: NSButton) {
        musicDancingEnabled = (sender.state == .on)
    }

    @objc private func previewMusicDancingPressed() {
        previewPetView.isDancingToMusic.toggle()
        onToggleMusicPreview?()
    }

    private func refreshCustomAppsList() {
        for subview in customAppsStack.arrangedSubviews {
            customAppsStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        if customMusicApps.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No custom apps added yet. Click \"+ Add App…\" to monitor any additional audio player or app.")
            emptyLabel.font = .systemFont(ofSize: 11)
            emptyLabel.textColor = .tertiaryLabelColor
            emptyLabel.maximumNumberOfLines = 2
            customAppsStack.addArrangedSubview(emptyLabel)
            return
        }

        for (index, app) in customMusicApps.enumerated() {
            let iconView = NSImageView()
            if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)?.path {
                iconView.image = NSWorkspace.shared.icon(forFile: path)
            } else {
                iconView.image = NSImage(systemSymbolName: "app.badge", accessibilityDescription: nil)
            }
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 16),
                iconView.heightAnchor.constraint(equalToConstant: 16)
            ])

            let nameLabel = NSTextField(labelWithString: "\(app.name) (\(app.bundleIdentifier))")
            nameLabel.font = .systemFont(ofSize: 11, weight: .medium)

            let removeBtn = NSButton(title: "✕", target: self, action: #selector(removeCustomAppPressed(_:)))
            removeBtn.bezelStyle = .inline
            removeBtn.tag = index
            removeBtn.isBordered = false
            removeBtn.font = .systemFont(ofSize: 11, weight: .bold)

            let row = NSStackView(views: [iconView, nameLabel, removeBtn])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 6
            customAppsStack.addArrangedSubview(row)
        }
    }

    @objc private func addCustomAppPressed() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "Select Application to Monitor"
        panel.prompt = "Add App"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            let bundle = Bundle(url: url)
            let name = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle?.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            let bundleID = bundle?.bundleIdentifier ?? url.lastPathComponent

            if !self.customMusicApps.contains(where: { $0.bundleIdentifier == bundleID }) {
                self.customMusicApps.append(CustomMonitoredApp(name: name, bundleIdentifier: bundleID))
                self.refreshCustomAppsList()
                MusicPlaybackWatcher.shared.updateCustomApps(self.customMusicApps)
            }
        }
    }

    @objc private func removeCustomAppPressed(_ sender: NSButton) {
        let index = sender.tag
        if index >= 0 && index < customMusicApps.count {
            customMusicApps.remove(at: index)
            refreshCustomAppsList()
            MusicPlaybackWatcher.shared.updateCustomApps(customMusicApps)
        }
    }

    @objc private func toggleGooglyEyes(_ sender: NSButton) {
        googlyEyesEnabled = (sender.state == .on)
        previewPetView.googlyEyesEnabled = googlyEyesEnabled
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette, googlyEyesEnabled)
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

    @objc private func animalPopUpChanged() {
        let idx = animalPopUp.indexOfSelectedItem
        guard idx >= 0 && idx < AnimalKind.allCases.count else { return }
        selectedAnimal = AnimalKind.allCases[idx]
        googlyEyesRow?.isHidden = (selectedAnimal != .slinky)
        updateThemePopUpItems()
        updateColorLabels()
        updateColorWellsFromActivePalette()
        updateThemeDescription()
        updateMacroTabLabels()
        if !selectedAnimal.themePresets.contains(selectedTheme) {
            selectedTheme = .classic
            if let classicIdx = selectedAnimal.themePresets.firstIndex(of: .classic) {
                themePopUp.selectItem(at: classicIdx)
            }
        }
        previewPetView.animalKind = selectedAnimal
        previewPetView.themePreset = selectedTheme
        previewPetView.themePalette = currentPalette
        previewPetView.googlyEyesEnabled = googlyEyesEnabled
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette, googlyEyesEnabled)
    }

    @objc private func themePopUpChanged() {
        let presets = selectedAnimal.themePresets
        let idx = themePopUp.indexOfSelectedItem
        guard idx >= 0 && idx < presets.count else { return }
        selectedTheme = presets[idx]
        updateColorWellsFromActivePalette()
        updateThemeDescription()
        previewPetView.animalKind = selectedAnimal
        previewPetView.themePreset = selectedTheme
        previewPetView.themePalette = currentPalette
        previewPetView.googlyEyesEnabled = googlyEyesEnabled
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette, googlyEyesEnabled)
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        selectedTheme = .custom
        updateThemePopUpItems()
        customPalette = PetThemePalette(
            bodyColor: CodableColor(nsColor: bodyColorWell.color),
            bellyColor: CodableColor(nsColor: bellyColorWell.color),
            beakColor: CodableColor(nsColor: beakColorWell.color),
            blushColor: CodableColor(nsColor: blushColorWell.color),
            eyeHighlightColor: CodableColor(nsColor: eyeHighlightColorWell.color)
        )
        updateThemeDescription()
        previewPetView.themePalette = customPalette
        previewPetView.themePreset = selectedTheme
        previewPetView.googlyEyesEnabled = googlyEyesEnabled
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette, googlyEyesEnabled)
    }

    @objc private func resetColorsPressed() {
        selectedTheme = .classic
        updateThemePopUpItems()
        customPalette = selectedAnimal.defaultPalette(for: .classic)
        updateColorWellsFromActivePalette()
        updateThemeDescription()
        previewPetView.animalKind = selectedAnimal
        previewPetView.themePreset = selectedTheme
        previewPetView.themePalette = currentPalette
        previewPetView.googlyEyesEnabled = googlyEyesEnabled
        themeStatusLabel.stringValue = "Restored classic colors for \(selectedAnimal.displayName)"
        themeStatusLabel.textColor = .secondaryLabelColor
        onThemeChanged?(selectedAnimal, selectedTheme, customPalette, googlyEyesEnabled)
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
                if let animalIdx = AnimalKind.allCases.firstIndex(of: animal) {
                    self.animalPopUp.selectItem(at: animalIdx)
                }
                self.googlyEyesRow?.isHidden = (animal != .slinky)
                self.customPalette = importedPalette
                self.selectedTheme = .custom
                self.updateThemePopUpItems()
                self.updateColorLabels()
                self.updateColorWellsFromActivePalette()
                self.updateThemeDescription()
                self.updateMacroTabLabels()
                self.previewPetView.animalKind = animal
                self.previewPetView.themePreset = .custom
                self.previewPetView.themePalette = importedPalette
                self.previewPetView.googlyEyesEnabled = self.googlyEyesEnabled
                self.onThemeChanged?(animal, .custom, importedPalette, self.googlyEyesEnabled)
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

    private func updateThemePopUpItems() {
        themePopUp.removeAllItems()
        let presets = selectedAnimal.themePresets
        themePopUp.addItems(withTitles: presets.map { $0.displayName(for: selectedAnimal) })
        if let idx = presets.firstIndex(of: selectedTheme) {
            themePopUp.selectItem(at: idx)
        } else if !presets.isEmpty {
            themePopUp.selectItem(at: 0)
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
            eyeLabel.stringValue = "Eye Glow"
        case .slinky:
            bodyLabel.stringValue = "Front Coil & Base"
            bellyLabel.stringValue = "Middle Coil Spring"
            beakLabel.stringValue = "Rear Coil Spring"
            blushLabel.stringValue = "Cheek Accent Rings"
            eyeLabel.stringValue = "Eye Pupils & Metal"
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
        triggerBannerTitle.stringValue = "🎯 Eye Click & Drag Triggers for \(selectedAnimal.displayName)"
        triggerBannerSubtitle.stringValue = """
        • Left Eye Click: \(selectedAnimal.leftTriggerName) → triggers Left Eye Macro
        • Right Eye Click: \(selectedAnimal.rightTriggerName) → triggers Right Eye Macro
        • Drag & Drop: Drop files, URLs, or text onto \(selectedAnimal.nameWithoutEmoji) → triggers Dragging Macros
        """

        leftCardTitleLabel.stringValue = "👈 Left Eye Macro (\(selectedAnimal.leftTriggerName))"
        leftCardSubtitleLabel.stringValue = "Clicking the \(selectedAnimal.nameWithoutEmoji)'s \(selectedAnimal.leftTriggerName.lowercased()) runs this sequence:"

        rightCardTitleLabel.stringValue = "👉 Right Eye Macro (\(selectedAnimal.rightTriggerName))"
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
            customPalette,
            hoverTranslucencyEnabled,
            googlyEyesEnabled,
            automaticallyCheckForUpdates,
            helpfulTipsEnabled,
            destinationFolderPath,
            organizeInboxByFileType,
            inboxSubfolderRules,
            alwaysOnTop,
            snappingEnabled,
            minimizeDestination,
            focusModeEnabled,
            focusModeWorkRemindersEnabled,
            focusModeIntervalMinutes,
            soundEffectsEnabled,
            musicDancingEnabled,
            customMusicApps
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
            choicePicker.removeAllItems(); choicePicker.addItem(withTitle: "Right Eye Macro"); choicePicker.addItem(withTitle: "Left Eye Macro")
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

@MainActor final class SubfolderRulesSheetController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    var onSave: (([InboxSubfolderRule]) -> Void)?
    private var rules: [InboxSubfolderRule]
    private let stackView = NSStackView()

    init(rules: [InboxSubfolderRule]) {
        self.rules = rules
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Customize Inbox Subfolder Rules & Patterns"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "📁 Inbox Subfolder Rules & Patterns")
        title.font = .systemFont(ofSize: 16, weight: .bold)

        let subtitle = NSTextField(wrappingLabelWithString: "Define which subfolders dropped items are saved into. You can specify file extensions, regular expression patterns (regex) for matching filenames, or both. Rules are evaluated in top-to-bottom priority order.")
        subtitle.font = .systemFont(ofSize: 11.5)
        subtitle.textColor = .secondaryLabelColor

        let headerStack = NSStackView(views: [title, subtitle])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        refreshRulesList()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let clip = NSClipView()
        clip.documentView = stackView
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView = clip

        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -24),
            stackView.topAnchor.constraint(equalTo: clip.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: clip.leadingAnchor, constant: 12)
        ])

        let addRuleBtn = NSButton(title: "➕ Add Custom Rule", target: self, action: #selector(addRulePressed))
        addRuleBtn.bezelStyle = .rounded
        addRuleBtn.font = .systemFont(ofSize: 12, weight: .medium)

        let resetDefaultsBtn = NSButton(title: "🔄 Reset to Defaults", target: self, action: #selector(resetDefaultsPressed))
        resetDefaultsBtn.bezelStyle = .rounded
        resetDefaultsBtn.font = .systemFont(ofSize: 12)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}" // Escape key
        cancelBtn.font = .systemFont(ofSize: 12)

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(donePressed))
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r" // Enter key
        doneBtn.font = .systemFont(ofSize: 12, weight: .semibold)

        let leftBtns = NSStackView(views: [addRuleBtn, resetDefaultsBtn])
        leftBtns.orientation = .horizontal
        leftBtns.spacing = 10

        let rightBtns = NSStackView(views: [cancelBtn, doneBtn])
        rightBtns.orientation = .horizontal
        rightBtns.spacing = 10

        let bottomRow = NSStackView(views: [leftBtns, rightBtns])
        bottomRow.orientation = .horizontal
        bottomRow.distribution = .equalSpacing
        bottomRow.alignment = .centerY

        let mainStack = NSStackView(views: [headerStack, scrollView, bottomRow])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 14
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 18, right: 20)

        mainStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: content.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            headerStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40),
            scrollView.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),
            bottomRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40)
        ])
    }

    private func refreshRulesList() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, rule) in rules.enumerated() {
            let row = makeRuleRow(rule: rule, index: idx)
            stackView.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
    }

    private func makeRuleRow(rule: InboxSubfolderRule, index: Int) -> NSView {
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 8
        card.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let toggle = NSButton(checkboxWithTitle: "", target: self, action: #selector(ruleToggled(_:)))
        toggle.state = rule.isEnabled ? .on : .off
        toggle.tag = index

        let catLabel = NSTextField(labelWithString: "Rule:")
        catLabel.font = .systemFont(ofSize: 11.5, weight: .medium)

        let catField = NSTextField(string: rule.categoryName)
        catField.font = .systemFont(ofSize: 11.5)
        catField.placeholderString = "Category Name"
        catField.tag = index
        catField.target = self
        catField.action = #selector(catFieldChanged(_:))
        catField.delegate = self

        let folderLabel = NSTextField(labelWithString: "Folder:")
        folderLabel.font = .systemFont(ofSize: 11.5, weight: .medium)

        let folderField = NSTextField(string: rule.folderName)
        folderField.font = .systemFont(ofSize: 11.5)
        folderField.placeholderString = "Subfolder name"
        folderField.tag = index
        folderField.target = self
        folderField.action = #selector(folderFieldChanged(_:))
        folderField.delegate = self

        let deleteBtn = NSButton(title: "✕", target: self, action: #selector(deleteRulePressed(_:)))
        deleteBtn.bezelStyle = .inline
        deleteBtn.font = .systemFont(ofSize: 12, weight: .bold)
        deleteBtn.tag = index
        deleteBtn.contentTintColor = .systemRed

        let topRow = NSStackView(views: [toggle, catLabel, catField, folderLabel, folderField, deleteBtn])
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.alignment = .centerY

        let regexLabel = NSTextField(labelWithString: "Regex:")
        regexLabel.font = .systemFont(ofSize: 11)
        regexLabel.textColor = .secondaryLabelColor

        let regexField = NSTextField(string: rule.regexPattern ?? "")
        regexField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        regexField.placeholderString = "e.g. ^holiday_.* or .*_receipt"
        regexField.tag = index
        regexField.target = self
        regexField.action = #selector(regexFieldChanged(_:))
        regexField.delegate = self

        let extLabel = NSTextField(labelWithString: "Extensions:")
        extLabel.font = .systemFont(ofSize: 11)
        extLabel.textColor = .secondaryLabelColor

        let extField = NSTextField(string: rule.extensionsString)
        extField.font = .systemFont(ofSize: 11)
        extField.placeholderString = "e.g. png, jpg, pdf (comma separated)"
        extField.tag = index
        extField.target = self
        extField.action = #selector(extFieldChanged(_:))
        extField.delegate = self

        let bottomRow = NSStackView(views: [regexLabel, regexField, extLabel, extField])
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .centerY

        catField.translatesAutoresizingMaskIntoConstraints = false
        folderField.translatesAutoresizingMaskIntoConstraints = false
        regexField.translatesAutoresizingMaskIntoConstraints = false
        extField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            catField.widthAnchor.constraint(equalToConstant: 140),
            folderField.widthAnchor.constraint(equalToConstant: 140),
            regexField.widthAnchor.constraint(equalToConstant: 180),
            extField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])

        card.addArrangedSubview(topRow)
        card.addArrangedSubview(bottomRow)
        topRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topRow.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -28),
            bottomRow.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -28)
        ])

        return card
    }

    @objc private func catFieldChanged(_ sender: NSTextField) {
        let idx = sender.tag
        guard idx < rules.count else { return }
        rules[idx].categoryName = sender.stringValue
    }

    @objc private func folderFieldChanged(_ sender: NSTextField) {
        let idx = sender.tag
        guard idx < rules.count else { return }
        rules[idx].folderName = sender.stringValue
    }

    @objc private func regexFieldChanged(_ sender: NSTextField) {
        let idx = sender.tag
        guard idx < rules.count else { return }
        let val = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        rules[idx].regexPattern = val.isEmpty ? nil : val
    }

    @objc private func extFieldChanged(_ sender: NSTextField) {
        let idx = sender.tag
        guard idx < rules.count else { return }
        rules[idx].extensionsString = sender.stringValue
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let idx = field.tag
        guard idx < rules.count else { return }
        if field.placeholderString == "Category Name" {
            rules[idx].categoryName = field.stringValue
        } else if field.placeholderString == "Subfolder name" {
            rules[idx].folderName = field.stringValue
        } else if field.placeholderString?.starts(with: "e.g. ^holiday") == true {
            let val = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            rules[idx].regexPattern = val.isEmpty ? nil : val
        } else if field.placeholderString?.starts(with: "e.g. png") == true {
            rules[idx].extensionsString = field.stringValue
        }
    }

    @objc private func ruleToggled(_ sender: NSButton) {
        let idx = sender.tag
        guard idx < rules.count else { return }
        rules[idx].isEnabled = (sender.state == .on)
    }

    @objc private func deleteRulePressed(_ sender: NSButton) {
        let idx = sender.tag
        guard idx < rules.count else { return }
        rules.remove(at: idx)
        refreshRulesList()
    }

    @objc private func addRulePressed() {
        let newRule = InboxSubfolderRule(
            id: UUID().uuidString,
            categoryName: "Custom Pattern",
            folderName: "Custom",
            extensions: [],
            regexPattern: "^holiday_.*",
            isEnabled: true
        )
        rules.insert(newRule, at: 0)
        refreshRulesList()
    }

    @objc private func resetDefaultsPressed() {
        rules = InboxSubfolderRule.defaultRules
        refreshRulesList()
    }

    @objc private func donePressed() {
        onSave?(rules)
        dismissSheet(returnCode: .OK)
    }

    @objc private func cancelPressed() {
        dismissSheet(returnCode: .cancel)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismissSheet(returnCode: .cancel)
        return true
    }

    private func dismissSheet(returnCode: NSApplication.ModalResponse) {
        guard let sheetWindow = self.window else { return }
        if let parent = sheetWindow.sheetParent {
            parent.endSheet(sheetWindow, returnCode: returnCode)
        } else if let parent = NSApp.keyWindow, parent != sheetWindow {
            parent.endSheet(sheetWindow, returnCode: returnCode)
        }
        sheetWindow.orderOut(nil)
    }
}
