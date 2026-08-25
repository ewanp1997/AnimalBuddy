import AppKit
import UniformTypeIdentifiers

final class PetWindowController: NSWindowController, NSDraggingDestination {
    private let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
    private let registry: ActionRegistry
    private let settings: AppSettings
    init(settings: AppSettings, registry: ActionRegistry) {
        self.settings = settings; self.registry = registry
        let window = NSPanel(contentRect: NSRect(x: 120, y: 120, width: 150, height: 150), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true; window.level = settings.alwaysOnTop ? .floating : .normal; window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; window.isMovableByWindowBackground = true
        super.init(window: window); window.contentView = petView; window.isMovableByWindowBackground = true
        window.registerForDraggedTypes([.fileURL, .URL, .string])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func windowDidLoad() { super.windowDidLoad(); petView.setAccessibilityLabel("Animal Buddy desktop pet"); petView.setAccessibilityRole(.image) }
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { petView.state = .noticingDrag; return .copy }
    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { petView.state = .waitingForDrop; return .copy }
    func draggingExited(_ sender: NSDraggingInfo?) { petView.state = .idle }
    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        let text = pasteboard.string(forType: .string)
        let input = InputClassifier.classify(urls: urls, text: urls.isEmpty ? text : nil)
        let flags = sender.draggingSourceOperationMask // preserve destination feedback; modifier flags read at drop
        _ = flags
        let modifiers = ModifierCombination(rawValue: currentModifierFlags())
        guard let action = registry.action(for: input, modifiers: modifiers) else { petView.state = .dragRejected; return false }
        petView.state = .processing
        let destination = settings.destinationFolderPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        Task { do { try await action.execute(context: ActionContext(input: input, destinationFolder: destination)); await MainActor.run { self.petView.state = .success; self.resetSoon() } } catch { await MainActor.run { self.petView.state = .failure; self.resetSoon() } } }
        return true
    }
    private func currentModifierFlags() -> Int { let flags = NSEvent.modifierFlags; var value = 0; if flags.contains(.option) { value |= ModifierCombination.option.rawValue }; if flags.contains(.command) { value |= ModifierCombination.command.rawValue }; if flags.contains(.shift) { value |= ModifierCombination.shift.rawValue }; if flags.contains(.control) { value |= ModifierCombination.control.rawValue }; return value }
    private func resetSoon() { DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self.petView.state = .idle } }
}
