import XCTest
@testable import AgentpadCore

final class KeyComboTests: XCTestCase {
    func testPlainKey() {
        XCTAssertEqual(KeyComboParser.parse("return"), KeyCombo(keyCode: 36, flags: []))
        XCTAssertEqual(KeyComboParser.parse("esc"), KeyCombo(keyCode: 53, flags: []))
    }

    func testModifierCombo() {
        XCTAssertEqual(KeyComboParser.parse("shift+tab"), KeyCombo(keyCode: 48, flags: [.shift]))
        XCTAssertEqual(KeyComboParser.parse("cmd+`"), KeyCombo(keyCode: 50, flags: [.command]))
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(KeyComboParser.parse("Shift+Tab"), KeyComboParser.parse("shift+tab"))
    }

    func testUnknownKeyOrModifierIsNil() {
        XCTAssertNil(KeyComboParser.parse("hyper+x"))
        XCTAssertNil(KeyComboParser.parse("nonsense"))
        XCTAssertNil(KeyComboParser.parse(""))
    }

    func testSequence() {
        let seq = KeyComboParser.parseSequence("ctrl ctrl")
        XCTAssertEqual(seq, [KeyCombo(keyCode: 59, flags: []), KeyCombo(keyCode: 59, flags: [])])
    }

    func testSequenceWithBadElementIsNil() {
        XCTAssertNil(KeyComboParser.parseSequence("ctrl nonsense"))
        XCTAssertNil(KeyComboParser.parseSequence("   "))
    }

    func testIsModifierOnly() {
        XCTAssertTrue(KeyComboParser.isModifierOnly(KeyCombo(keyCode: 59, flags: [])))
        XCTAssertFalse(KeyComboParser.isModifierOnly(KeyCombo(keyCode: 36, flags: [])))
    }

    func testDigitsForPromptOptions() {
        XCTAssertEqual(KeyComboParser.parse("1"), KeyCombo(keyCode: 18, flags: []))
        XCTAssertEqual(KeyComboParser.parse("3"), KeyCombo(keyCode: 20, flags: []))
    }
}
