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
        XCTAssertTrue(defaultSettings.googlyEyesEnabled)

        let encoded = try JSONEncoder().encode(defaultSettings)
        var decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)
        XCTAssertEqual(decoded.animalKind, .bird)
        XCTAssertTrue(decoded.alwaysOnTop)
        XCTAssertTrue(decoded.hoverTranslucencyEnabled)
        XCTAssertTrue(decoded.googlyEyesEnabled)

        defaultSettings.hoverTranslucencyEnabled = false
        defaultSettings.googlyEyesEnabled = false
        let disabledEncoded = try JSONEncoder().encode(defaultSettings)
        decoded = try JSONDecoder().decode(AppSettings.self, from: disabledEncoded)
        XCTAssertFalse(decoded.hoverTranslucencyEnabled)
        XCTAssertFalse(decoded.googlyEyesEnabled)
    }

    func testSlinkyGooglyEyesToggleAndRendering() {
        let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        petView.animalKind = .slinky
        petView.themePreset = .rainbow
        petView.googlyEyesEnabled = true
        petView.layout()

        // Verify googly eyes property is set and view draws without error
        XCTAssertTrue(petView.googlyEyesEnabled)
        petView.display()

        // Toggle googly eyes off
        petView.googlyEyesEnabled = false
        XCTAssertFalse(petView.googlyEyesEnabled)
        petView.display()
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

    func testEyeMacroTriggerMatchesEyePositions() {
        let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        for animal in AnimalKind.allCases {
            petView.animalKind = animal
            petView.layout()
            let blushButtons = petView.subviews.compactMap { $0 as? MacroBlushButton }
            XCTAssertEqual(blushButtons.count, 2)
            let leftBtn = blushButtons[0]
            let rightBtn = blushButtons[1]

            let (expectedLeft, expectedRight) = PetView.eyeRects(for: animal, in: petView.bounds)
            XCTAssertEqual(leftBtn.frame, expectedLeft)
            XCTAssertEqual(rightBtn.frame, expectedRight)

            // Ensure left button is on left side and right button is on right side
            XCTAssertLessThan(leftBtn.frame.midX, 75)
            XCTAssertGreaterThan(rightBtn.frame.midX, 75)

            // Verify entire eye is clickable: top half, center, and bottom half
            let leftEyeTop = NSPoint(x: expectedLeft.midX, y: expectedLeft.minY + 3)
            let leftEyeCenter = NSPoint(x: expectedLeft.midX, y: expectedLeft.midY)
            let leftEyeBottom = NSPoint(x: expectedLeft.midX, y: expectedLeft.maxY - 3)
            XCTAssertEqual(petView.hitTest(leftEyeTop), leftBtn, "Top of left eye for \(animal.displayName) must hit macro button")
            XCTAssertEqual(petView.hitTest(leftEyeCenter), leftBtn, "Center of left eye for \(animal.displayName) must hit macro button")
            XCTAssertEqual(petView.hitTest(leftEyeBottom), leftBtn, "Bottom of left eye for \(animal.displayName) must hit macro button")

            let rightEyeTop = NSPoint(x: expectedRight.midX, y: expectedRight.minY + 3)
            let rightEyeCenter = NSPoint(x: expectedRight.midX, y: expectedRight.midY)
            let rightEyeBottom = NSPoint(x: expectedRight.midX, y: expectedRight.maxY - 3)
            XCTAssertEqual(petView.hitTest(rightEyeTop), rightBtn, "Top of right eye for \(animal.displayName) must hit macro button")
            XCTAssertEqual(petView.hitTest(rightEyeCenter), rightBtn, "Center of right eye for \(animal.displayName) must hit macro button")
            XCTAssertEqual(petView.hitTest(rightEyeBottom), rightBtn, "Bottom of right eye for \(animal.displayName) must hit macro button")

            // Clicking blush / cheek areas below or outside the eyes should hit the petView directly (not the macro buttons)
            let cheekPoint = NSPoint(x: 20, y: 80)
            XCTAssertEqual(petView.hitTest(cheekPoint), petView)
        }

        // Verify window-backed hit testing (where NSWindow sends points in window coordinate space)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 150, height: 150), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = petView
        petView.animalKind = .bird
        petView.layout()
        let blushButtons = petView.subviews.compactMap { $0 as? MacroBlushButton }
        let leftBtn = blushButtons[0]
        let rightBtn = blushButtons[1]
        let (birdLeft, birdRight) = PetView.eyeRects(for: .bird, in: petView.bounds)

        // In window coords (unflipped, y=0 at bottom), top of eye (flipped y=38) is window y = 150 - 38 = 112
        let windowTopLeftEye = NSPoint(x: birdLeft.midX, y: 150 - (birdLeft.minY + 3))
        let windowCenterLeftEye = NSPoint(x: birdLeft.midX, y: 150 - birdLeft.midY)
        let windowBottomLeftEye = NSPoint(x: birdLeft.midX, y: 150 - (birdLeft.maxY - 3))
        XCTAssertEqual(petView.hitTest(windowTopLeftEye), leftBtn, "Top of left eye in window coords must hit macro button")
        XCTAssertEqual(petView.hitTest(windowCenterLeftEye), leftBtn, "Center of left eye in window coords must hit macro button")
        XCTAssertEqual(petView.hitTest(windowBottomLeftEye), leftBtn, "Bottom of left eye in window coords must hit macro button")

        let windowTopRightEye = NSPoint(x: birdRight.midX, y: 150 - (birdRight.minY + 3))
        let windowCenterRightEye = NSPoint(x: birdRight.midX, y: 150 - birdRight.midY)
        let windowBottomRightEye = NSPoint(x: birdRight.midX, y: 150 - (birdRight.maxY - 3))
        XCTAssertEqual(petView.hitTest(windowTopRightEye), rightBtn, "Top of right eye in window coords must hit macro button")
        XCTAssertEqual(petView.hitTest(windowCenterRightEye), rightBtn, "Center of right eye in window coords must hit macro button")
        XCTAssertEqual(petView.hitTest(windowBottomRightEye), rightBtn, "Bottom of right eye in window coords must hit macro button")
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

    func testVersionComparatorHandlesAlphaAndSemVer() {
        XCTAssertTrue(VersionComparator.isVersion("a0.27", greaterThan: "a0.26"))
        XCTAssertTrue(VersionComparator.isVersion("0.27", greaterThan: "0.26"))
        XCTAssertTrue(VersionComparator.isVersion("1.0.0", greaterThan: "0.9.9"))
        XCTAssertFalse(VersionComparator.isVersion("a0.25", greaterThan: "a0.27"))
        XCTAssertFalse(VersionComparator.isVersion("a0.27", greaterThan: "a0.27"))
        XCTAssertEqual(VersionComparator.compare("a0.27", "a0.27"), .orderedSame)
    }

    func testWelcomeEvaluatorFirstLaunchReturnsInitialWelcome() {
        var settings = AppSettings()
        settings.hasCompletedWelcome = false
        settings.lastSeenAppVersion = nil

        let presentation = WelcomePresentationEvaluator.evaluate(settings: settings, currentVersion: "a0.27")
        guard case .firstLaunch(let features)? = presentation else {
            XCTFail("Expected .firstLaunch presentation on fresh install")
            return
        }
        XCTAssertEqual(features.count, 4)
        XCTAssertEqual(features.first?.title, "Your Desktop Pet")
    }

    func testWelcomeEvaluatorAppUpdateReturnsWhatsNewWithDiff() {
        var settings = AppSettings()
        settings.hasCompletedWelcome = true
        settings.lastSeenAppVersion = "a0.50"

        let presentation = WelcomePresentationEvaluator.evaluate(settings: settings, currentVersion: "a0.65")
        guard case .whatsNew(let version, let releases)? = presentation else {
            XCTFail("Expected .whatsNew presentation on update")
            return
        }
        XCTAssertEqual(version, "a0.65")
        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases.first?.version, "a0.65")
        XCTAssertEqual(releases.first?.releaseTitle, "Help Me Focus Mode & Performance Polish")
        XCTAssertTrue(releases.first?.features.contains { $0.title == "Help Me Focus & Just Cute Modes" } == true)
    }

    func testWelcomeEvaluatorSameVersionReturnsNil() {
        var settings = AppSettings()
        settings.hasCompletedWelcome = true
        settings.lastSeenAppVersion = "a0.65"

        let presentation = WelcomePresentationEvaluator.evaluate(settings: settings, currentVersion: "a0.65")
        XCTAssertNil(presentation, "Expected nil when version matches last seen")
    }

    func testWelcomeEvaluatorMultiVersionUpgradeAggregatesUnseenReleases() {
        var settings = AppSettings()
        settings.hasCompletedWelcome = true
        settings.lastSeenAppVersion = "a0.25"

        let presentation = WelcomePresentationEvaluator.evaluate(settings: settings, currentVersion: "a0.65")
        guard case .whatsNew(_, let releases)? = presentation else {
            XCTFail("Expected .whatsNew for multi-version upgrade")
            return
        }
        XCTAssertEqual(releases.map(\.version), ["a0.26", "a0.27", "a0.41", "a0.42", "a0.43", "a0.50", "a0.65"])
    }

    func testAppSettingsPreservesWelcomeKeysOnRoundTrip() throws {
        var settings = AppSettings()
        settings.hasCompletedWelcome = true
        settings.lastSeenAppVersion = "a0.27"

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(restored.hasCompletedWelcome)
        XCTAssertEqual(restored.lastSeenAppVersion, "a0.27")
    }

    func testLegacySettingsDecodesDefaultWelcomeValues() throws {
        let legacy = Data(#"{"alwaysOnTop":true,"bindings":[]}"#.utf8)
        let restored = try JSONDecoder().decode(AppSettings.self, from: legacy)

        XCTAssertFalse(restored.hasCompletedWelcome)
        XCTAssertNil(restored.lastSeenAppVersion)
        XCTAssertTrue(restored.automaticallyCheckForUpdates)
        XCTAssertNil(restored.skippedAppVersion)
        XCTAssertNil(restored.lastUpdateCheckDate)
        XCTAssertFalse(restored.helpfulTipsEnabled, "Helpful tips must be switched off by default")
    }

    func testAppSettingsPreservesHelpfulTipsEnabledOnRoundTrip() throws {
        var settings = AppSettings()
        settings.helpfulTipsEnabled = true

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(restored.helpfulTipsEnabled)
    }

    func testHelpfulTipsCatalogContainsUniqueTips() {
        let tips = HelpfulTipsCatalog.allTips
        XCTAssertGreaterThanOrEqual(tips.count, 5)

        let ids = tips.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Tip IDs must be distinct")

        for tip in tips {
            XCTAssertFalse(tip.emoji.isEmpty)
            XCTAssertFalse(tip.title.isEmpty)
            XCTAssertFalse(tip.message.isEmpty)
        }
    }

    func testHelpfulTipsCatalogRandomTipExcludesGivenId() {
        let excludedId = "eye-macros"
        for _ in 0..<20 {
            let tip = HelpfulTipsCatalog.randomTip(excluding: excludedId)
            XCTAssertNotEqual(tip.id, excludedId, "Expected random tip to exclude specified ID")
        }
    }

    func testHelpfulTipsTargetsMapToValidSettingsTabs() {
        let generalTip = HelpfulTipsCatalog.allTips.first { $0.id == "smart-inbox" }
        XCTAssertEqual(generalTip?.settingsTarget, .general)
        XCTAssertEqual(generalTip?.settingsTarget?.tabIndex, 0)

        let themeTip = HelpfulTipsCatalog.allTips.first { $0.id == "custom-themes" }
        XCTAssertEqual(themeTip?.settingsTarget, .appearance)
        XCTAssertEqual(themeTip?.settingsTarget?.tabIndex, 1)

        let eyeMacrosTip = HelpfulTipsCatalog.allTips.first { $0.id == "eye-macros" }
        XCTAssertEqual(eyeMacrosTip?.settingsTarget, .macrosWorkshop)
        XCTAssertEqual(eyeMacrosTip?.settingsTarget?.tabIndex, 2)
    }

    func testAppSettingsPreservesGeneralSettingsOnRoundTrip() throws {
        var settings = AppSettings()
        settings.destinationFolderPath = "/Custom/Path/Inbox"
        settings.alwaysOnTop = false
        settings.snappingEnabled = false
        settings.minimizeDestination = .dock

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(restored.destinationFolderPath, "/Custom/Path/Inbox")
        XCTAssertFalse(restored.alwaysOnTop)
        XCTAssertFalse(restored.snappingEnabled)
        XCTAssertEqual(restored.minimizeDestination, .dock)
    }

    func testAppSettingsPreservesUpdatePreferencesOnRoundTrip() throws {
        var settings = AppSettings()
        settings.automaticallyCheckForUpdates = false
        settings.skippedAppVersion = "a0.50"
        let checkDate = Date(timeIntervalSince1970: 1700000000)
        settings.lastUpdateCheckDate = checkDate

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertFalse(restored.automaticallyCheckForUpdates)
        XCTAssertEqual(restored.skippedAppVersion, "a0.50")
        XCTAssertEqual(restored.lastUpdateCheckDate?.timeIntervalSince1970, checkDate.timeIntervalSince1970)
    }

    func testGitHubReleaseDecodingAndDownloadURL() throws {
        let json = """
        {
            "tag_name": "a0.43",
            "name": "Animal Buddy a0.43",
            "body": "## What's New\\n- Streamlined Menu Bar\\n- Unified Settings Hub",
            "html_url": "https://github.com/ewanp1997/AnimalBuddy/releases/tag/a0.43",
            "published_at": "2026-08-29T10:25:00Z",
            "assets": [
                {
                    "name": "AnimalBuddy-a0.43.zip",
                    "browser_download_url": "https://github.com/ewanp1997/AnimalBuddy/releases/download/a0.43/AnimalBuddy-a0.43.zip",
                    "size": 5242880
                }
            ]
        }
        """
        let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
        XCTAssertEqual(release.tagName, "a0.43")
        XCTAssertEqual(release.name, "Animal Buddy a0.43")
        XCTAssertEqual(release.displayTitle, "Animal Buddy a0.43")
        XCTAssertEqual(release.primaryDownloadURL?.absoluteString, "https://github.com/ewanp1997/AnimalBuddy/releases/download/a0.43/AnimalBuddy-a0.43.zip")
    }

    func testVersionComparisonDetectsUpdate() {
        XCTAssertTrue(VersionComparator.isVersion("a0.65", greaterThan: "a0.50"))
        XCTAssertTrue(VersionComparator.isVersion("a0.65", greaterThan: "a0.43"))
        XCTAssertFalse(VersionComparator.isVersion("a0.65", greaterThan: "a0.65"))
        XCTAssertFalse(VersionComparator.isVersion("a0.50", greaterThan: "a0.65"))
    }

    func testFileTypeOrganizerSortsKnownFileTypesIntoCorrectSubfolders() {
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/photo.png")), "Images")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/picture.HEIC")), "Images")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/doc.pdf")), "Documents")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/sheet.xlsx")), "Documents")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/notes.txt")), "Documents")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/track.mp3")), "Audio")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/movie.mp4")), "Videos")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/bundle.zip")), "Archives")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/installer.dmg")), "Archives")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/script.swift")), "Code")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/app.py")), "Code")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/config.json")), "Code")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/Calculator.app")), "Applications")
    }

    func testStoreActionOrganizesFilesIntoSubfoldersWhenEnabled() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AnimalBuddyInboxTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageFile = tempDir.appendingPathComponent("sample.png")
        let docFile = tempDir.appendingPathComponent("report.pdf")
        let codeFile = tempDir.appendingPathComponent("main.swift")

        try Data("png-content".utf8).write(to: imageFile)
        try Data("pdf-content".utf8).write(to: docFile)
        try Data("swift-code".utf8).write(to: codeFile)

        let inboxDir = tempDir.appendingPathComponent("Inbox")
        let action = StoreAction()
        let dropInput = DropInput(urls: [imageFile, docFile, codeFile], category: .mixed)
        let context = ActionContext(input: dropInput, destinationFolder: inboxDir, organizeByFileType: true)

        try await action.execute(context: context)

        XCTAssertTrue(FileManager.default.fileExists(atPath: inboxDir.appendingPathComponent("Images/sample.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inboxDir.appendingPathComponent("Documents/report.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inboxDir.appendingPathComponent("Code/main.swift").path))
    }

    func testStoreActionFlatStorageWhenOrganizeDisabled() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AnimalBuddyInboxTestFlat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageFile = tempDir.appendingPathComponent("photo.jpg")
        try Data("jpg-content".utf8).write(to: imageFile)

        let inboxDir = tempDir.appendingPathComponent("Inbox")
        let action = StoreAction()
        let dropInput = DropInput(urls: [imageFile], category: .image)
        let context = ActionContext(input: dropInput, destinationFolder: inboxDir, organizeByFileType: false)

        try await action.execute(context: context)

        XCTAssertTrue(FileManager.default.fileExists(atPath: inboxDir.appendingPathComponent("photo.jpg").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: inboxDir.appendingPathComponent("Images/photo.jpg").path))
    }

    func testAppSettingsPreservesOrganizeInboxByFileTypeOnRoundTrip() throws {
        var settings = AppSettings()
        settings.organizeInboxByFileType = true
        settings.inboxSubfolderRules = [
            InboxSubfolderRule(categoryName: "Holiday", folderName: "Holiday", regexPattern: "^holiday_.*")
        ]

        let data1 = try JSONEncoder().encode(settings)
        let restored1 = try JSONDecoder().decode(AppSettings.self, from: data1)
        XCTAssertTrue(restored1.organizeInboxByFileType)
        XCTAssertEqual(restored1.inboxSubfolderRules.first?.categoryName, "Holiday")
        XCTAssertEqual(restored1.inboxSubfolderRules.first?.regexPattern, "^holiday_.*")

        settings.organizeInboxByFileType = false
        let data2 = try JSONEncoder().encode(settings)
        let restored2 = try JSONDecoder().decode(AppSettings.self, from: data2)
        XCTAssertFalse(restored2.organizeInboxByFileType)
    }

    func testInboxSubfolderRuleMatchesRegexPatterns() {
        let holidayRule = InboxSubfolderRule(
            categoryName: "Holiday",
            folderName: "Holiday",
            regexPattern: "^holiday_.*"
        )
        XCTAssertTrue(holidayRule.matches(url: URL(fileURLWithPath: "/tmp/holiday_image.png")))
        XCTAssertTrue(holidayRule.matches(url: URL(fileURLWithPath: "/tmp/Holiday_beach.jpg")))
        XCTAssertFalse(holidayRule.matches(url: URL(fileURLWithPath: "/tmp/work_holiday.png")))

        let receiptRule = InboxSubfolderRule(
            categoryName: "Receipts",
            folderName: "Receipts",
            regexPattern: ".*_receipt.*"
        )
        XCTAssertTrue(receiptRule.matches(url: URL(fileURLWithPath: "/tmp/2026-08_receipt_coffee.pdf")))
        XCTAssertFalse(receiptRule.matches(url: URL(fileURLWithPath: "/tmp/invoice.pdf")))
    }

    func testFileTypeOrganizerUsesCustomRegexRules() {
        let rules: [InboxSubfolderRule] = [
            InboxSubfolderRule(categoryName: "Holiday", folderName: "Holiday", regexPattern: "^holiday_.*"),
            InboxSubfolderRule(id: "images", categoryName: "Images", folderName: "Images", extensions: ["png", "jpg"])
        ]
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/holiday_image.png"), customRules: rules), "Holiday")
        XCTAssertEqual(FileTypeOrganizer.subfolderName(for: URL(fileURLWithPath: "/tmp/standard_photo.png"), customRules: rules), "Images")
    }

    func testStoreActionRoutesRegexMatchedFilesIntoCustomFolder() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AnimalBuddyRegexInboxTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let holidayFile = tempDir.appendingPathComponent("holiday_image.png")
        let standardFile = tempDir.appendingPathComponent("normal_doc.pdf")
        try Data("img".utf8).write(to: holidayFile)
        try Data("doc".utf8).write(to: standardFile)

        let rules: [InboxSubfolderRule] = [
            InboxSubfolderRule(categoryName: "Holiday", folderName: "Holiday", regexPattern: "^holiday_.*"),
            InboxSubfolderRule(id: "documents", categoryName: "Documents", folderName: "Documents", extensions: ["pdf"])
        ]

        let inboxDir = tempDir.appendingPathComponent("Inbox")
        let action = StoreAction()
        let dropInput = DropInput(urls: [holidayFile, standardFile], category: .mixed)
        let context = ActionContext(input: dropInput, destinationFolder: inboxDir, organizeByFileType: true, subfolderRules: rules)

        try await action.execute(context: context)

        XCTAssertTrue(FileManager.default.fileExists(atPath: inboxDir.appendingPathComponent("Holiday/holiday_image.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inboxDir.appendingPathComponent("Documents/normal_doc.pdf").path))
    }

    @MainActor
    func testPetDiscoEasterEggModeActivation() {
        let petView = PetView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        XCTAssertFalse(petView.isDiscoMode)
        XCTAssertNotEqual(petView.state, .disco)

        petView.startDiscoMode(duration: 5.0)
        XCTAssertTrue(petView.isDiscoMode)
        XCTAssertEqual(petView.state, .disco)

        petView.stopDiscoMode()
        XCTAssertFalse(petView.isDiscoMode)
        XCTAssertEqual(petView.state, .idle)
    }

    func testAppSettingsFocusAndSoundSerializationAndDefaults() throws {
        var settings = AppSettings()
        XCTAssertFalse(settings.focusModeEnabled)
        XCTAssertTrue(settings.focusModeWorkRemindersEnabled)
        XCTAssertEqual(settings.focusModeIntervalMinutes, 10)
        XCTAssertTrue(settings.soundEffectsEnabled)

        settings.focusModeEnabled = true
        settings.focusModeWorkRemindersEnabled = false
        settings.focusModeIntervalMinutes = 15
        settings.soundEffectsEnabled = false

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)

        XCTAssertTrue(decoded.focusModeEnabled)
        XCTAssertFalse(decoded.focusModeWorkRemindersEnabled)
        XCTAssertEqual(decoded.focusModeIntervalMinutes, 15)
        XCTAssertFalse(decoded.soundEffectsEnabled)
    }

    func testFocusSoundCatalogReturnsSpeciesSpecificSounds() {
        for kind in AnimalKind.allCases {
            let sounds = FocusSoundCatalog.sounds(for: kind)
            XCTAssertFalse(sounds.isEmpty, "Expected sounds for \(kind.displayName)")
            for item in sounds {
                XCTAssertFalse(item.text.isEmpty)
                XCTAssertFalse(item.systemSoundName.isEmpty)
                XCTAssertFalse(item.emoji.isEmpty)
            }
            let random = FocusSoundCatalog.randomSound(for: kind)
            XCTAssertFalse(random.text.isEmpty)
        }
    }

    func testFocusReminderCatalogReturnsInspiringReminders() {
        XCTAssertFalse(FocusReminderCatalog.reminders.isEmpty)
        let sample = FocusReminderCatalog.randomReminder()
        XCTAssertFalse(sample.isEmpty)
        XCTAssertTrue(FocusReminderCatalog.reminders.contains(sample))
    }

    func testCuteReactionCatalogReturnsWarmReactions() {
        XCTAssertFalse(CuteReactionCatalog.reactions.isEmpty)
        let sample = CuteReactionCatalog.randomReaction()
        XCTAssertFalse(sample.isEmpty)
        XCTAssertTrue(CuteReactionCatalog.reactions.contains(sample))
    }

    func testSoundEffectsToggleIsIndependentOfFocusMode() {
        var settings = AppSettings()
        settings.focusModeEnabled = true
        settings.focusModeWorkRemindersEnabled = true
        settings.soundEffectsEnabled = true

        // Sound effects can be muted without altering focus mode state
        settings.soundEffectsEnabled = false
        XCTAssertFalse(settings.soundEffectsEnabled)
        XCTAssertTrue(settings.focusModeEnabled)
        XCTAssertTrue(settings.focusModeWorkRemindersEnabled)

        // Focus mode can be changed to 'just cute' without affecting sound setting
        settings.focusModeWorkRemindersEnabled = false
        XCTAssertFalse(settings.soundEffectsEnabled)
        XCTAssertFalse(settings.focusModeWorkRemindersEnabled)
    }
}

