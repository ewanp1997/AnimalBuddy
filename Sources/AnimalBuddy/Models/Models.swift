import Foundation
import UniformTypeIdentifiers
import AppKit

public struct CodableColor: Codable, Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.red = Double(converted.redComponent)
        self.green = Double(converted.greenComponent)
        self.blue = Double(converted.blueComponent)
        self.alpha = Double(converted.alphaComponent)
    }

    public init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        guard let hexValue = UInt64(cleanHex, radix: 16) else { return nil }
        if cleanHex.count == 6 {
            self.red = Double((hexValue >> 16) & 0xFF) / 255.0
            self.green = Double((hexValue >> 8) & 0xFF) / 255.0
            self.blue = Double(hexValue & 0xFF) / 255.0
            self.alpha = 1.0
        } else if cleanHex.count == 8 {
            self.red = Double((hexValue >> 24) & 0xFF) / 255.0
            self.green = Double((hexValue >> 16) & 0xFF) / 255.0
            self.blue = Double((hexValue >> 8) & 0xFF) / 255.0
            self.alpha = Double(hexValue & 0xFF) / 255.0
        } else {
            return nil
        }
    }

    public var hexString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        if alpha < 0.999 {
            let a = Int(round(alpha * 255))
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    public init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(), let hexStr = try? singleValue.decode(String.self), let parsed = CodableColor(hex: hexStr) {
            self = parsed
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.red = try container.decode(Double.self, forKey: .red)
        self.green = try container.decode(Double.self, forKey: .green)
        self.blue = try container.decode(Double.self, forKey: .blue)
        self.alpha = try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1.0
    }

    private enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
}

public struct PetThemePalette: Codable, Sendable, Equatable {
    public var bodyColor: CodableColor
    public var bellyColor: CodableColor
    public var beakColor: CodableColor
    public var blushColor: CodableColor
    public var eyeHighlightColor: CodableColor

    public init(bodyColor: CodableColor, bellyColor: CodableColor, beakColor: CodableColor, blushColor: CodableColor, eyeHighlightColor: CodableColor) {
        self.bodyColor = bodyColor
        self.bellyColor = bellyColor
        self.beakColor = beakColor
        self.blushColor = blushColor
        self.eyeHighlightColor = eyeHighlightColor
    }
}

public enum AnimalKind: String, Codable, CaseIterable, Sendable {
    case bird = "bird"
    case dog = "dog"
    case cat = "cat"
    case monkey = "monkey"
    case giraffe = "giraffe"
    case slinky = "slinky"

    public var displayName: String {
        switch self {
        case .bird: "🐦 Tippo the Bird"
        case .dog: "🐶 Dog"
        case .cat: "🐱 Cat"
        case .monkey: "🐵 Monkey"
        case .giraffe: "🦒 Giraffe"
        case .slinky: "🌀 Slinky"
        }
    }

    public var nameWithoutEmoji: String {
        switch self {
        case .bird: "Tippo the Bird"
        case .dog: "Dog"
        case .cat: "Cat"
        case .monkey: "Monkey"
        case .giraffe: "Giraffe"
        case .slinky: "Slinky"
        }
    }

    public var emoji: String {
        switch self {
        case .bird: "🐦"
        case .dog: "🐶"
        case .cat: "🐱"
        case .monkey: "🐵"
        case .giraffe: "🦒"
        case .slinky: "🌀"
        }
    }

    public var themePresets: [PetThemePreset] {
        self == .slinky ? [.classic, .dark, .light, .custom, .rainbow] : [.classic, .dark, .light, .custom]
    }

    public func defaultPalette(for preset: PetThemePreset) -> PetThemePalette {
        switch self {
        case .bird:
            switch preset {
            case .classic:
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#4F91ED")!,
                    bellyColor: CodableColor(hex: "#FAF7ED")!,
                    beakColor: CodableColor(hex: "#FFAE29")!,
                    blushColor: CodableColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 0.58),
                    eyeHighlightColor: CodableColor(hex: "#0A80E6")!
                )
            case .dark:
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#1E2538")!,
                    bellyColor: CodableColor(hex: "#D8DEE9")!,
                    beakColor: CodableColor(hex: "#F59E0B")!,
                    blushColor: CodableColor(red: 0.65, green: 0.55, blue: 0.98, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#38BDF8")!
                )
            case .light:
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#E0F2FE")!,
                    bellyColor: CodableColor(hex: "#FFFFFF")!,
                    beakColor: CodableColor(hex: "#FBBF24")!,
                    blushColor: CodableColor(red: 0.99, green: 0.64, blue: 0.69, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#38BDF8")!
                )
            case .custom:
                return defaultPalette(for: .classic)
            case .rainbow:
                return defaultPalette(for: .classic)
            }

        case .dog:
            switch preset {
            case .classic: // Golden Retriever Puppy
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#E5A65D")!,
                    bellyColor: CodableColor(hex: "#FFF3E0")!,
                    beakColor: CodableColor(hex: "#8D5B4C")!,
                    blushColor: CodableColor(red: 1.0, green: 0.42, blue: 0.55, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#5D4037")!
                )
            case .dark: // Chocolate / Espresso Pup
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#4E342E")!,
                    bellyColor: CodableColor(hex: "#BCAAA4")!,
                    beakColor: CodableColor(hex: "#1F1209")!,
                    blushColor: CodableColor(red: 1.0, green: 0.44, blue: 0.35, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#FFB300")!
                )
            case .light: // Samoyed Snow Puppy
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#F8FAFC")!,
                    bellyColor: CodableColor(hex: "#FFFFFF")!,
                    beakColor: CodableColor(hex: "#334155")!,
                    blushColor: CodableColor(red: 1.0, green: 0.50, blue: 0.67, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#0288D1")!
                )
            case .custom:
                return defaultPalette(for: .classic)
            case .rainbow:
                return defaultPalette(for: .classic)
            }

        case .cat:
            switch preset {
            case .classic: // Ginger Tabby
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#F97316")!,
                    bellyColor: CodableColor(hex: "#FEF3C7")!,
                    beakColor: CodableColor(hex: "#FB7185")!,
                    blushColor: CodableColor(red: 0.96, green: 0.25, blue: 0.37, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#10B981")!
                )
            case .dark: // Midnight Panther
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#18181B")!,
                    bellyColor: CodableColor(hex: "#3F3F46")!,
                    beakColor: CodableColor(hex: "#F472B6")!,
                    blushColor: CodableColor(red: 0.75, green: 0.52, blue: 0.99, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#FACC15")!
                )
            case .light: // Snow White Kitty
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#F1F5F9")!,
                    bellyColor: CodableColor(hex: "#FFFFFF")!,
                    beakColor: CodableColor(hex: "#FDA4AF")!,
                    blushColor: CodableColor(red: 0.99, green: 0.64, blue: 0.69, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#3B82F6")!
                )
            case .custom:
                return defaultPalette(for: .classic)
            case .rainbow:
                return defaultPalette(for: .classic)
            }

        case .monkey:
            switch preset {
            case .classic: // Playful Capuchin
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#78350F")!,
                    bellyColor: CodableColor(hex: "#FED7AA")!,
                    beakColor: CodableColor(hex: "#451A03")!,
                    blushColor: CodableColor(red: 0.96, green: 0.25, blue: 0.37, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#92400E")!
                )
            case .dark: // Shadow Gibbon
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#1C1917")!,
                    bellyColor: CodableColor(hex: "#78716C")!,
                    beakColor: CodableColor(hex: "#0C0A09")!,
                    blushColor: CodableColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#F59E0B")!
                )
            case .light: // Golden Marmoset
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#F59E0B")!,
                    bellyColor: CodableColor(hex: "#FEF3C7")!,
                    beakColor: CodableColor(hex: "#78350F")!,
                    blushColor: CodableColor(red: 0.98, green: 0.44, blue: 0.52, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#0D9488")!
                )
            case .custom:
                return defaultPalette(for: .classic)
            case .rainbow:
                return defaultPalette(for: .classic)
            }

        case .giraffe:
            switch preset {
            case .classic: // Savanna Gold Giraffe
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#F59E0B")!,
                    bellyColor: CodableColor(hex: "#FEF3C7")!,
                    beakColor: CodableColor(hex: "#B45309")!,
                    blushColor: CodableColor(red: 0.98, green: 0.44, blue: 0.52, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#78350F")!
                )
            case .dark: // Sunset Auburn Giraffe
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#7C2D12")!,
                    bellyColor: CodableColor(hex: "#E7E5E4")!,
                    beakColor: CodableColor(hex: "#431407")!,
                    blushColor: CodableColor(red: 0.96, green: 0.25, blue: 0.37, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#EAB308")!
                )
            case .light: // Pastel Snow Giraffe
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#FEF08A")!,
                    bellyColor: CodableColor(hex: "#FFFFFF")!,
                    beakColor: CodableColor(hex: "#FDE047")!,
                    blushColor: CodableColor(red: 0.96, green: 0.45, blue: 0.71, alpha: 0.60),
                    eyeHighlightColor: CodableColor(hex: "#06B6D4")!
                )
            case .custom:
                return defaultPalette(for: .classic)
            case .rainbow:
                return defaultPalette(for: .classic)
            }

        case .slinky:
            switch preset {
            case .classic:
                return PetThemePalette(bodyColor: CodableColor(hex: "#4B6B9B")!, bellyColor: CodableColor(hex: "#EAF3FF")!, beakColor: CodableColor(hex: "#9B7BFF")!, blushColor: CodableColor(red: 1.0, green: 0.34, blue: 0.58, alpha: 0.62), eyeHighlightColor: CodableColor(hex: "#67D7FF")!)
            case .dark:
                return PetThemePalette(bodyColor: CodableColor(hex: "#293452")!, bellyColor: CodableColor(hex: "#CBD5E8")!, beakColor: CodableColor(hex: "#C084FC")!, blushColor: CodableColor(red: 0.82, green: 0.42, blue: 1.0, alpha: 0.62), eyeHighlightColor: CodableColor(hex: "#A5F3FC")!)
            case .light:
                return PetThemePalette(bodyColor: CodableColor(hex: "#A8B9E8")!, bellyColor: CodableColor(hex: "#FFFFFF")!, beakColor: CodableColor(hex: "#8B5CF6")!, blushColor: CodableColor(red: 1.0, green: 0.52, blue: 0.72, alpha: 0.62), eyeHighlightColor: CodableColor(hex: "#38BDF8")!)
            case .custom:
                return defaultPalette(for: .classic)
            case .rainbow:
                return PetThemePalette(
                    bodyColor: CodableColor(hex: "#FF3B30")!,
                    bellyColor: CodableColor(hex: "#FFFBF2")!,
                    beakColor: CodableColor(hex: "#8B5CF6")!,
                    blushColor: CodableColor(red: 1.0, green: 0.30, blue: 0.45, alpha: 0.65),
                    eyeHighlightColor: CodableColor(hex: "#06B6D4")!
                )
            }
        }
    }

    public var leftTriggerName: String { "Left Eye" }
    public var rightTriggerName: String { "Right Eye" }
}

public struct ThemeDocument: Codable, Sendable, Equatable {
    public var animal: AnimalKind
    public var name: String
    public var version: Int
    public var palette: PetThemePalette

    enum CodingKeys: String, CodingKey {
        case animal, name, version, palette
    }

    public init(animal: AnimalKind = .bird, name: String = "Custom Theme", version: Int = 1, palette: PetThemePalette) {
        self.animal = animal
        self.name = name
        self.version = version
        self.palette = palette
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.animal = (try? container.decodeIfPresent(AnimalKind.self, forKey: .animal)) ?? .bird
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Custom Theme"
        self.version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        self.palette = try container.decode(PetThemePalette.self, forKey: .palette)
    }

    public func exportJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> (animal: AnimalKind, name: String, palette: PetThemePalette) {
        let decoder = JSONDecoder()
        if let doc = try? decoder.decode(ThemeDocument.self, from: data) {
            return (doc.animal, doc.name, doc.palette)
        }
        if let pal = try? decoder.decode(PetThemePalette.self, from: data) {
            return (.bird, "Imported Theme", pal)
        }
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid theme JSON format"))
    }
}

public enum PetThemePreset: String, Codable, CaseIterable, Sendable {
    case classic = "classic"
    case dark = "dark"
    case light = "light"
    case custom = "custom"
    case rainbow = "rainbow"

    public func displayName(for animal: AnimalKind) -> String {
        switch animal {
        case .bird:
            switch self {
            case .classic: "Classic Blue"
            case .dark: "Midnight Dark"
            case .light: "Daylight Light"
            case .custom: "Custom Palette"
            case .rainbow: "Rainbow"
            }
        case .dog:
            switch self {
            case .classic: "Golden Puppy"
            case .dark: "Chocolate Pup"
            case .light: "Snow Puppy"
            case .custom: "Custom Palette"
            case .rainbow: "Rainbow"
            }
        case .cat:
            switch self {
            case .classic: "Ginger Tabby"
            case .dark: "Midnight Cat"
            case .light: "Snow Kitty"
            case .custom: "Custom Palette"
            case .rainbow: "Rainbow"
            }
        case .monkey:
            switch self {
            case .classic: "Playful Capuchin"
            case .dark: "Shadow Gibbon"
            case .light: "Golden Marmoset"
            case .custom: "Custom Palette"
            case .rainbow: "Rainbow"
            }
        case .giraffe:
            switch self {
            case .classic: "Savanna Gold"
            case .dark: "Sunset Auburn"
            case .light: "Pastel Snow"
            case .custom: "Custom Palette"
            case .rainbow: "Rainbow"
            }
        case .slinky:
            switch self {
            case .classic: "Polished Blue Spring"
            case .dark: "Deep Indigo Coil"
            case .light: "Lavender Toy Spring"
            case .custom: "Custom Palette"
            case .rainbow: "Rainbow Spring"
            }
        }
    }

    public var displayName: String {
        displayName(for: .bird)
    }

    public var palette: PetThemePalette {
        AnimalKind.bird.defaultPalette(for: self)
    }
}

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
        switch self {
        case .shell: return "Run Shell Command"
        case .openApplication: return "Open Application"
        case .openURL: return "Open URL"
        case .runShortcut: return "Run Apple Shortcut"
        case .runBlushMacro: return "Run Another Eye Macro"
        }
    }
    public var placeholder: String {
        switch self {
        case .shell: return "e.g. say 'Hello from Animal Buddy'"
        case .openApplication: return "e.g. Calendar"
        case .openURL: return "e.g. https://example.com"
        case .runShortcut: return "Choose a Shortcut"
        case .runBlushMacro: return "Choose another eye macro"
        }
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

public enum MacroDocumentError: LocalizedError, Sendable, Equatable {
    case invalidFormat(String)
    case unsupportedSchemaVersion(Int)
    case missingMacros

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let format): "This is not an Animal Buddy macro document (format: \(format))."
        case .unsupportedSchemaVersion(let version): "This macro document uses schema version \(version), but this version of Animal Buddy supports version 1."
        case .missingMacros: "The macro document is missing its macros section."
        }
    }
}

public struct MacroDefinition: Codable, Sendable, Equatable {
    public var name: String
    public var steps: [MacroStep]

    public init(name: String = "", steps: [MacroStep] = []) {
        self.name = name
        self.steps = steps
    }

    public init(macro: UserMacro) {
        self.init(name: macro.name, steps: macro.effectiveSteps)
    }

    public var userMacro: UserMacro { UserMacro(name: name, steps: steps) }
}

public struct MacroBlushDefinitions: Codable, Sendable, Equatable {
    public var left: MacroDefinition
    public var right: MacroDefinition

    public init(left: MacroDefinition = MacroDefinition(), right: MacroDefinition = MacroDefinition()) {
        self.left = left
        self.right = right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        left = try container.decodeIfPresent(MacroDefinition.self, forKey: .left) ?? MacroDefinition()
        right = try container.decodeIfPresent(MacroDefinition.self, forKey: .right) ?? MacroDefinition()
    }

    private enum CodingKeys: String, CodingKey { case left, right }
}

public struct MacroDefinitions: Codable, Sendable, Equatable {
    public var blush: MacroBlushDefinitions
    public var drag: [InputCategory: MacroDefinition]

    public init(blush: MacroBlushDefinitions = MacroBlushDefinitions(), drag: [InputCategory: MacroDefinition] = [:]) {
        self.blush = blush
        self.drag = drag
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blush = try container.decodeIfPresent(MacroBlushDefinitions.self, forKey: .blush) ?? MacroBlushDefinitions()
        guard container.contains(.drag) else {
            drag = [:]
            return
        }
        let dragContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .drag)
        var decoded: [InputCategory: MacroDefinition] = [:]
        for key in dragContainer.allKeys {
            guard let category = InputCategory(rawValue: key.stringValue) else {
                throw MacroDocumentError.invalidFormat("unknown drag category \(key.stringValue)")
            }
            decoded[category] = try dragContainer.decode(MacroDefinition.self, forKey: key)
        }
        drag = decoded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blush, forKey: .blush)
        var dragContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .drag)
        for category in InputCategory.allCases {
            if let definition = drag[category] {
                try dragContainer.encode(definition, forKey: DynamicCodingKey(category.rawValue))
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case blush, drag }

    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

public struct MacroDocument: Codable, Sendable, Equatable {
    public static let formatIdentifier = "com.animalbuddy.macros"
    public static let currentSchemaVersion = 1

    public var format: String
    public var schemaVersion: Int
    public var macros: MacroDefinitions

    public init(left: UserMacro = UserMacro(), right: UserMacro = UserMacro(), dragMacros: [DragMacroBinding] = []) {
        self.format = Self.formatIdentifier
        self.schemaVersion = Self.currentSchemaVersion
        var drag = Dictionary(uniqueKeysWithValues: InputCategory.allCases.map { ($0, MacroDefinition()) })
        for binding in dragMacros { drag[binding.category] = MacroDefinition(macro: binding.macro) }
        self.macros = MacroDefinitions(blush: MacroBlushDefinitions(left: MacroDefinition(macro: left), right: MacroDefinition(macro: right)), drag: drag)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decode(String.self, forKey: .format)
        guard format == Self.formatIdentifier else { throw MacroDocumentError.invalidFormat(format) }
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else { throw MacroDocumentError.unsupportedSchemaVersion(version) }
        guard container.contains(.macros) else { throw MacroDocumentError.missingMacros }
        self.format = format
        self.schemaVersion = version
        self.macros = try container.decode(MacroDefinitions.self, forKey: .macros)
    }

    public var leftMacro: UserMacro { macros.blush.left.userMacro }
    public var rightMacro: UserMacro { macros.blush.right.userMacro }
    public var dragMacros: [DragMacroBinding] {
        macros.drag.keys.sorted { $0.rawValue < $1.rawValue }.map { DragMacroBinding(category: $0, macro: macros.drag[$0]!.userMacro) }
    }

    public func exportJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> MacroDocument {
        try JSONDecoder().decode(Self.self, from: data)
    }

    private enum CodingKeys: String, CodingKey { case format, schemaVersion, macros }
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

public struct FeatureItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String { title }
    public let iconName: String
    public let title: String
    public let description: String

    public init(iconName: String, title: String, description: String) {
        self.iconName = iconName
        self.title = title
        self.description = description
    }
}

public struct VersionRelease: Identifiable, Codable, Hashable, Sendable {
    public var id: String { version }
    public let version: String
    public let releaseTitle: String
    public let features: [FeatureItem]

    public init(version: String, releaseTitle: String, features: [FeatureItem]) {
        self.version = version
        self.releaseTitle = releaseTitle
        self.features = features
    }
}

public enum AppChangelog {
    public static let initialWelcomeFeatures: [FeatureItem] = [
        FeatureItem(
            iconName: "pawprint.fill",
            title: "Your Desktop Pet",
            description: "A friendly companion that floats on your screen, reacts to your cursor, and stays out of your way."
        ),
        FeatureItem(
            iconName: "tray.and.arrow.down.fill",
            title: "Drag & Drop Superpowers",
            description: "Drop files, images, or links directly onto your pet to store them in your inbox folder or trigger actions."
        ),
        FeatureItem(
            iconName: "keyboard.fill",
            title: "Modifier Shortcuts",
            description: "Hold Option or Shift while dropping to convert images to PNG, reveal in Finder, copy paths, and more."
        ),
        FeatureItem(
            iconName: "bolt.horizontal.fill",
            title: "Eye Click Macros",
            description: "Click your buddy's left or right eye to run custom shell commands or launch your favorite macOS Shortcuts."
        )
    ]

    public static let releases: [VersionRelease] = [
        VersionRelease(
            version: "a0.25",
            releaseTitle: "Initial Companion Release",
            features: [
                FeatureItem(
                    iconName: "bird.fill",
                    title: "Bird, Dog, & Cat Companions",
                    description: "Choose your favorite buddy with expressive eye tracking and animations."
                ),
                FeatureItem(
                    iconName: "folder.fill",
                    title: "Smart File Inbox",
                    description: "Drop files directly onto your pet for collision-safe file storage."
                )
            ]
        ),
        VersionRelease(
            version: "a0.26",
            releaseTitle: "Monkey, Giraffe & Macro Workshop",
            features: [
                FeatureItem(
                    iconName: "sparkles",
                    title: "New Animal Characters",
                    description: "Say hello to the Monkey and Giraffe buddies with custom color palettes."
                ),
                FeatureItem(
                    iconName: "hammer.fill",
                    title: "Macro Builder & Custom Themes",
                    description: "Export and import custom theme JSONs, and configure custom click actions."
                )
            ]
        ),
        VersionRelease(
            version: "a0.27",
            releaseTitle: "Slinky Spring & Googly Eyes",
            features: [
                FeatureItem(
                    iconName: "scribble.variable",
                    title: "Slinky Pet & Rainbow Spring",
                    description: "Enjoy fluid coil animations and the vibrant new Rainbow Spring theme."
                ),
                FeatureItem(
                    iconName: "eyes",
                    title: "Googly Eyes Mode",
                    description: "Loose, jiggling craft pupils with real physics for the Slinky buddy."
                ),
                FeatureItem(
                    iconName: "circle.dotted",
                    title: "Resting Translucency",
                    description: "Subtle resting opacity that smoothly brightens when your mouse hovers near."
                ),
                FeatureItem(
                    iconName: "hand.point.up.left.fill",
                    title: "Interactive Hand Cursors",
                    description: "Hovering over eyes and interactive zones now shows a pointer hand."
                )
            ]
        ),
        VersionRelease(
            version: "a0.41",
            releaseTitle: "Googly Spring Physics, Rainbow Coils & Auto Updates",
            features: [
                FeatureItem(
                    iconName: "sparkles",
                    title: "Dorky Spring-Mounted Googly Eyes",
                    description: "Slinky features 3D pop-out micro-spring stalks, gravity coordination, and dynamic vigor damping."
                ),
                FeatureItem(
                    iconName: "paintpalette.fill",
                    title: "True Rainbow Spectrum Coils",
                    description: "Vibrant multi-color rainbow spectrum loops and glowing swirl highlights."
                ),
                FeatureItem(
                    iconName: "bolt.horizontal.fill",
                    title: "Eye Click Macro Triggers",
                    description: "Exact full-eye click targets and standardized trigger mapping for every animal companion."
                ),
                FeatureItem(
                    iconName: "arrow.triangle.2.circlepath.circle.fill",
                    title: "Automatic GitHub Update Checker",
                    description: "Seamlessly checks GitHub for new releases with one-click download and instant updates."
                )
            ]
        ),
        VersionRelease(
            version: "a0.42",
            releaseTitle: "General Settings & Helpful Tips Speech Bubble",
            features: [
                FeatureItem(
                    iconName: "gearshape.fill",
                    title: "General Settings Tab",
                    description: "Easily customize your desktop inbox storage folder, window behavior, snapping, tips, and updates."
                ),
                FeatureItem(
                    iconName: "bubble.left.and.text.bubble.right.fill",
                    title: "Helpful Tips Speech Bubble",
                    description: "Friendly educational tips float gently above your buddy, with one-tap navigation directly into Settings."
                ),
                FeatureItem(
                    iconName: "folder.fill.badge.plus",
                    title: "Desktop Inbox Customization",
                    description: "Choose any folder on your Mac for dropped items, with direct Reveal in Finder and Reset actions."
                ),
                FeatureItem(
                    iconName: "sparkle.magnifyingglass",
                    title: "Expanded Macro Placeholders",
                    description: "Drop macros now support {{inbox}} and {{destination}} placeholder paths in custom scripts."
                )
            ]
        ),
        VersionRelease(
            version: "a0.43",
            releaseTitle: "Streamlined Menu Bar & Settings Integration",
            features: [
                FeatureItem(
                    iconName: "menubar.rectangle",
                    title: "Streamlined Menu Bar",
                    description: "A clean, lightweight menu bar dropdown with dynamic show/hide and direct settings shortcuts."
                ),
                FeatureItem(
                    iconName: "slider.horizontal.3",
                    title: "Unified Settings Hub",
                    description: "All animal choices, appearance palettes, snapping rules, updates, and macros now live neatly inside Settings."
                )
            ]
        )
    ]
}

public enum VersionComparator {
    public static func compare(_ v1: String, _ v2: String) -> ComparisonResult {
        let clean1 = cleanVersion(v1)
        let clean2 = cleanVersion(v2)
        return clean1.compare(clean2, options: .numeric)
    }

    public static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        compare(v1, v2) == .orderedDescending
    }

    public static func cleanVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet.letters.union(.whitespacesAndNewlines))
    }
}

public enum WelcomePresentationKind: Equatable, Sendable {
    case firstLaunch(features: [FeatureItem])
    case whatsNew(currentVersion: String, unseenReleases: [VersionRelease])
}

public enum WelcomePresentationEvaluator {
    public static func evaluate(
        settings: AppSettings,
        currentVersion: String,
        catalog: [VersionRelease] = AppChangelog.releases,
        initialWelcomeFeatures: [FeatureItem] = AppChangelog.initialWelcomeFeatures
    ) -> WelcomePresentationKind? {
        guard settings.hasCompletedWelcome, let lastSeen = settings.lastSeenAppVersion else {
            return .firstLaunch(features: initialWelcomeFeatures)
        }

        if VersionComparator.isVersion(currentVersion, greaterThan: lastSeen) {
            let unseen = catalog.filter { VersionComparator.isVersion($0.version, greaterThan: lastSeen) }
            if !unseen.isEmpty {
                return .whatsNew(currentVersion: currentVersion, unseenReleases: unseen)
            }
        }

        return nil
    }
}

public struct AppSettings: Codable, Sendable {
    public var alwaysOnTop = true
    public var petScale = 1.0
    public var snappingEnabled = false
    public var animalKind: AnimalKind = .bird
    public var leftBlushMacro = UserMacro()
    public var rightBlushMacro = UserMacro()
    public var dragMacros: [DragMacroBinding] = []
    public var destinationFolderPath: String? = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("Animal Buddy Inbox", isDirectory: true).path
    public var minimizeDestination: MinimizeDestination = .menubar
    public var themePreset: PetThemePreset = .classic
    public var customPalette: PetThemePalette = AnimalKind.bird.defaultPalette(for: .classic)
    public var hoverTranslucencyEnabled: Bool = true
    public var googlyEyesEnabled: Bool = true
    public var hasCompletedWelcome: Bool = false
    public var lastSeenAppVersion: String? = nil
    public var automaticallyCheckForUpdates: Bool = true
    public var skippedAppVersion: String? = nil
    public var lastUpdateCheckDate: Date? = nil
    public var helpfulTipsEnabled: Bool = false
    public var bindings: [ModifierBinding] = [
        .init(category: .file, modifiers: .none, actionID: "store"),
        .init(category: .image, modifiers: .none, actionID: "store"),
        .init(category: .image, modifiers: .option, actionID: "convert-image"),
        .init(category: .image, modifiers: .command, actionID: "compress-image"),
        .init(category: .file, modifiers: .shift, actionID: "reveal")
    ]

    public var activePalette: PetThemePalette {
        themePreset == .custom ? customPalette : animalKind.defaultPalette(for: themePreset)
    }

    private enum CodingKeys: String, CodingKey {
        case alwaysOnTop, petScale, snappingEnabled, animalKind, leftBlushMacro, rightBlushMacro, dragMacros, destinationFolderPath, minimizeDestination, themePreset, customPalette, hoverTranslucencyEnabled, googlyEyesEnabled, hasCompletedWelcome, lastSeenAppVersion, automaticallyCheckForUpdates, skippedAppVersion, lastUpdateCheckDate, helpfulTipsEnabled, bindings
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        alwaysOnTop = try values.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? true
        petScale = try values.decodeIfPresent(Double.self, forKey: .petScale) ?? 1.0
        snappingEnabled = try values.decodeIfPresent(Bool.self, forKey: .snappingEnabled) ?? false
        animalKind = try values.decodeIfPresent(AnimalKind.self, forKey: .animalKind) ?? .bird
        leftBlushMacro = try values.decodeIfPresent(UserMacro.self, forKey: .leftBlushMacro) ?? UserMacro()
        rightBlushMacro = try values.decodeIfPresent(UserMacro.self, forKey: .rightBlushMacro) ?? UserMacro()
        dragMacros = try values.decodeIfPresent([DragMacroBinding].self, forKey: .dragMacros) ?? []
        destinationFolderPath = try values.decodeIfPresent(String.self, forKey: .destinationFolderPath) ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("Animal Buddy Inbox", isDirectory: true).path
        minimizeDestination = try values.decodeIfPresent(MinimizeDestination.self, forKey: .minimizeDestination) ?? .menubar
        themePreset = try values.decodeIfPresent(PetThemePreset.self, forKey: .themePreset) ?? .classic
        customPalette = try values.decodeIfPresent(PetThemePalette.self, forKey: .customPalette) ?? AnimalKind.bird.defaultPalette(for: .classic)
        hoverTranslucencyEnabled = try values.decodeIfPresent(Bool.self, forKey: .hoverTranslucencyEnabled) ?? true
        googlyEyesEnabled = try values.decodeIfPresent(Bool.self, forKey: .googlyEyesEnabled) ?? true
        hasCompletedWelcome = try values.decodeIfPresent(Bool.self, forKey: .hasCompletedWelcome) ?? false
        lastSeenAppVersion = try values.decodeIfPresent(String.self, forKey: .lastSeenAppVersion)
        automaticallyCheckForUpdates = try values.decodeIfPresent(Bool.self, forKey: .automaticallyCheckForUpdates) ?? true
        skippedAppVersion = try values.decodeIfPresent(String.self, forKey: .skippedAppVersion)
        lastUpdateCheckDate = try values.decodeIfPresent(Date.self, forKey: .lastUpdateCheckDate)
        helpfulTipsEnabled = try values.decodeIfPresent(Bool.self, forKey: .helpfulTipsEnabled) ?? false
        bindings = try values.decodeIfPresent([ModifierBinding].self, forKey: .bindings) ?? []
    }
}

public enum TipSettingsTarget: String, Sendable, Codable, Equatable {
    case general = "general"
    case appearance = "appearance"
    case macrosWorkshop = "macros"

    public var tabIndex: Int {
        switch self {
        case .general: return 0
        case .appearance: return 1
        case .macrosWorkshop: return 2
        }
    }
}

public struct AppTip: Sendable, Equatable {
    public let id: String
    public let emoji: String
    public let title: String
    public let message: String
    public let settingsTarget: TipSettingsTarget?

    public init(id: String, emoji: String, title: String, message: String, settingsTarget: TipSettingsTarget? = nil) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.message = message
        self.settingsTarget = settingsTarget
    }
}

public enum HelpfulTipsCatalog {
    public static let allTips: [AppTip] = [
        AppTip(
            id: "eye-macros",
            emoji: "👀",
            title: "Eye Click Macros",
            message: "Click my left or right eye to trigger your custom shell commands or launch Apple Shortcuts!",
            settingsTarget: .macrosWorkshop
        ),
        AppTip(
            id: "option-convert-png",
            emoji: "🖼️",
            title: "Quick PNG Conversion",
            message: "Hold the Option key while dropping an image onto me to automatically convert it to PNG format.",
            settingsTarget: .macrosWorkshop
        ),
        AppTip(
            id: "shift-reveal-finder",
            emoji: "🔍",
            title: "Reveal in Finder",
            message: "Hold the Shift key while dropping any file or folder to immediately highlight it in Finder.",
            settingsTarget: .macrosWorkshop
        ),
        AppTip(
            id: "cmd-compress",
            emoji: "🗜️",
            title: "Quick Image Compression",
            message: "Hold the Command key while dropping an image to compress and optimize it for web use.",
            settingsTarget: .macrosWorkshop
        ),
        AppTip(
            id: "dismiss-crosshair",
            emoji: "🎯",
            title: "Screen Edge Dismissal",
            message: "Drag me towards the top or bottom center edge of your screen to quickly hide or minimize me.",
            settingsTarget: .general
        ),
        AppTip(
            id: "slinky-googly-eyes",
            emoji: "🤪",
            title: "Googly Eyes Mode",
            message: "Customize the Slinky buddy with spring-mounted, gravity-coordinated jiggling craft eyes!",
            settingsTarget: .appearance
        ),
        AppTip(
            id: "macro-workshop",
            emoji: "⚡️",
            title: "Macros Workshop",
            message: "Open Settings → Macros Workshop to create Scratch-like automated multi-step sequences.",
            settingsTarget: .macrosWorkshop
        ),
        AppTip(
            id: "custom-themes",
            emoji: "🎨",
            title: "Custom Plumage & Themes",
            message: "Pick custom colors for feathers, fur, and eyes, or import & export theme JSON files from the Menu Bar.",
            settingsTarget: .appearance
        ),
        AppTip(
            id: "smart-inbox",
            emoji: "📥",
            title: "Smart Desktop Inbox",
            message: "Drop files, links, or text snippets onto me anytime to safely store them in your Animal Buddy Inbox.",
            settingsTarget: .general
        )
    ]

    public static func randomTip(excluding currentId: String? = nil) -> AppTip {
        let candidates = allTips.filter { $0.id != currentId }
        return candidates.randomElement() ?? allTips[0]
    }
}
