import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindowController?
    private var settings = AppSettings()
    private let settingsStore = SettingsStore()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = settingsStore.load()
        let registry = ActionRegistry(settings: settings)
        petWindow = PetWindowController(settings: settings, registry: registry)
        statusBar = StatusBarController()
        statusBar?.onShowPet = { [weak self] in self?.petWindow?.showPet() }
        statusBar?.onMinimizeDestinationChanged = { [weak self] destination in self?.setMinimizeDestination(destination) }
        statusBar?.onQuit = { NSApp.terminate(nil) }
        statusBar?.update(destination: settings.minimizeDestination)
        // Keep a regular application presence so Animal Buddy is available in
        // Force Quit Applications even when its pet window is minimized.
        NSApp.setActivationPolicy(.regular)
        petWindow?.showPet()
    }

    private func setMinimizeDestination(_ destination: MinimizeDestination) {
        settings.minimizeDestination = destination
        try? settingsStore.save(settings)
        statusBar?.update(destination: destination)
        petWindow?.update(settings: settings)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
