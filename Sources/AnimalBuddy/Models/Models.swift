import Foundation
import UniformTypeIdentifiers

public enum InputCategory: String, Codable, CaseIterable, Sendable {
    case file, image, directory, application, url, text, mixed, unknown
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

public enum DropItemKind: String, Codable, CaseIterable, Sendable {
    case application, directory, image, file, url, text, unknown
}

public struct DropItem: Sendable, Equatable {
    public let url: URL?
    public let kind: DropItemKind
    public let contentTypes: [UTType]
    public let displayName: String?

    public init(url: URL? = nil, kind: DropItemKind, contentTypes: [UTType] = [], displayName: String? = nil) {
        self.url = url
        self.kind = kind
        self.contentTypes = contentTypes
        self.displayName = displayName
    }
}

public enum DragPresentationKind: String, Sendable {
    case cameraAndSDCard, envelopeAndLink, storageBox, document, questionMark
}

public struct DragPresentation: Sendable, Equatable {
    public let prop: DragPresentationKind
    public let actionID: String?
    public let actionTitle: String?

    public init(prop: DragPresentationKind, actionID: String? = nil, actionTitle: String? = nil) {
        self.prop = prop
        self.actionID = actionID
        self.actionTitle = actionTitle
    }
}

public struct DropContext: Sendable, Equatable {
    public let items: [DropItem]
    public let text: String?
    public let category: InputCategory
    public let contentTypes: [UTType]
    public let modifiers: ModifierCombination
    public let sourceApplicationName: String?
    public let presentation: DragPresentation

    public init(items: [DropItem], text: String? = nil, category: InputCategory, contentTypes: [UTType] = [], modifiers: ModifierCombination = .none, sourceApplicationName: String? = nil, presentation: DragPresentation? = nil) {
        self.items = items
        self.text = text
        self.category = category
        self.contentTypes = contentTypes
        self.modifiers = modifiers
        self.sourceApplicationName = sourceApplicationName
        self.presentation = presentation ?? DragPresentation(prop: Self.presentationKind(for: category))
    }

    public var urls: [URL] { items.compactMap(\.url) }
    public var input: DropInput { DropInput(urls: urls, text: text, category: category, contentTypes: contentTypes) }

    public func withPresentation(_ presentation: DragPresentation) -> DropContext {
        DropContext(items: items, text: text, category: category, contentTypes: contentTypes, modifiers: modifiers, sourceApplicationName: sourceApplicationName, presentation: presentation)
    }

    public static func presentationKind(for category: InputCategory) -> DragPresentationKind {
        switch category {
        case .image: .cameraAndSDCard
        case .url: .envelopeAndLink
        case .directory: .storageBox
        case .file, .application: .document
        case .text, .mixed, .unknown: .questionMark
        }
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
    case shell, openApplication, openURL, runShortcut, runBlushMacro
    public var displayName: String {
        switch self { case .shell: "Run Shell Command"; case .openApplication: "Open Application"; case .openURL: "Open URL"; case .runShortcut: "Run Apple Shortcut"; case .runBlushMacro: "Run Another Blush Macro" }
    }
    public var placeholder: String {
        switch self { case .shell: "e.g. say 'Hello from Animal Buddy'"; case .openApplication: "e.g. Calendar"; case .openURL: "e.g. https://example.com"; case .runShortcut: "Choose a Shortcut"; case .runBlushMacro: "Choose another macro" }
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
    public var isConfigured: Bool { !effectiveSteps.isEmpty }
    private enum CodingKeys: String, CodingKey { case name, command, steps }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        command = try values.decodeIfPresent(String.self, forKey: .command) ?? ""
        steps = try values.decodeIfPresent([MacroStep].self, forKey: .steps) ?? []
    }
}

public struct DragMacroBinding: Codable, Sendable, Equatable {
    public var category: InputCategory
    public var macro: UserMacro

    public init(category: InputCategory, macro: UserMacro = UserMacro()) {
        self.category = category
        self.macro = macro
    }
}

public struct MacroPreset: Sendable, Equatable {
    public let title: String
    public let macro: UserMacro

    public init(title: String, name: String, steps: [MacroStep]) {
        self.title = title
        self.macro = UserMacro(name: name, steps: steps)
    }
}

public enum MacroPresets {
    public static let leftBlush: [MacroPreset] = [
        MacroPreset(
            title: "Friendly Greeting",
            name: "Morning Greeting",
            steps: [MacroStep(kind: .shell, value: "say 'Hello! Hope you are having a wonderful day!'")]
        ),
        MacroPreset(
            title: "Open Calendar",
            name: "Open Calendar",
            steps: [MacroStep(kind: .openApplication, value: "Calendar")]
        ),
        MacroPreset(
            title: "Mute & Sleep Screen",
            name: "Step Away",
            steps: [MacroStep(kind: .shell, value: "osascript -e 'set volume output muted true' && pmset displaysleepnow")]
        ),
        MacroPreset(
            title: "Take Screenshot",
            name: "Capture Screen",
            steps: [MacroStep(kind: .shell, value: "screencapture -i ~/Desktop/Screenshot-$(date +%s).png")]
        )
    ]

    public static let rightBlush: [MacroPreset] = [
        MacroPreset(
            title: "Quick Scratchpad",
            name: "Quick Scratchpad",
            steps: [MacroStep(kind: .shell, value: "open -a TextEdit")]
        ),
        MacroPreset(
            title: "Open Music",
            name: "Open Music",
            steps: [MacroStep(kind: .openApplication, value: "Music")]
        ),
        MacroPreset(
            title: "Lock Display",
            name: "Lock Display",
            steps: [MacroStep(kind: .shell, value: "pmset displaysleepnow")]
        ),
        MacroPreset(
            title: "Empty Trash",
            name: "Empty Trash",
            steps: [MacroStep(kind: .shell, value: "osascript -e 'tell application \"Finder\" to empty trash'")]
        )
    ]

    public static func presets(for category: InputCategory) -> [MacroPreset] {
        switch category {
        case .image:
            return [
                MacroPreset(
                    title: "Set as Desktop Wallpaper",
                    name: "Set Wallpaper",
                    steps: [MacroStep(kind: .shell, value: "osascript -e 'tell application \"Finder\" to set desktop picture to POSIX file \"{{path}}\"'")]
                ),
                MacroPreset(
                    title: "Convert to PNG",
                    name: "Convert to PNG",
                    steps: [MacroStep(kind: .shell, value: "sips -s format png \"{{path}}\" --out \"${{path}%.*}.png\"")]
                ),
                MacroPreset(
                    title: "Convert to WebP",
                    name: "Convert to WebP",
                    steps: [MacroStep(kind: .shell, value: "sips -s format webp \"{{path}}\" --out \"${{path}%.*}.webp\"")]
                ),
                MacroPreset(
                    title: "Open in Preview",
                    name: "Open in Preview",
                    steps: [MacroStep(kind: .openApplication, value: "Preview")]
                )
            ]
        case .directory:
            return [
                MacroPreset(
                    title: "Create Zip Archive",
                    name: "Compress Folder",
                    steps: [MacroStep(kind: .shell, value: "ditto -c -k --sequesterRsrc --keepParent \"{{path}}\" \"{{path}}.zip\"")]
                ),
                MacroPreset(
                    title: "Open in Terminal",
                    name: "Open in Terminal",
                    steps: [MacroStep(kind: .shell, value: "open -a Terminal \"{{path}}\"")]
                ),
                MacroPreset(
                    title: "Open in Visual Studio Code",
                    name: "Open in VS Code",
                    steps: [MacroStep(kind: .shell, value: "open -a \"Visual Studio Code\" \"{{path}}\"")]
                ),
                MacroPreset(
                    title: "Clean .DS_Store Files",
                    name: "Clean .DS_Store",
                    steps: [MacroStep(kind: .shell, value: "find \"{{path}}\" -name \".DS_Store\" -delete")]
                )
            ]
        case .application:
            return [
                MacroPreset(
                    title: "Restart Application",
                    name: "Restart App",
                    steps: [MacroStep(kind: .shell, value: "killall \"$(basename \"{{path}}\" .app)\" 2>/dev/null; open \"{{path}}\"")]
                ),
                MacroPreset(
                    title: "Reveal App in Finder",
                    name: "Reveal in Finder",
                    steps: [MacroStep(kind: .shell, value: "open -R \"{{path}}\"")]
                ),
                MacroPreset(
                    title: "Show App Version Notification",
                    name: "Show App Version",
                    steps: [MacroStep(kind: .shell, value: "VER=$(/usr/libexec/PlistBuddy -c \"Print :CFBundleShortVersionString\" \"{{path}}/Contents/Info.plist\" 2>/dev/null); osascript -e \"display notification \\\"Version: $VER\\\" with title \\\"$(basename \"{{path}}\")\\\"\"")]
                )
            ]
        case .file:
            return [
                MacroPreset(
                    title: "Reveal in Finder",
                    name: "Reveal in Finder",
                    steps: [MacroStep(kind: .shell, value: "open -R \"{{path}}\"")]
                ),
                MacroPreset(
                    title: "Copy File Path to Clipboard",
                    name: "Copy File Path",
                    steps: [MacroStep(kind: .shell, value: "echo -n \"{{path}}\" | pbcopy")]
                ),
                MacroPreset(
                    title: "Copy SHA-256 Checksum",
                    name: "Copy SHA-256",
                    steps: [MacroStep(kind: .shell, value: "shasum -a 256 \"{{path}}\" | awk '{print $1}' | tr -d '\\n' | pbcopy")]
                ),
                MacroPreset(
                    title: "Quick Look Preview",
                    name: "Quick Look Preview",
                    steps: [MacroStep(kind: .shell, value: "qlmanage -p \"{{path}}\" >/dev/null 2>&1")]
                )
            ]
        case .url:
            return [
                MacroPreset(
                    title: "Open in Default Browser",
                    name: "Open Link",
                    steps: [MacroStep(kind: .openURL, value: "{{text}}")]
                ),
                MacroPreset(
                    title: "Search Web with Google",
                    name: "Search Google",
                    steps: [MacroStep(kind: .openURL, value: "https://www.google.com/search?q={{text}}")]
                ),
                MacroPreset(
                    title: "Download to ~/Downloads via curl",
                    name: "Download File",
                    steps: [MacroStep(kind: .shell, value: "cd ~/Downloads && curl -O \"{{text}}\"")]
                )
            ]
        case .text:
            return [
                MacroPreset(
                    title: "Read Aloud with Voice",
                    name: "Speak Text",
                    steps: [MacroStep(kind: .shell, value: "say \"{{text}}\"")]
                ),
                MacroPreset(
                    title: "Append to Desktop Notes",
                    name: "Add to Notes",
                    steps: [MacroStep(kind: .shell, value: "echo \"- {{text}}\" >> ~/Desktop/Notes.txt")]
                ),
                MacroPreset(
                    title: "Search Google",
                    name: "Google Search",
                    steps: [MacroStep(kind: .openURL, value: "https://www.google.com/search?q={{text}}")]
                ),
                MacroPreset(
                    title: "Copy Uppercase Text",
                    name: "Copy Uppercase",
                    steps: [MacroStep(kind: .shell, value: "echo \"{{text}}\" | tr '[:lower:]' '[:upper:]' | pbcopy")]
                )
            ]
        case .mixed:
            return [
                MacroPreset(
                    title: "Bundle Items into New Folder",
                    name: "Bundle into Folder",
                    steps: [MacroStep(kind: .shell, value: "DIR=~/Desktop/\"Drop-$(date +%s)\"; mkdir -p \"$DIR\"; echo \"{{paths}}\" | while read -r p; do cp -r \"$p\" \"$DIR/\"; done; open \"$DIR\"")]
                ),
                MacroPreset(
                    title: "Zip All Items into Archive",
                    name: "Zip All Items",
                    steps: [MacroStep(kind: .shell, value: "DIR=~/Desktop/\"Drop-$(date +%s)\"; mkdir -p \"$DIR\"; echo \"{{paths}}\" | while read -r p; do cp -r \"$p\" \"$DIR/\"; done; ditto -c -k \"$DIR\" \"$DIR.zip\"; rm -rf \"$DIR\"; open -R \"$DIR.zip\"")]
                )
            ]
        case .unknown:
            return [
                MacroPreset(
                    title: "Identify File Type",
                    name: "Identify File Type",
                    steps: [MacroStep(kind: .shell, value: "INFO=$(file -b \"{{path}}\"); osascript -e \"display notification \\\"$INFO\\\" with title \\\"File Info\\\"\"")]
                ),
                MacroPreset(
                    title: "Open in TextEdit",
                    name: "Open in TextEdit",
                    steps: [MacroStep(kind: .openApplication, value: "TextEdit")]
                )
            ]
        }
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
    public var dragMacros: [DragMacroBinding] = []
    public var destinationFolderPath: String? = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("Animal Buddy Inbox", isDirectory: true).path
    public var minimizeDestination: MinimizeDestination = .menubar
    public var bindings: [ModifierBinding] = [
        .init(category: .file, modifiers: .none, actionID: "store"),
        .init(category: .image, modifiers: .none, actionID: "store"),
        .init(category: .image, modifiers: .option, actionID: "convert-image"),
        .init(category: .image, modifiers: .command, actionID: "compress-image"),
        .init(category: .file, modifiers: .shift, actionID: "reveal")
    ]

    private enum CodingKeys: String, CodingKey { case alwaysOnTop, petScale, snappingEnabled, leftBlushMacro, rightBlushMacro, dragMacros, destinationFolderPath, minimizeDestination, bindings }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        alwaysOnTop = try values.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? true
        petScale = try values.decodeIfPresent(Double.self, forKey: .petScale) ?? 1.0
        snappingEnabled = try values.decodeIfPresent(Bool.self, forKey: .snappingEnabled) ?? false
        leftBlushMacro = try values.decodeIfPresent(UserMacro.self, forKey: .leftBlushMacro) ?? UserMacro()
        rightBlushMacro = try values.decodeIfPresent(UserMacro.self, forKey: .rightBlushMacro) ?? UserMacro()
        dragMacros = try values.decodeIfPresent([DragMacroBinding].self, forKey: .dragMacros) ?? []
        destinationFolderPath = try values.decodeIfPresent(String.self, forKey: .destinationFolderPath) ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("Animal Buddy Inbox", isDirectory: true).path
        minimizeDestination = try values.decodeIfPresent(MinimizeDestination.self, forKey: .minimizeDestination) ?? .menubar
        bindings = try values.decodeIfPresent([ModifierBinding].self, forKey: .bindings) ?? []
    }
}
