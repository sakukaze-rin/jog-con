import XCTest
@testable import JogConCore

final class ButtonMappingTests: XCTestCase {
    func testMigrationPreservesOrderAndAssignments() {
        let mappings = ButtonMapping.migrate(["无", "Button B", "Button X", "无", "无", "Button A"])
        XCTAssertEqual(mappings.count, 6)
        XCTAssertEqual(mappings[1].input, "Button B")
        XCTAssertEqual(mappings[1].action, .source)
        XCTAssertEqual(mappings[2].action, .timeline)
        XCTAssertEqual(mappings[5].action.mcuNote, 0x5D)
    }
    func testCustomCombinationPersistsAndPresetActionsAreExecutable() throws {
        let shortcut = KeyShortcut(keyCode: 40, label: "K", command: true, shift: true, option: true, control: true)
        let mapping = ButtonMapping(input: "Button B", shortcut: shortcut)
        XCTAssertEqual(try JSONDecoder().decode(ButtonMapping.self, from: JSONEncoder().encode(mapping)), mapping)
        XCTAssertEqual(shortcut.display, "⌃⌥⇧⌘K")
        for action in ButtonAction.allCases where action != .custom {
            XCTAssertTrue(action.shortcut != nil || action.mcuNote != nil)
        }
        XCTAssertEqual(ButtonAction.nextFrame.shortcut?.keyCode, 124)
        XCTAssertEqual(ButtonAction.previousFrame.shortcut?.keyCode, 123)
    }
}
