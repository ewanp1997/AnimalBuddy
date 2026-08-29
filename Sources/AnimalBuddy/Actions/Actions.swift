import AppKit
import Foundation
import UniformTypeIdentifiers

public protocol Action: Sendable {
    var descriptor: ActionDescriptor { get }
    func execute(context: ActionContext) async throws
}

public enum ActionError: LocalizedError {
    case noInput
    case noDestination
    case unsupported
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .noInput:
            return "Nothing was dropped"
        case .noDestination:
            return "Choose a destination folder in settings"
        case .unsupported:
            return "This action does not support that input"
        case .failed(let message):
            return message
        }
    }
}

public enum SafeFileOperations {
    public static func uniqueURL(for source: URL, in folder: URL) -> URL {
        let fileManager = FileManager.default
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = folder.appendingPathComponent(source.lastPathComponent)
        var index = 2
        while fileManager.fileExists(atPath: candidate.path) {
            if ext.isEmpty {
                candidate = folder.appendingPathComponent("\(base) (\(index))")
            } else {
                candidate = folder.appendingPathComponent("\(base) (\(index)).\(ext)")
            }
            index += 1
        }
        return candidate
    }
}

struct StoreAction: Action {
    let descriptor = ActionDescriptor(
        identifier: "store",
        displayName: "Store in folder",
        symbolName: "folder",
        acceptedCategories: [.file, .image, .directory, .application, .mixed, .url, .text]
    )

    func execute(context: ActionContext) async throws {
        guard let baseFolder = context.destinationFolder else {
            throw ActionError.noDestination
        }
        try FileManager.default.createDirectory(at: baseFolder, withIntermediateDirectories: true)

        let organize = context.organizeByFileType
        let rules = context.subfolderRules

        for url in context.input.urls {
            let targetFolder: URL
            if organize {
                let subfolderName = FileTypeOrganizer.subfolderName(for: url, customRules: rules)
                targetFolder = baseFolder.appendingPathComponent(subfolderName, isDirectory: true)
                try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
            } else {
                targetFolder = baseFolder
            }
            let uniqueURL = SafeFileOperations.uniqueURL(for: url, in: targetFolder)
            try FileManager.default.copyItem(at: url, to: uniqueURL)
        }

        if context.input.urls.isEmpty {
            if let text = context.input.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let isURL = (URL(string: trimmed)?.scheme != nil)
                let targetFolder: URL
                if organize {
                    let subfolderName = FileTypeOrganizer.textSubfolderName(text: trimmed, isURL: isURL, customRules: rules)
                    targetFolder = baseFolder.appendingPathComponent(subfolderName, isDirectory: true)
                    try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
                } else {
                    targetFolder = baseFolder
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
                let timestamp = formatter.string(from: Date())

                if isURL {
                    let weblocData = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                    <plist version="1.0">
                    <dict>
                        <key>URL</key>
                        <string>\(trimmed)</string>
                    </dict>
                    </plist>
                    """
                    let filename = "Link \(timestamp).webloc"
                    let fileURL = SafeFileOperations.uniqueURL(for: URL(fileURLWithPath: filename), in: targetFolder)
                    try weblocData.write(to: fileURL, atomically: true, encoding: .utf8)
                } else {
                    let filename = "Note \(timestamp).txt"
                    let fileURL = SafeFileOperations.uniqueURL(for: URL(fileURLWithPath: filename), in: targetFolder)
                    try trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            }
        }
    }
}

struct CopyPathAction: Action {
    let descriptor = ActionDescriptor(
        identifier: "copy-path",
        displayName: "Copy path",
        symbolName: "doc.on.doc",
        acceptedCategories: [.file, .image, .directory, .application, .mixed]
    )

    func execute(context: ActionContext) async throws {
        guard let url = context.input.urls.first else {
            throw ActionError.noInput
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }
}

struct RevealAction: Action {
    let descriptor = ActionDescriptor(
        identifier: "reveal",
        displayName: "Reveal in Finder",
        symbolName: "magnifyingglass",
        acceptedCategories: [.file, .image, .directory, .application, .mixed]
    )

    func execute(context: ActionContext) async throws {
        guard !context.input.urls.isEmpty else {
            throw ActionError.noInput
        }
        NSWorkspace.shared.activateFileViewerSelecting(context.input.urls)
    }
}

struct TrashAction: Action {
    let descriptor = ActionDescriptor(
        identifier: "trash",
        displayName: "Move to Trash",
        symbolName: "trash",
        acceptedCategories: [.file, .image, .directory, .application, .mixed]
    )

    func execute(context: ActionContext) async throws {
        for url in context.input.urls {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
}

struct ConvertImageAction: Action {
    let descriptor = ActionDescriptor(
        identifier: "convert-image",
        displayName: "Convert to PNG",
        symbolName: "photo",
        acceptedCategories: [.image]
    )

    func execute(context: ActionContext) async throws {
        for url in context.input.urls {
            guard let image = NSImage(contentsOf: url),
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .png, properties: [:]) else {
                throw ActionError.failed("Could not read image")
            }
            let outPath = url.deletingPathExtension().appendingPathExtension("png")
            let out = SafeFileOperations.uniqueURL(for: outPath, in: url.deletingLastPathComponent())
            try data.write(to: out)
        }
    }
}

struct CompressImageAction: Action {
    let descriptor = ActionDescriptor(
        identifier: "compress-image",
        displayName: "Optimise image",
        symbolName: "arrow.down.right.and.arrow.up.left",
        acceptedCategories: [.image]
    )

    func execute(context: ActionContext) async throws {
        for url in context.input.urls {
            guard let image = NSImage(contentsOf: url),
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) else {
                throw ActionError.failed("Could not optimise image")
            }
            let outPath = url.deletingPathExtension().appendingPathExtension("jpg")
            let out = SafeFileOperations.uniqueURL(for: outPath, in: url.deletingLastPathComponent())
            try data.write(to: out)
        }
    }
}

struct OpenURLAction: Action {
    let descriptor = ActionDescriptor(
        identifier: "open-url",
        displayName: "Open URL",
        symbolName: "safari",
        acceptedCategories: [.url]
    )

    func execute(context: ActionContext) async throws {
        guard let text = context.input.text, let url = URL(string: text) else {
            throw ActionError.noInput
        }
        NSWorkspace.shared.open(url)
    }
}

public final class ActionRegistry: @unchecked Sendable {
    private var actions: [String: any Action] = [:]
    private let settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
        let builtins: [any Action] = [
            StoreAction(),
            CopyPathAction(),
            RevealAction(),
            TrashAction(),
            ConvertImageAction(),
            CompressImageAction(),
            OpenURLAction()
        ]
        for action in builtins {
            actions[action.descriptor.identifier] = action
        }
    }

    public func action(for input: DropInput, modifiers: ModifierCombination) -> (any Action)? {
        let binding = settings.bindings.first { $0.category == input.category && $0.modifiers == modifiers }
            ?? settings.bindings.first { $0.category == input.category && $0.modifiers == .none }
        guard let binding,
              let action = actions[binding.actionID],
              action.descriptor.accepts(input) else {
            return nil
        }
        return action
    }

    public func eligibleActions(for input: DropInput) -> [ActionDescriptor] {
        actions.values
            .filter { $0.descriptor.accepts(input) }
            .map(\.descriptor)
            .sorted { $0.displayName < $1.displayName }
    }

    public func configuredActions(for input: DropInput, modifiers: ModifierCombination) -> [any Action] {
        let exact = settings.bindings.filter { $0.category == input.category && $0.modifiers == modifiers }
        let configured = settings.bindings.filter { $0.category == input.category }
        let ordered = exact + configured
        var seen = Set<String>()
        return ordered.compactMap { binding in
            guard let action = actions[binding.actionID],
                  action.descriptor.accepts(input),
                  seen.insert(binding.actionID).inserted else {
                return nil
            }
            return action
        }
    }
}
