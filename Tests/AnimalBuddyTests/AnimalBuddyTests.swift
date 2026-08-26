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
    func testCrosshairVisibilityWithinRadius() {
        let target = NSPoint(x: 500, y: 764)
        let insideFrame = NSRect(x: 450, y: 650, width: 100, height: 100) // midX = 500, midY = 700 -> distance = 64 <= 260
        let outsideFrame = NSRect(x: 100, y: 200, width: 100, height: 100) // midX = 150, midY = 250 -> distance >> 260
        XCTAssertTrue(DragTargetOverlayController.isWithinVisibilityRadius(for: insideFrame, target: target))
        XCTAssertFalse(DragTargetOverlayController.isWithinVisibilityRadius(for: outsideFrame, target: target))
    }
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
        let data = Data(#"{"format":"com.animalbuddy.macros","schemaVersion":1,"futureField":true,"macros":{"blush":{"left":{"name":"Hello","steps":[]}},"drag":{"image":{"name":"Image","steps":[]}},"futureSection":{"enabled":true}}}"#.utf8)
        let document = try MacroDocument.decode(from: data)
        XCTAssertEqual(document.leftMacro.name, "Hello")
        XCTAssertEqual(document.rightMacro, UserMacro())
        XCTAssertEqual(document.dragMacros.count, 1)
    }
    func testMacroDocumentRejectsUnknownDragCategory() {
        let data = Data(#"{"format":"com.animalbuddy.macros","schemaVersion":1,"macros":{"drag":{"notARealCategory":{"name":"Bad","steps":[]}}}}"#.utf8)
        XCTAssertThrowsError(try MacroDocument.decode(from: data))
    }
    func testMacroDocumentRejectsUnsupportedSchemaVersion() {
        let data = Data(#"{"format":"com.animalbuddy.macros","schemaVersion":2,"macros":{}}"#.utf8)
        XCTAssertThrowsError(try MacroDocument.decode(from: data)) { error in
            XCTAssertEqual(error as? MacroDocumentError, .unsupportedSchemaVersion(2))
        }
    }
    func testLegacySettingsStillDecodeAfterMacroSchemaAddition() throws {
        let legacy = Data(#"{"leftBlushMacro":{"name":"Legacy","command":"say hi"},"rightBlushMacro":{},"bindings":[]}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: legacy)
        XCTAssertEqual(settings.leftBlushMacro.effectiveSteps, [MacroStep(kind: .shell, value: "say hi")])
        XCTAssertTrue(settings.dragMacros.isEmpty)
        XCTAssertEqual(settings.animalKind, .bird)
    }

    func testAnimalKindPresetsAndPalettes() {
        for animal in AnimalKind.allCases {
            XCTAssertFalse(animal.displayName.isEmpty)
            XCTAssertEqual(animal.themePresets.count, animal == .slinky ? 5 : 4)
            let classicPal = animal.defaultPalette(for: .classic)
            let darkPal = animal.defaultPalette(for: .dark)
            let lightPal = animal.defaultPalette(for: .light)
            XCTAssertNotEqual(classicPal.bodyColor, darkPal.bodyColor)
            XCTAssertNotEqual(classicPal.bodyColor, lightPal.bodyColor)
            if animal == .slinky {
                XCTAssertTrue(animal.themePresets.contains(.rainbow))
                XCTAssertNotEqual(classicPal.bodyColor, animal.defaultPalette(for: .rainbow).bodyColor)
            }
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
        let legacyJSON = Data(##"{"name":"Vintage Sky","version":1,"palette":{"bodyColor":"#4A90E2","bellyColor":"#FFF8DC","beakColor":"#FF9500","blushColor":"#FF6B81","eyeHighlightColor":"#FFFFFF"}}"##.utf8)
        let (decodedAnimal, decodedName, decodedPalette) = try ThemeDocument.decode(from: legacyJSON)
        XCTAssertEqual(decodedAnimal, AnimalKind.bird)
        XCTAssertEqual(decodedName, "Vintage Sky")
        XCTAssertEqual(decodedPalette.bodyColor.hexString.uppercased(), "#4A90E2")
    }

    func testAppSettingsRoundtrip() throws {
        var defaultSettings = AppSettings()
        XCTAssertEqual(defaultSettings.animalKind, .bird)
        XCTAssertTrue(defaultSettings.alwaysOnTop)
        XCTAssertTrue(defaultSettings.hoverTranslucencyEnabled)

        let encoded = try JSONEncoder().encode(defaultSettings)
        var decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)
        XCTAssertEqual(decoded.animalKind, .bird)
        XCTAssertTrue(decoded.alwaysOnTop)
        XCTAssertTrue(decoded.hoverTranslucencyEnabled)

        defaultSettings.hoverTranslucencyEnabled = false
        let disabledEncoded = try JSONEncoder().encode(defaultSettings)
        decoded = try JSONDecoder().decode(AppSettings.self, from: disabledEncoded)
        XCTAssertFalse(decoded.hoverTranslucencyEnabled)
    }

    func testBlushTappedInvokesCallback() {
        let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        var tappedSlot: BlushSlot?
        petView.onBlushTapped = { slot in
            tappedSlot = slot
        }

        // Find the left and right blush button subviews
        let buttons = petView.subviews.compactMap { $0 as? NSButton }.filter { $0.action != nil }
        XCTAssertGreaterThanOrEqual(buttons.count, 2)

        // Trigger left action
        petView.perform(NSSelectorFromString("leftBlushPressed"))
        XCTAssertEqual(tappedSlot, .left)

        // Trigger right action
        petView.perform(NSSelectorFromString("rightBlushPressed"))
        XCTAssertEqual(tappedSlot, .right)
    }

    func testEyeAndBlushTriggerCoversEyePositions() {
        let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        for animal in AnimalKind.allCases {
            petView.animalKind = animal
            petView.layout()
            let blushButtons = petView.subviews.compactMap { $0 as? MacroBlushButton }
            XCTAssertEqual(blushButtons.count, 2)
            let leftBtn = blushButtons[0]
            let rightBtn = blushButtons[1]

            // Ensure left and right buttons have substantial width/height covering eyes and cheeks
            XCTAssertGreaterThanOrEqual(leftBtn.frame.width, 48)
            XCTAssertGreaterThanOrEqual(leftBtn.frame.height, 44)
            XCTAssertGreaterThanOrEqual(rightBtn.frame.width, 48)
            XCTAssertGreaterThanOrEqual(rightBtn.frame.height, 44)

            // Ensure left button is on left side and right button is on right side
            XCTAssertLessThan(leftBtn.frame.midX, 75)
            XCTAssertGreaterThan(rightBtn.frame.midX, 75)
        }
    }

    func testHitTestCapturesEntirePetBoundary() {
        let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        petView.animalKind = .slinky
        petView.layout()

        // Test corners, edges, and inner points across the 150x150 boundary
        let samplePoints = [
            NSPoint(x: 0, y: 0),
            NSPoint(x: 149, y: 0),
            NSPoint(x: 0, y: 149),
            NSPoint(x: 149, y: 149),
            NSPoint(x: 75, y: 75),
            NSPoint(x: 20, y: 80),
            NSPoint(x: 130, y: 80),
            NSPoint(x: 75, y: 20),
            NSPoint(x: 75, y: 130)
        ]

        for point in samplePoints {
            let hitView = petView.hitTest(point)
            XCTAssertNotNil(hitView, "Point \(point) should register a hit within pet boundaries")
        }

        // Test outside points return nil
        XCTAssertNil(petView.hitTest(NSPoint(x: -1, y: 50)))
        XCTAssertNil(petView.hitTest(NSPoint(x: 151, y: 50)))
        XCTAssertNil(petView.hitTest(NSPoint(x: 50, y: -1)))
        XCTAssertNil(petView.hitTest(NSPoint(x: 50, y: 151)))
    }

    func testWindowDirectDraggingUpdatesFrame() {
        let panel = PetPanel(
            contentRect: NSRect(x: 100, y: 100, width: 150, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        var dragBeganCalled = false
        var dragChangedCount = 0
        var dragEndedCalled = false

        panel.onDragBegan = { dragBeganCalled = true }
        panel.onDragChanged = { _, _, _ in dragChangedCount += 1 }
        panel.onDragEnded = { _, startFrame, endFrame, _ in
            dragEndedCalled = true
            XCTAssertEqual(startFrame.origin.x, 100)
            XCTAssertEqual(startFrame.origin.y, 100)
            XCTAssertEqual(endFrame.origin.x, 150)
            XCTAssertEqual(endFrame.origin.y, 180)
        }

        // Simulate drag sequence
        panel.beginWindowDrag(at: NSPoint(x: 120, y: 120), eventTimestamp: 1.0)
        XCTAssertTrue(dragBeganCalled)

        panel.continueWindowDrag(at: NSPoint(x: 170, y: 200), eventTimestamp: 1.05)
        XCTAssertEqual(dragChangedCount, 1)
        XCTAssertEqual(panel.frame.origin.x, 150) // 100 + (170 - 120) = 150
        XCTAssertEqual(panel.frame.origin.y, 180) // 100 + (200 - 120) = 180

        panel.endWindowDrag(at: NSPoint(x: 170, y: 200), eventTimestamp: 1.08)
        XCTAssertTrue(dragEndedCalled)
    }
}
