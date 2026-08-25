import XCTest
import UniformTypeIdentifiers
@testable import AnimalBuddy

final class AnimalBuddyTests: XCTestCase {
    func testModifierBindingSelectsConvertImage() { var settings = AppSettings(); settings.bindings = [.init(category: .image, modifiers: .option, actionID: "convert-image")]; let registry = ActionRegistry(settings: settings); let input = DropInput(category: .image); XCTAssertEqual(registry.action(for: input, modifiers: .option)?.descriptor.identifier, "convert-image") }
    func testURLClassification() { XCTAssertEqual(InputClassifier.classify(urls: [], text: "https://example.com").category, .url) }
    func testImageTypeClassification() throws { let url = URL(fileURLWithPath: "/tmp/photo.png"); XCTAssertEqual(InputClassifier.classify(urls: [url]).category, .image) }
    func testSafeDestinationNameAvoidsCollision() throws { let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("animal-buddy-test-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: folder) }; let source = folder.appendingPathComponent("photo.png"); FileManager.default.createFile(atPath: source.path, contents: Data()); XCTAssertTrue(SafeFileOperations.uniqueURL(for: source, in: folder).lastPathComponent.contains("2")) }
    func testPupilOffsetIsClamped() { let offset = PetView.clampPupilOffset(NSPoint(x: 100, y: 0)); XCTAssertEqual(offset.x, 5, accuracy: 0.001); XCTAssertEqual(offset.y, 0, accuracy: 0.001) }
    func testDistanceToRectIsZeroInsideAndMeasuredOutside() { let rect = NSRect(x: 10, y: 10, width: 20, height: 20); XCTAssertEqual(PetWindowController.distance(from: NSPoint(x: 20, y: 20), to: rect), 0); XCTAssertEqual(PetWindowController.distance(from: NSPoint(x: 40, y: 20), to: rect), 10) }
}
