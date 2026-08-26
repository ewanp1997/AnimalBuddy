import XCTest
import UniformTypeIdentifiers
@testable import AnimalBuddy

@MainActor final class AnimalBuddyTests: XCTestCase {
    func testModifierBindingSelectsConvertImage() { var settings = AppSettings(); settings.bindings = [.init(category: .image, modifiers: .option, actionID: "convert-image")]; let registry = ActionRegistry(settings: settings); let input = DropInput(category: .image); XCTAssertEqual(registry.action(for: input, modifiers: .option)?.descriptor.identifier, "convert-image") }
    func testURLClassification() { XCTAssertEqual(InputClassifier.classify(urls: [], text: "https://example.com").category, .url) }
    func testImageTypeClassification() throws { let url = URL(fileURLWithPath: "/tmp/photo.png"); XCTAssertEqual(InputClassifier.classify(urls: [url]).category, .image) }
    func testSafeDestinationNameAvoidsCollision() throws { let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("animal-buddy-test-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: folder) }; let source = folder.appendingPathComponent("photo.png"); FileManager.default.createFile(atPath: source.path, contents: Data()); XCTAssertTrue(SafeFileOperations.uniqueURL(for: source, in: folder).lastPathComponent.contains("2")) }
    func testPupilOffsetIsClamped() { let offset = PetView.clampPupilOffset(NSPoint(x: 100, y: 0)); XCTAssertEqual(offset.x, 5, accuracy: 0.001); XCTAssertEqual(offset.y, 0, accuracy: 0.001) }
    func testScreenPupilOffsetUsesFlippedVerticalDirection() { let eye = NSPoint(x: 100, y: 100); XCTAssertLessThan(PetView.pupilOffset(towardScreenPoint: NSPoint(x: 100, y: 120), fromScreenEyeCenter: eye).y, 0); XCTAssertGreaterThan(PetView.pupilOffset(towardScreenPoint: NSPoint(x: 100, y: 80), fromScreenEyeCenter: eye).y, 0) }
    func testDistanceToRectIsZeroInsideAndMeasuredOutside() { let rect = NSRect(x: 10, y: 10, width: 20, height: 20); XCTAssertEqual(PetWindowController.distance(from: NSPoint(x: 20, y: 20), to: rect), 0); XCTAssertEqual(PetWindowController.distance(from: NSPoint(x: 40, y: 20), to: rect), 10) }
    func testDragDismissZoneRequiresCenteredTopOrBottom() { let screen = NSRect(x: 0, y: 0, width: 1000, height: 800); XCTAssertTrue(PetPanel.shouldDismiss(frame: NSRect(x: 450, y: 740, width: 100, height: 100), on: screen)); XCTAssertTrue(PetPanel.shouldDismiss(frame: NSRect(x: 450, y: -40, width: 100, height: 100), on: screen)); XCTAssertFalse(PetPanel.shouldDismiss(frame: NSRect(x: 50, y: 740, width: 100, height: 100), on: screen)) }
    func testDragVelocityIsCappedToUnitRange() { XCTAssertEqual(min(2500 / 1000, 1), 1) }
    func testCrosshairStaysDarkOutsideDismissBoundary() { XCTAssertEqual(DragTargetOverlayController.redness(for: NSRect(x: 0, y: 0, width: 100, height: 100), target: NSPoint(x: 250, y: 50)), 0) }
    func testCrosshairRednessStartsAtDismissBoundary() { XCTAssertEqual(DragTargetOverlayController.redness(for: NSRect(x: 0, y: 0, width: 100, height: 100), target: NSPoint(x: 150, y: 50), boundaryRadius: 100), 0, accuracy: 0.001); XCTAssertGreaterThan(DragTargetOverlayController.redness(for: NSRect(x: 0, y: 0, width: 100, height: 100), target: NSPoint(x: 90, y: 50), boundaryRadius: 100), 0) }
    func testCrosshairUsesTopOrBottomBasedOnScreenHalf() { let screen = NSRect(x: 0, y: 0, width: 1000, height: 800); XCTAssertEqual(DragTargetOverlayController.targetCenterY(for: 700, in: screen), 764); XCTAssertEqual(DragTargetOverlayController.targetCenterY(for: 100, in: screen), 36) }
    func testCrosshairTargetStaysHorizontallyCentered() { let screen = NSRect(x: 0, y: 0, width: 1000, height: 800); let target = DragTargetOverlayController.targetCenter(for: NSPoint(x: 300, y: 700), in: screen); XCTAssertEqual(target.x, 500); XCTAssertEqual(target.y, 764) }
    func testDismissRadiusSeparatesCloseFromRestore() { let target = NSPoint(x: 500, y: 764); XCTAssertLessThan(hypot(500 - target.x, 764 - target.y), 100); XCTAssertGreaterThan(hypot(300 - target.x, 764 - target.y), 100) }
    func testLegacyMacroCommandBecomesShellStep() { let macro = UserMacro(name: "Say hi", command: "say hi"); XCTAssertEqual(macro.effectiveSteps, [MacroStep(kind: .shell, value: "say hi")]) }
    func testShortcutMacroStepIsRepresented() { let step = MacroStep(kind: .runShortcut, value: "Morning Routine"); XCTAssertEqual(step.kind, .runShortcut); XCTAssertEqual(step.value, "Morning Routine") }
    func testApplicationClassification() { XCTAssertEqual(InputClassifier.detect(urls: [URL(fileURLWithPath: "/Applications/Calendar.app")]).category, .application) }
    func testDirectoryClassification() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("animal-buddy-context-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertEqual(InputClassifier.detect(urls: [folder]).category, .directory)
    }
    func testMixedDropPreservesEveryItem() {
        let context = InputClassifier.detect(urls: [URL(fileURLWithPath: "/tmp/photo.png"), URL(fileURLWithPath: "/tmp/readme.txt")])
        XCTAssertEqual(context.category, .mixed)
        XCTAssertEqual(context.items.count, 2)
        XCTAssertEqual(context.input.urls.count, 2)
    }
    func testContextPresentationMatchesInputKind() {
        XCTAssertEqual(InputClassifier.detect(urls: [URL(fileURLWithPath: "/tmp/photo.png")]).presentation.prop, .cameraAndSDCard)
        XCTAssertEqual(InputClassifier.detect(urls: [], text: "https://example.com").presentation.prop, .envelopeAndLink)
        XCTAssertEqual(InputClassifier.detect(urls: [], text: "plain text").presentation.prop, .questionMark)
    }
    func testConfiguredActionsIncludeCompatibleAlternatives() {
        var settings = AppSettings()
        settings.bindings = [
            .init(category: .application, modifiers: .none, actionID: "store"),
            .init(category: .application, modifiers: .option, actionID: "copy-path")
        ]
        let registry = ActionRegistry(settings: settings)
        let input = InputClassifier.classify(urls: [URL(fileURLWithPath: "/Applications/Calendar.app")])
        XCTAssertEqual(registry.action(for: input, modifiers: .none)?.descriptor.identifier, "store")
        XCTAssertEqual(registry.configuredActions(for: input, modifiers: .none).map { $0.descriptor.identifier }, ["store", "copy-path"])
    }
    func testDragMacroBindingPersistsAndMatchesDropCategory() throws {
        var settings = AppSettings()
        settings.dragMacros = [DragMacroBinding(category: .image, macro: UserMacro(name: "Image helper", steps: [MacroStep(kind: .shell, value: "echo {{path}}")]))]
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.dragMacros.first?.category, .image)
        XCTAssertEqual(restored.dragMacros.first?.macro.effectiveSteps.first?.value, "echo {{path}}")
    }
    func testMacroDocumentUsesCanonicalSchemaWithoutLegacyCommand() throws {
        let document = MacroDocument(left: UserMacro(name: "Hello", command: "say hi"))
        let json = String(data: try document.exportJSONData(), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"format\" : \"com.animalbuddy.macros\""))
        XCTAssertTrue(json.contains("\"schemaVersion\" : 1"))
        XCTAssertTrue(json.contains("\"steps\""))
        XCTAssertFalse(json.contains("\"command\""))
    }
    func testMacroDocumentRoundTripsEveryDragCategory() throws {
        let bindings = InputCategory.allCases.map { DragMacroBinding(category: $0, macro: UserMacro(name: $0.rawValue, steps: [MacroStep(kind: .shell, value: "echo \($0.rawValue)")])) }
        let document = MacroDocument(left: UserMacro(name: "Left"), right: UserMacro(name: "Right"), dragMacros: bindings)
        let restored = try MacroDocument.decode(from: document.exportJSONData())
        XCTAssertEqual(restored.leftMacro.name, "Left")
        XCTAssertEqual(restored.rightMacro.name, "Right")
        XCTAssertEqual(Set(restored.dragMacros.map(\.category)), Set(InputCategory.allCases))
    }
    func testMacroDocumentIgnoresUnknownFieldsAndDefaultsMissingEntries() throws {
        let data = #"{"format":"com.animalbuddy.macros","schemaVersion":1,"futureField":true,"macros":{"blush":{"left":{"name":"Hello","steps":[]}},"drag":{"image":{"name":"Image","steps":[]}},"futureSection":{"enabled":true}}}"#.data(using: .utf8)!
        let document = try MacroDocument.decode(from: data)
        XCTAssertEqual(document.leftMacro.name, "Hello")
        XCTAssertEqual(document.rightMacro, UserMacro())
        XCTAssertEqual(document.dragMacros.count, 1)
    }
    func testMacroDocumentRejectsUnknownDragCategory() {
        let data = #"{"format":"com.animalbuddy.macros","schemaVersion":1,"macros":{"drag":{"notARealCategory":{"name":"Bad","steps":[]}}}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try MacroDocument.decode(from: data))
    }
    func testMacroDocumentRejectsUnsupportedSchemaVersion() {
        let data = #"{"format":"com.animalbuddy.macros","schemaVersion":2,"macros":{}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try MacroDocument.decode(from: data)) { error in
            XCTAssertEqual(error as? MacroDocumentError, .unsupportedSchemaVersion(2))
        }
    }
    func testLegacySettingsStillDecodeAfterMacroSchemaAddition() throws {
        let legacy = #"{"leftBlushMacro":{"name":"Legacy","command":"say hi"},"rightBlushMacro":{},"bindings":[]}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: legacy)
        XCTAssertEqual(settings.leftBlushMacro.effectiveSteps, [MacroStep(kind: .shell, value: "say hi")])
        XCTAssertTrue(settings.dragMacros.isEmpty)
        XCTAssertEqual(settings.animalKind, .bird)
    }

    func testAnimalKindPresetsAndPalettes() {
        for animal in AnimalKind.allCases {
            XCTAssertFalse(animal.displayName.isEmpty)
            XCTAssertEqual(animal.themePresets.count, 4)
            let classicPal = animal.defaultPalette(for: .classic)
            let darkPal = animal.defaultPalette(for: .dark)
            let lightPal = animal.defaultPalette(for: .light)
            XCTAssertNotEqual(classicPal.bodyColor, darkPal.bodyColor)
            XCTAssertNotEqual(classicPal.bodyColor, lightPal.bodyColor)
        }
    }

    func testThemeDocumentPreservesAnimalKind() throws {
        let dogTheme = ThemeDocument(animal: .dog, name: "Golden Puppy", version: 1, palette: AnimalKind.dog.defaultPalette(for: .classic))
        let data = try dogTheme.exportJSONData()
        let (decodedAnimal, decodedName, decodedPalette) = try ThemeDocument.decode(from: data)
        XCTAssertEqual(decodedAnimal, .dog)
        XCTAssertEqual(decodedName, "Golden Puppy")
        XCTAssertEqual(decodedPalette.bodyColor, AnimalKind.dog.defaultPalette(for: .classic).bodyColor)
    }

    func testThemeDocumentBackwardsCompatibilityDefaultsToBird() throws {
        let legacyJSON = ##"{"name":"Vintage Sky","version":1,"palette":{"bodyColor":"#4A90E2","bellyColor":"#FFF8DC","beakColor":"#FF9500","blushColor":"#FF6B81","eyeHighlightColor":"#FFFFFF"}}"##.data(using: .utf8)!
        let (decodedAnimal, decodedName, decodedPalette) = try ThemeDocument.decode(from: legacyJSON)
        XCTAssertEqual(decodedAnimal, AnimalKind.bird)
        XCTAssertEqual(decodedName, "Vintage Sky")
        XCTAssertEqual(decodedPalette.bodyColor.hexString.uppercased(), "#4A90E2")
    }

    func testTextBoxAwarenessSettingDefaultAndDecoding() throws {
        let defaultSettings = AppSettings()
        XCTAssertTrue(defaultSettings.textBoxAwarenessEnabled)

        let encoded = try JSONEncoder().encode(defaultSettings)
        var decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)
        XCTAssertTrue(decoded.textBoxAwarenessEnabled)

        decoded.textBoxAwarenessEnabled = false
        let reencoded = try JSONEncoder().encode(decoded)
        let redecoded = try JSONDecoder().decode(AppSettings.self, from: reencoded)
        XCTAssertFalse(redecoded.textBoxAwarenessEnabled)
    }
}

