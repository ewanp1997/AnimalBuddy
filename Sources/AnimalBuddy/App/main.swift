import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsStore().load()
        let registry = ActionRegistry(settings: settings)
        petWindow = PetWindowController(settings: settings, registry: registry)
        petWindow?.showWindow(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
