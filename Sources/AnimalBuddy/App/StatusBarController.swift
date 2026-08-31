import AppKit

@MainActor final class StatusBarController: NSObject {
    var onShowPet: (() -> Void)?
    var onHidePet: (() -> Void)?
    var onToggleFocusMode: (() -> Void)?
    var onToggleSoundEffects: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenWelcome: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let togglePetItem = NSMenuItem(title: "Show Animal Buddy", action: #selector(togglePet), keyEquivalent: "")
    private let focusModeItem = NSMenuItem(title: "🎯 Focus Mode", action: #selector(toggleFocusMode), keyEquivalent: "")
    private let soundEffectsItem = NSMenuItem(title: "🔊 Sound Effects", action: #selector(toggleSoundEffects), keyEquivalent: "")

    override init() {
        super.init()
        statusItem.button?.image = Self.logoImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Animal Buddy"

        let menu = NSMenu(title: "Animal Buddy")

        togglePetItem.target = self
        menu.addItem(togglePetItem)
        menu.addItem(.separator())

        focusModeItem.target = self
        menu.addItem(focusModeItem)

        soundEffectsItem.target = self
        menu.addItem(soundEffectsItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let welcomeItem = NSMenuItem(title: "Welcome & What's New…", action: #selector(openWelcome), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Animal Buddy", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func update(isPetVisible: Bool, isFocusModeEnabled: Bool = false, isSoundEffectsEnabled: Bool = true) {
        togglePetItem.title = isPetVisible ? "Hide Animal Buddy" : "Show Animal Buddy"
        focusModeItem.state = isFocusModeEnabled ? .on : .off
        soundEffectsItem.state = isSoundEffectsEnabled ? .on : .off
        soundEffectsItem.title = isSoundEffectsEnabled ? "🔊 Sound Effects" : "🔇 Sound Effects (Muted)"
    }

    @objc private func togglePet() {
        if togglePetItem.title == "Hide Animal Buddy" {
            onHidePet?()
        } else {
            onShowPet?()
        }
    }

    @objc private func toggleFocusMode() {
        onToggleFocusMode?()
    }

    @objc private func toggleSoundEffects() {
        onToggleSoundEffects?()
    }

    @objc private func openSettings() { onOpenSettings?() }
    @objc private func openWelcome() { onOpenWelcome?() }
    @objc private func quit() { onQuit?() }

    private static func logoImage() -> NSImage {
        if let url = Bundle.main.url(forResource: "AnimalBuddyIcon", withExtension: "png"), let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 16, height: 16), xRadius: 5, yRadius: 5).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 4, y: 10, width: 4, height: 5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 10, y: 10, width: 4, height: 5)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5, y: 11, width: 2, height: 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: 11, y: 11, width: 2, height: 2)).fill()
        image.unlockFocus()
        return image
    }
}
