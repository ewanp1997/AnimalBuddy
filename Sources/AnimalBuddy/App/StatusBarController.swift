import AppKit

@MainActor final class StatusBarController: NSObject {
    var onShowPet: (() -> Void)?
    var onMinimizeDestinationChanged: ((MinimizeDestination) -> Void)?
    var onSnappingChanged: ((Bool) -> Void)?
    var onThemePresetChanged: ((PetThemePreset) -> Void)?
    var onImportThemeJSON: (() -> Void)?
    var onExportThemeJSON: (() -> Void)?
    var onOpenAppearanceSettings: (() -> Void)?
    var onConfigureMacros: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let destinationMenu = NSMenu(title: "Minimize To")
    private let dockItem = NSMenuItem(title: "Dock", action: #selector(selectDock), keyEquivalent: "")
    private let menubarItem = NSMenuItem(title: "Menu Bar", action: #selector(selectMenubar), keyEquivalent: "")
    private let snappingItem = NSMenuItem(title: "Snap to Screen Edges", action: #selector(toggleSnapping), keyEquivalent: "")

    private let themeMenu = NSMenu(title: "Bird Theme")
    private let classicThemeItem = NSMenuItem(title: "🔹 Classic Blue", action: #selector(selectClassicTheme), keyEquivalent: "")
    private let darkThemeItem = NSMenuItem(title: "🌑 Midnight Dark", action: #selector(selectDarkTheme), keyEquivalent: "")
    private let lightThemeItem = NSMenuItem(title: "☀️ Daylight Light", action: #selector(selectLightTheme), keyEquivalent: "")
    private let customThemeItem = NSMenuItem(title: "🎨 Custom Palette", action: #selector(selectCustomTheme), keyEquivalent: "")

    override init() {
        super.init()
        statusItem.button?.image = Self.logoImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Animal Buddy"

        let menu = NSMenu(title: "Animal Buddy")
        let showItem = NSMenuItem(title: "Show Animal Buddy", action: #selector(showPet), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())

        classicThemeItem.target = self
        darkThemeItem.target = self
        lightThemeItem.target = self
        customThemeItem.target = self

        themeMenu.addItem(classicThemeItem)
        themeMenu.addItem(darkThemeItem)
        themeMenu.addItem(lightThemeItem)
        themeMenu.addItem(customThemeItem)
        themeMenu.addItem(.separator())
        let importItem = NSMenuItem(title: "📥 Import Theme JSON…", action: #selector(importTheme), keyEquivalent: "")
        importItem.target = self
        themeMenu.addItem(importItem)
        let exportItem = NSMenuItem(title: "📤 Export Theme JSON…", action: #selector(exportTheme), keyEquivalent: "")
        exportItem.target = self
        themeMenu.addItem(exportItem)
        themeMenu.addItem(.separator())
        let customColorsItem = NSMenuItem(title: "Customize Plumage Colors…", action: #selector(openAppearance), keyEquivalent: "")
        customColorsItem.target = self
        themeMenu.addItem(customColorsItem)

        let themeItem = NSMenuItem(title: "Bird Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        dockItem.target = self
        menubarItem.target = self
        destinationMenu.addItem(dockItem)
        destinationMenu.addItem(menubarItem)
        let destinationItem = NSMenuItem(title: "Minimize To", action: nil, keyEquivalent: "")
        destinationItem.submenu = destinationMenu
        menu.addItem(destinationItem)
        snappingItem.target = self
        menu.addItem(snappingItem)
        let macroItem = NSMenuItem(title: "Configure Macros…", action: #selector(configureMacros), keyEquivalent: "")
        macroItem.target = self
        menu.addItem(macroItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Animal Buddy", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func update(destination: MinimizeDestination) {
        dockItem.state = destination == .dock ? .on : .off
        menubarItem.state = destination == .menubar ? .on : .off
    }

    func update(snappingEnabled: Bool) { snappingItem.state = snappingEnabled ? .on : .off }

    func update(theme: PetThemePreset) {
        classicThemeItem.state = theme == .classic ? .on : .off
        darkThemeItem.state = theme == .dark ? .on : .off
        lightThemeItem.state = theme == .light ? .on : .off
        customThemeItem.state = theme == .custom ? .on : .off
    }

    @objc private func showPet() { onShowPet?() }
    @objc private func selectClassicTheme() { onThemePresetChanged?(.classic) }
    @objc private func selectDarkTheme() { onThemePresetChanged?(.dark) }
    @objc private func selectLightTheme() { onThemePresetChanged?(.light) }
    @objc private func selectCustomTheme() { onThemePresetChanged?(.custom) }
    @objc private func importTheme() { onImportThemeJSON?() }
    @objc private func exportTheme() { onExportThemeJSON?() }
    @objc private func openAppearance() { onOpenAppearanceSettings?() }
    @objc private func selectDock() { onMinimizeDestinationChanged?(.dock) }
    @objc private func selectMenubar() { onMinimizeDestinationChanged?(.menubar) }
    @objc private func toggleSnapping() { onSnappingChanged?(snappingItem.state != .on) }
    @objc private func configureMacros() { onConfigureMacros?() }
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
