import AppKit

@MainActor final class DropActionPopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private var selectedAction = false
    private var onSelection: ((any Action) -> Void)?
    private var onCancel: (() -> Void)?

    func show(actions: [any Action], context: DropContext, relativeTo view: NSView, onSelection: @escaping (any Action) -> Void, onCancel: @escaping () -> Void) {
        guard !actions.isEmpty else { return }
        self.onSelection = onSelection
        self.onCancel = onCancel
        selectedAction = false
        let controller = DropActionPopoverViewController(actions: actions, context: context) { [weak self] action in
            guard let self else { return }
            selectedAction = true
            popover.performClose(nil)
            onSelection(action)
        }
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
    }

    func popoverDidClose(_ notification: Notification) {
        guard !selectedAction else { return }
        onCancel?()
        onSelection = nil
        onCancel = nil
    }
}

@MainActor private final class DropActionPopoverViewController: NSViewController {
    private let actions: [any Action]
    private let context: DropContext
    private let onSelection: (any Action) -> Void

    init(actions: [any Action], context: DropContext, onSelection: @escaping (any Action) -> Void) {
        self.actions = actions
        self.context = context
        self.onSelection = onSelection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let title = NSTextField(labelWithString: "Choose an action")
        title.font = .systemFont(ofSize: 14, weight: .bold)
        let summary = NSTextField(wrappingLabelWithString: summaryText)
        summary.textColor = .secondaryLabelColor
        summary.maximumNumberOfLines = 2
        let buttons = NSStackView()
        buttons.orientation = .vertical
        buttons.alignment = .width
        buttons.spacing = 6
        for (index, action) in actions.enumerated() {
            let button = NSButton(title: action.descriptor.displayName, target: self, action: #selector(actionPressed(_:)))
            button.tag = index
            button.image = NSImage(systemSymbolName: action.descriptor.symbolName, accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            button.alignment = .left
            buttons.addArrangedSubview(button)
        }
        let stack = NSStackView(views: [title, summary, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 160))
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.widthAnchor.constraint(equalToConstant: 250)
        ])
        self.view = view
    }

    private var summaryText: String {
        let count = context.items.count
        let noun = count == 1 ? "item" : "items"
        return "\(count) \(noun) detected as \(context.category.rawValue)."
    }

    @objc private func actionPressed(_ sender: NSButton) {
        guard actions.indices.contains(sender.tag) else { return }
        onSelection(actions[sender.tag])
    }
}
