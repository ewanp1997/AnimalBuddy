import AppKit

@MainActor final class StatusBarController: NSObject {
    var onShowPet: (() -> Void)?
    var onMinimizeDestinationChanged: ((MinimizeDestination) -> Void)?
    var onSnappingChanged: ((Bool) -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let destinationMenu = NSMenu(title: "Minimize To")
    private let dockItem = NSMenuItem(title: "Dock", action: #selector(selectDock), keyEquivalent: "")
    private let menubarItem = NSMenuItem(title: "Menu Bar", action: #selector(selectMenubar), keyEquivalent: "")
    private let snappingItem = NSMenuItem(title: "Snap to Screen Edges", action: #selector(toggleSnapping), keyEquivalent: "")

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

        dockItem.target = self
        menubarItem.target = self
        destinationMenu.addItem(dockItem)
        destinationMenu.addItem(menubarItem)
        let destinationItem = NSMenuItem(title: "Minimize To", action: nil, keyEquivalent: "")
        destinationItem.submenu = destinationMenu
        menu.addItem(destinationItem)
        snappingItem.target = self
        menu.addItem(snappingItem)
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

    @objc private func showPet() { onShowPet?() }
    @objc private func selectDock() { onMinimizeDestinationChanged?(.dock) }
    @objc private func selectMenubar() { onMinimizeDestinationChanged?(.menubar) }
    @objc private func toggleSnapping() { onSnappingChanged?(snappingItem.state != .on) }
    @objc private func quit() { onQuit?() }

    private static func logoImage() -> NSImage {
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
