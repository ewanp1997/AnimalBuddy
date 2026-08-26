import AppKit
import UniformTypeIdentifiers

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindowController?
    private var settings = AppSettings()
    private let settingsStore = SettingsStore()
    private var statusBar: StatusBarController?
    private var macroSettingsWindow: MacroSettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AnimalBuddyIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
            NSApp.dockTile.display()
        }
        settings = settingsStore.load()
        let registry = ActionRegistry(settings: settings)
        petWindow = PetWindowController(settings: settings, registry: registry)
        statusBar = StatusBarController()
        statusBar?.onShowPet = { [weak self] in self?.petWindow?.showPet() }
        statusBar?.onMinimizeDestinationChanged = { [weak self] destination in self?.setMinimizeDestination(destination) }
        statusBar?.onSnappingChanged = { [weak self] enabled in self?.setSnapping(enabled) }
        statusBar?.onAnimalAndThemeChanged = { [weak self] animal, theme in self?.setAnimalAndTheme(animal, theme: theme) }
        statusBar?.onImportThemeJSON = { [weak self] in self?.importThemeFromMenu() }
        statusBar?.onExportThemeJSON = { [weak self] in self?.exportThemeFromMenu() }
        statusBar?.onOpenAppearanceSettings = { [weak self] in self?.showSettings(initialTab: 0) }
        statusBar?.onConfigureMacros = { [weak self] in self?.showSettings(initialTab: 1) }
        statusBar?.onOpenSettings = { [weak self] in self?.showSettings(initialTab: 0) }
        statusBar?.onOpenAccessibility = {
            AccessibilityHelper.openSystemSettings()
        }
        statusBar?.onToggleTextBoxAwareness = { [weak self] enabled in
            guard let self else { return }
            self.settings.textBoxAwarenessEnabled = enabled
            try? self.settingsStore.save(self.settings)
            self.statusBar?.update(textBoxAwarenessEnabled: enabled)
            self.petWindow?.update(settings: self.settings)
        }
        statusBar?.onQuit = { NSApp.terminate(nil) }
        statusBar?.update(destination: settings.minimizeDestination)
        statusBar?.update(snappingEnabled: settings.snappingEnabled)
        statusBar?.update(animal: settings.animalKind, theme: settings.themePreset)
        statusBar?.update(textBoxAwarenessEnabled: settings.textBoxAwarenessEnabled)
        statusBar?.updateAccessibilityStatus()

        // Check & prompt for accessibility if not yet granted
        if !AccessibilityHelper.isTrusted {
            AccessibilityHelper.requestPrompt()
        }

        // Keep a regular application presence so Animal Buddy is available in
        // Force Quit Applications even when its pet window is minimized.
        NSApp.setActivationPolicy(.regular)
        petWindow?.showPet()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        petWindow?.showPet()
        return true
    }

    private func setMinimizeDestination(_ destination: MinimizeDestination) {
        settings.minimizeDestination = destination
        try? settingsStore.save(settings)
        statusBar?.update(destination: destination)
        petWindow?.update(settings: settings)
    }

    private func setSnapping(_ enabled: Bool) {
        settings.snappingEnabled = enabled
        try? settingsStore.save(settings)
        statusBar?.update(snappingEnabled: enabled)
        petWindow?.update(settings: settings)
    }

    private func setAnimalAndTheme(_ animal: AnimalKind, theme: PetThemePreset) {
        settings.animalKind = animal
        settings.themePreset = theme
        if theme == .custom {
            settings.customPalette = animal.defaultPalette(for: .classic)
        }
        try? settingsStore.save(settings)
        statusBar?.update(animal: animal, theme: theme)
        petWindow?.update(settings: settings)
    }

    private func showSettings(initialTab: Int = 0) {
        let controller = MacroSettingsWindowController(settings: settings, initialTab: initialTab)
        controller.onSave = { [weak self] left, right, dragMacros, animal, themePreset, customPalette, textBoxAwareness in
            guard let self else { return }
            self.settings.leftBlushMacro = left
            self.settings.rightBlushMacro = right
            self.settings.dragMacros = dragMacros
            self.settings.animalKind = animal
            self.settings.themePreset = themePreset
            self.settings.customPalette = customPalette
            self.settings.textBoxAwarenessEnabled = textBoxAwareness
            try? self.settingsStore.save(self.settings)
            self.statusBar?.update(animal: animal, theme: themePreset)
            self.statusBar?.update(textBoxAwarenessEnabled: textBoxAwareness)
            self.petWindow?.update(settings: self.settings)
        }
        controller.onThemeChanged = { [weak self] animal, themePreset, customPalette in
            guard let self else { return }
            self.settings.animalKind = animal
            self.settings.themePreset = themePreset
            self.settings.customPalette = customPalette
            try? self.settingsStore.save(self.settings)
            self.statusBar?.update(animal: animal, theme: themePreset)
            self.petWindow?.update(settings: self.settings)
        }
        macroSettingsWindow = controller
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func importThemeFromMenu() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Animal Buddy Theme"
        openPanel.prompt = "Import"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let (animal, _, palette) = try ThemeDocument.decode(from: data)
                self.settings.animalKind = animal
                self.settings.themePreset = .custom
                self.settings.customPalette = palette
                try? self.settingsStore.save(self.settings)
                self.statusBar?.update(animal: animal, theme: .custom)
                self.petWindow?.update(settings: self.settings)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could not import theme"
                alert.informativeText = "Invalid theme JSON: \(error.localizedDescription)"
                alert.runModal()
            }
        }
    }

    private func exportThemeFromMenu() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export \(settings.animalKind.nameWithoutEmoji) Theme"
        savePanel.prompt = "Export"
        savePanel.allowedContentTypes = [UTType.json]
        let defaultFileName = "\(settings.animalKind.rawValue)-\(settings.themePreset == .custom ? "custom" : settings.themePreset.rawValue)-theme.json"
        savePanel.nameFieldStringValue = defaultFileName
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let name = settings.themePreset == .custom ? "Custom \(settings.animalKind.nameWithoutEmoji) Theme" : settings.themePreset.displayName(for: settings.animalKind)
                let doc = ThemeDocument(animal: settings.animalKind, name: name, version: 1, palette: settings.activePalette)
                let data = try doc.exportJSONData()
                try data.write(to: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to export theme"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
