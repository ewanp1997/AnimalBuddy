import AppKit

@MainActor final class StatusBarController: NSObject {
    var onShowPet: (() -> Void)?
    var onMinimizeDestinationChanged: ((MinimizeDestination) -> Void)?
    var onSnappingChanged: ((Bool) -> Void)?
    var onAnimalAndThemeChanged: ((AnimalKind, PetThemePreset) -> Void)?
    var onImportThemeJSON: (() -> Void)?
    var onExportThemeJSON: (() -> Void)?
    var onOpenAppearanceSettings: (() -> Void)?
    var onConfigureMacros: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let destinationMenu = NSMenu(title: "Minimize To")
    private let dockItem = NSMenuItem(title: "Dock", action: #selector(selectDock), keyEquivalent: "")
    private let menubarItem = NSMenuItem(title: "Menu Bar", action: #selector(selectMenubar), keyEquivalent: "")
    private let snappingItem = NSMenuItem(title: "Snap to Screen Edges", action: #selector(toggleSnapping), keyEquivalent: "")

    private let animalMenu = NSMenu(title: "Animal Selector")
    private var animalSubmenuItems: [AnimalKind: [PetThemePreset: NSMenuItem]] = [:]

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

        // Build Animal Selector submenus for each animal
        for animal in AnimalKind.allCases {
            let animalSubmenu = NSMenu(title: animal.displayName)
            var presetMap: [PetThemePreset: NSMenuItem] = [:]

            for preset in animal.themePresets {
                let itemTitle = preset.displayName(for: animal)
                let item = NSMenuItem(title: itemTitle, action: #selector(themePresetSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = (animal, preset)
                animalSubmenu.addItem(item)
                presetMap[preset] = item
            }

            animalSubmenuItems[animal] = presetMap

            let animalItem = NSMenuItem(title: animal.displayName, action: nil, keyEquivalent: "")
            animalItem.submenu = animalSubmenu
            animalMenu.addItem(animalItem)
        }

        animalMenu.addItem(.separator())
        let importItem = NSMenuItem(title: "📥 Import Theme JSON…", action: #selector(importTheme), keyEquivalent: "")
        importItem.target = self
        animalMenu.addItem(importItem)
        let exportItem = NSMenuItem(title: "📤 Export Theme JSON…", action: #selector(exportTheme), keyEquivalent: "")
        exportItem.target = self
        animalMenu.addItem(exportItem)
        animalMenu.addItem(.separator())
        let customColorsItem = NSMenuItem(title: "Customize Plumage & Appearance…", action: #selector(openAppearance), keyEquivalent: "")
        customColorsItem.target = self
        animalMenu.addItem(customColorsItem)

        let animalSelectorRootItem = NSMenuItem(title: "Animal Selector", action: nil, keyEquivalent: "")
        animalSelectorRootItem.submenu = animalMenu
        menu.addItem(animalSelectorRootItem)

        dockItem.target = self
        menubarItem.target = self
        destinationMenu.addItem(dockItem)
        destinationMenu.addItem(menubarItem)
        let destinationItem = NSMenuItem(title: "Minimize To", action: nil, keyEquivalent: "")
        destinationItem.submenu = destinationMenu
        menu.addItem(destinationItem)
        snappingItem.target = self
        menu.addItem(snappingItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Animal Buddy", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func update(destination: MinimizeDestination) {
        dockItem.state = destination == .dock ? .on : .off
        menubarItem.state = destination == .menubar ? .on : .off
    }

    func update(snappingEnabled: Bool) { snappingItem.state = snappingEnabled ? .on : .off }

    func update(animal: AnimalKind, theme: PetThemePreset) {
        for (aKind, presetDict) in animalSubmenuItems {
            for (preset, menuItem) in presetDict {
                menuItem.state = (aKind == animal && preset == theme) ? .on : .off
            }
        }
    }

    @objc private func themePresetSelected(_ sender: NSMenuItem) {
        guard let (animal, preset) = sender.representedObject as? (AnimalKind, PetThemePreset) else { return }
        onAnimalAndThemeChanged?(animal, preset)
    }

    @objc private func showPet() { onShowPet?() }
    @objc private func importTheme() { onImportThemeJSON?() }
    @objc private func exportTheme() { onExportThemeJSON?() }
    @objc private func openAppearance() { onOpenAppearanceSettings?() }
    @objc private func selectDock() { onMinimizeDestinationChanged?(.dock) }
    @objc private func selectMenubar() { onMinimizeDestinationChanged?(.menubar) }
    @objc private func toggleSnapping() { onSnappingChanged?(snappingItem.state != .on) }
    @objc private func openSettings() { (onOpenSettings ?? onConfigureMacros)?() }
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
