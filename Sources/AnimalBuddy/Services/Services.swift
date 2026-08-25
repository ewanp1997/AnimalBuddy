import Foundation
import UniformTypeIdentifiers

public enum InputClassifier {
    public static func classify(urls: [URL], text: String? = nil) -> DropInput {
        if let text, let url = URL(string: text), url.scheme != nil { return DropInput(text: text, category: .url) }
        guard let first = urls.first else { return DropInput(text: text, category: .text) }
        let values = urls.compactMap { try? $0.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey]) }
        if values.contains(where: { $0.isDirectory == true }) { return DropInput(urls: urls, category: .directory, contentTypes: values.compactMap(\.contentType)) }
        let types = values.compactMap(\.contentType) + urls.compactMap { UTType(filenameExtension: $0.pathExtension) }
        if types.contains(where: { $0.conforms(to: .image) }) { return DropInput(urls: urls, category: .image, contentTypes: types) }
        _ = first
        return DropInput(urls: urls, category: .file, contentTypes: types)
    }
}

public struct SettingsStore: Sendable {
    public init() {}
    private var url: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AnimalBuddy/settings.json") }
    public func load() -> AppSettings { guard let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }; return decoded }
    public func save(_ settings: AppSettings) throws { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(settings).write(to: url, options: .atomic) }
}
