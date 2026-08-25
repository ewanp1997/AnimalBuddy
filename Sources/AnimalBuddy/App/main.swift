import AppKit

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
        statusBar?.onConfigureMacros = { [weak self] in self?.showMacroSettings() }
        statusBar?.onQuit = { NSApp.terminate(nil) }
        statusBar?.update(destination: settings.minimizeDestination)
        statusBar?.update(snappingEnabled: settings.snappingEnabled)
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

    private func showMacroSettings() {
        let controller = MacroSettingsWindowController(settings: settings)
        controller.onSave = { [weak self] left, right in
            guard let self else { return }
            self.settings.leftBlushMacro = left
            self.settings.rightBlushMacro = right
            try? self.settingsStore.save(self.settings)
            self.petWindow?.update(settings: self.settings)
        }
        macroSettingsWindow = controller
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
