import Foundation
import UniformTypeIdentifiers

public enum InputClassifier {
    public static func classify(urls: [URL], text: String? = nil) -> DropInput {
        detect(urls: urls, text: text, modifiers: .none).input
    }

    public static func detect(urls: [URL], text: String? = nil, modifiers: ModifierCombination = .none, sourceApplicationName: String? = nil) -> DropContext {
        if urls.isEmpty {
            if let text, let url = URL(string: text), url.scheme != nil {
                let item = DropItem(kind: .url, displayName: text)
                return DropContext(items: [item], text: text, category: .url, modifiers: modifiers, sourceApplicationName: sourceApplicationName)
            }
            if let text, !text.isEmpty {
                let item = DropItem(kind: .text, displayName: text)
                return DropContext(items: [item], text: text, category: .text, modifiers: modifiers, sourceApplicationName: sourceApplicationName)
            }
            return DropContext(items: [], category: .unknown, modifiers: modifiers, sourceApplicationName: sourceApplicationName)
        }

        let items = urls.map(classifyURL)
        let kinds = Set(items.map(\.kind))
        let category: InputCategory
        if kinds.count > 1 {
            category = .mixed
        } else {
            category = inputCategory(for: items[0].kind)
        }
        let types = items.flatMap(\.contentTypes)
        return DropContext(items: items, text: text, category: category, contentTypes: types, modifiers: modifiers, sourceApplicationName: sourceApplicationName)
    }

    private static func classifyURL(_ url: URL) -> DropItem {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey, .localizedNameKey])
        let resourceType = values?.contentType
        let extensionType = UTType(filenameExtension: url.pathExtension)
        let types = [resourceType, extensionType].compactMap { $0 }
        let kind: DropItemKind
        if url.pathExtension.caseInsensitiveCompare("app") == .orderedSame || types.contains(where: { $0.conforms(to: .application) }) {
            kind = .application
        } else if values?.isDirectory == true {
            kind = .directory
        } else if types.contains(where: { $0.conforms(to: .image) }) {
            kind = .image
        } else {
            kind = .file
        }
        return DropItem(url: url, kind: kind, contentTypes: types, displayName: values?.localizedName ?? url.lastPathComponent)
    }

    private static func inputCategory(for kind: DropItemKind) -> InputCategory {
        switch kind {
        case .application: .application
        case .directory: .directory
        case .image: .image
        case .file: .file
        case .url: .url
        case .text: .text
        case .unknown: .unknown
        }
    }
}

public struct SettingsStore: Sendable {
    public init() {}
    private var url: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AnimalBuddy/settings.json") }
    public func load() -> AppSettings { guard let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }; return decoded }
    public func save(_ settings: AppSettings) throws { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(settings).write(to: url, options: .atomic) }
}
