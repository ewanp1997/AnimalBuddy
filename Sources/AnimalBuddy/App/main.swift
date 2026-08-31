
import AppKit
import UniformTypeIdentifiers

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindowController?
    private var settings = AppSettings()
    private let settingsStore = SettingsStore()
    private var statusBar: StatusBarController?
    private var macroSettingsWindow: MacroSettingsWindowController?
    private var welcomeWindow: WelcomeWindowController?
    private var updateWindow: UpdateWindowController?

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
        statusBar?.onHidePet = { [weak self] in self?.petWindow?.minimizePet() }
        statusBar?.onToggleFocusMode = { [weak self] in
            guard let self else { return }
            self.settings.focusModeEnabled.toggle()
            try? self.settingsStore.save(self.settings)
            self.petWindow?.update(settings: self.settings)
            self.updateStatusBar()
        }
        statusBar?.onToggleSoundEffects = { [weak self] in
            guard let self else { return }
            self.settings.soundEffectsEnabled.toggle()
            try? self.settingsStore.save(self.settings)
            self.petWindow?.update(settings: self.settings)
            self.updateStatusBar()
        }
        statusBar?.onOpenSettings = { [weak self] in self?.showSettings(initialTab: 0) }
        statusBar?.onOpenWelcome = { [weak self] in self?.showWelcomeFromMenu() }
        statusBar?.onQuit = { NSApp.terminate(nil) }

        petWindow?.onVisibilityChanged = { [weak self] _ in
            self?.updateStatusBar()
        }
        petWindow?.onOpenSettings = { [weak self] tabIndex in
            self?.showSettings(initialTab: tabIndex)
        }

        // Keep a regular application presence so Animal Buddy is available in
        // Force Quit Applications even when its pet window is minimized.
        NSApp.setActivationPolicy(.regular)
        petWindow?.showPet()
        updateStatusBar()

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "a0.65"
        if let presentation = WelcomePresentationEvaluator.evaluate(settings: settings, currentVersion: currentVersion) {
            showWelcome(presentation: presentation, currentVersion: currentVersion)
        }

        if settings.automaticallyCheckForUpdates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.checkForUpdates(silent: true)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        petWindow?.showPet()
        return true
    }

    private func updateStatusBar() {
        let isVisible = petWindow?.window?.isVisible == true
        statusBar?.update(
            isPetVisible: isVisible,
            isFocusModeEnabled: settings.focusModeEnabled,
            isSoundEffectsEnabled: settings.soundEffectsEnabled
        )
    }

    private func showSettings(initialTab: Int = 0) {
        if let existing = macroSettingsWindow, existing.window?.isVisible == true {
            existing.selectTab(initialTab)
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = MacroSettingsWindowController(settings: settings, initialTab: initialTab)
        controller.onSave = { [weak self] left, right, dragMacros, animal, themePreset, customPalette, hoverTranslucency, googlyEyes, autoUpdates, helpfulTips, destinationFolder, organizeSubfolders, subfolderRules, alwaysOnTop, snapping, minDest, focusMode, focusReminders, focusInterval, soundEffects in
            guard let self else { return }
            self.settings.leftBlushMacro = left
            self.settings.rightBlushMacro = right
            self.settings.dragMacros = dragMacros
            self.settings.animalKind = animal
            self.settings.themePreset = themePreset
            self.settings.customPalette = customPalette
            self.settings.hoverTranslucencyEnabled = hoverTranslucency
            self.settings.googlyEyesEnabled = googlyEyes
            self.settings.automaticallyCheckForUpdates = autoUpdates
            self.settings.helpfulTipsEnabled = helpfulTips
            self.settings.destinationFolderPath = destinationFolder
            self.settings.organizeInboxByFileType = organizeSubfolders
            self.settings.inboxSubfolderRules = subfolderRules
            self.settings.alwaysOnTop = alwaysOnTop
            self.settings.snappingEnabled = snapping
            self.settings.minimizeDestination = minDest
            self.settings.focusModeEnabled = focusMode
            self.settings.focusModeWorkRemindersEnabled = focusReminders
            self.settings.focusModeIntervalMinutes = focusInterval
            self.settings.soundEffectsEnabled = soundEffects
            try? self.settingsStore.save(self.settings)
            self.petWindow?.update(settings: self.settings)
            self.updateStatusBar()
        }
        controller.onThemeChanged = { [weak self] animal, themePreset, customPalette, googlyEyes in
            guard let self else { return }
            self.settings.animalKind = animal
            self.settings.themePreset = themePreset
            self.settings.customPalette = customPalette
            self.settings.googlyEyesEnabled = googlyEyes
            try? self.settingsStore.save(self.settings)
            self.petWindow?.update(settings: self.settings)
        }
        controller.onCheckForUpdates = { [weak self] in
            self?.checkForUpdates(silent: false)
        }
        controller.onShowTipPreview = { [weak self] in
            self?.petWindow?.showTip()
        }
        controller.onShowFocusSoundPreview = { [weak self] in
            self?.petWindow?.showFocusSound()
        }
        macroSettingsWindow = controller
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showWelcome(presentation: WelcomePresentationKind, currentVersion: String) {
        let controller = WelcomeWindowController(presentation: presentation)
        controller.onDismiss = { [weak self] in
            guard let self else { return }
            self.settings.hasCompletedWelcome = true
            self.settings.lastSeenAppVersion = currentVersion
            try? self.settingsStore.save(self.settings)
        }
        welcomeWindow = controller
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showWelcomeFromMenu() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "a0.65"
        let presentation: WelcomePresentationKind
        if let latestRelease = AppChangelog.releases.last {
            presentation = .whatsNew(currentVersion: currentVersion, unseenReleases: [latestRelease])
        } else {
            presentation = .firstLaunch(features: AppChangelog.initialWelcomeFeatures)
        }
        showWelcome(presentation: presentation, currentVersion: currentVersion)
    }

    private func checkForUpdates(silent: Bool) {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "a0.65"
        let skipped = settings.skippedAppVersion

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await UpdateChecker.shared.checkForUpdates(currentVersion: currentVersion, skippedVersion: skipped, ignoreSkipped: !silent)
            self.settings.lastUpdateCheckDate = Date()
            try? self.settingsStore.save(self.settings)

            switch result {
            case .updateAvailable(let release, let current):
                self.showUpdateWindow(release: release, currentVersion: current)
            case .upToDate:
                if !silent {
                    let alert = NSAlert()
                    alert.messageText = "You're Up to Date!"
                    alert.informativeText = "Animal Buddy \(currentVersion) is the latest available release."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            case .skipped:
                if !silent {
                    let alert = NSAlert()
                    alert.messageText = "You're Up to Date"
                    alert.informativeText = "You have skipped the latest version available on GitHub."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            case .error(let message):
                if !silent {
                    let alert = NSAlert()
                    alert.messageText = "Could Not Check for Updates"
                    alert.informativeText = message
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func showUpdateWindow(release: GitHubRelease, currentVersion: String) {
        let controller = UpdateWindowController(release: release, currentVersion: currentVersion)
        controller.onSkipVersion = { [weak self] skippedVersion in
            guard let self else { return }
            self.settings.skippedAppVersion = skippedVersion
            try? self.settingsStore.save(self.settings)
        }
        updateWindow = controller
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
