import Foundation
import UniformTypeIdentifiers

public enum InputCategory: String, Codable, CaseIterable, Sendable {
    case file, image, directory, url, text
}

public struct DropInput: Sendable {
    public let urls: [URL]
    public let text: String?
    public let category: InputCategory
    public let contentTypes: [UTType]

    public init(urls: [URL] = [], text: String? = nil, category: InputCategory, contentTypes: [UTType] = []) {
        self.urls = urls; self.text = text; self.category = category; self.contentTypes = contentTypes
    }
}

public struct ModifierCombination: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let option = Self(rawValue: 1 << 0)
    public static let command = Self(rawValue: 1 << 1)
    public static let shift = Self(rawValue: 1 << 2)
    public static let control = Self(rawValue: 1 << 3)
    public static let none: Self = []
    public var label: String {
        if isEmpty { return "Drop" }
        return [(contains(.option) ? "Option" : nil), (contains(.command) ? "Command" : nil),
                (contains(.shift) ? "Shift" : nil), (contains(.control) ? "Control" : nil)].compactMap { $0 }.joined(separator: " + ")
    }
}

public enum PetState: String, Sendable { case idle, sleeping, noticingDrag, dragAccepted, dragRejected, waitingForDrop, processing, success, failure }

public enum MinimizeDestination: String, Codable, CaseIterable, Sendable {
    case dock
    case menubar

    public var displayName: String {
        switch self { case .dock: "Dock"; case .menubar: "Menu Bar" }
    }
}

public enum BlushSlot: String, Codable, Sendable { case left, right }

public enum MacroStepKind: String, Codable, CaseIterable, Sendable {
    case shell, openApplication, openURL, runShortcut
    public var displayName: String {
        switch self { case .shell: "Run Shell Command"; case .openApplication: "Open Application"; case .openURL: "Open URL"; case .runShortcut: "Run Apple Shortcut" }
    }
    public var placeholder: String {
        switch self { case .shell: "e.g. say 'Hello from Animal Buddy'"; case .openApplication: "e.g. Calendar"; case .openURL: "e.g. https://example.com"; case .runShortcut: "e.g. My Shortcut" }
    }
}

public struct MacroStep: Codable, Sendable, Equatable {
    public var kind: MacroStepKind
    public var value: String
    public init(kind: MacroStepKind, value: String = "") { self.kind = kind; self.value = value }
}

public struct UserMacro: Codable, Sendable, Equatable {
    public var name: String
    public var command: String
    public var steps: [MacroStep]
    public init(name: String = "", command: String = "", steps: [MacroStep] = []) { self.name = name; self.command = command; self.steps = steps }
    public var effectiveSteps: [MacroStep] { steps.isEmpty && !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [MacroStep(kind: .shell, value: command)] : steps }
    public var isConfigured: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !effectiveSteps.isEmpty }
    private enum CodingKeys: String, CodingKey { case name, command, steps }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        command = try values.decodeIfPresent(String.self, forKey: .command) ?? ""
        steps = try values.decodeIfPresent([MacroStep].self, forKey: .steps) ?? []
    }
}

public struct ActionContext: Sendable {
    public let input: DropInput
    public let destinationFolder: URL?
    public init(input: DropInput, destinationFolder: URL? = nil) { self.input = input; self.destinationFolder = destinationFolder }
}

public struct ActionDescriptor: Sendable {
    public let identifier: String
    public let displayName: String
    public let symbolName: String
    public let acceptedCategories: Set<InputCategory>
    public init(identifier: String, displayName: String, symbolName: String, acceptedCategories: Set<InputCategory>) {
        self.identifier = identifier; self.displayName = displayName; self.symbolName = symbolName; self.acceptedCategories = acceptedCategories
    }
    public func accepts(_ input: DropInput) -> Bool { acceptedCategories.contains(input.category) }
}

public struct ModifierBinding: Codable, Hashable, Sendable {
    public let category: InputCategory
    public let modifierRawValue: Int
    public let actionID: String
    public init(category: InputCategory, modifiers: ModifierCombination, actionID: String) {
        self.category = category; self.modifierRawValue = modifiers.rawValue; self.actionID = actionID
    }
    public var modifiers: ModifierCombination { ModifierCombination(rawValue: modifierRawValue) }
}

public struct AppSettings: Codable, Sendable {
    public var alwaysOnTop = true
    public var petScale = 1.0
    public var snappingEnabled = false
    public var leftBlushMacro = UserMacro()
    public var rightBlushMacro = UserMacro()
    public var destinationFolderPath: String? = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("Animal Buddy Inbox", isDirectory: true).path
    public var minimizeDestination: MinimizeDestination = .menubar
    public var bindings: [ModifierBinding] = [
        .init(category: .file, modifiers: .none, actionID: "store"),
        .init(category: .image, modifiers: .none, actionID: "store"),
        .init(category: .image, modifiers: .option, actionID: "convert-image"),
        .init(category: .image, modifiers: .command, actionID: "compress-image"),
        .init(category: .file, modifiers: .shift, actionID: "reveal")
    ]

    private enum CodingKeys: String, CodingKey { case alwaysOnTop, petScale, snappingEnabled, leftBlushMacro, rightBlushMacro, destinationFolderPath, minimizeDestination, bindings }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        alwaysOnTop = try values.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? true
        petScale = try values.decodeIfPresent(Double.self, forKey: .petScale) ?? 1.0
        snappingEnabled = try values.decodeIfPresent(Bool.self, forKey: .snappingEnabled) ?? false
        leftBlushMacro = try values.decodeIfPresent(UserMacro.self, forKey: .leftBlushMacro) ?? UserMacro()
        rightBlushMacro = try values.decodeIfPresent(UserMacro.self, forKey: .rightBlushMacro) ?? UserMacro()
        destinationFolderPath = try values.decodeIfPresent(String.self, forKey: .destinationFolderPath) ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("Animal Buddy Inbox", isDirectory: true).path
        minimizeDestination = try values.decodeIfPresent(MinimizeDestination.self, forKey: .minimizeDestination) ?? .menubar
        bindings = try values.decodeIfPresent([ModifierBinding].self, forKey: .bindings) ?? []
    }
}
