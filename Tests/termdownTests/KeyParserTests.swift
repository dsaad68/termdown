import XCTest
@testable import termdown

/// Tests for the terminal key-sequence decoder. `Terminal.decodeKey` is the pure
/// core of `readKey`, taking the first byte plus a `next` closure that yields
/// further bytes — so we can feed exact byte sequences without a real terminal.
final class KeyParserTests: XCTestCase {

    /// Decode a full byte sequence: the first byte seeds `decodeKey`, the rest are
    /// served in order by `next` (returning nil once exhausted, like a timeout).
    private func decode(_ bytes: [UInt8]) -> Terminal.Key {
        var rest = Array(bytes.dropFirst())
        var i = 0
        return Terminal.decodeKey(first: bytes[0]) { _ in
            guard i < rest.count else { return nil }
            defer { i += 1 }
            return rest[i]
        }
    }

    private func csi(_ tail: String) -> [UInt8] { [0x1B, 0x5B] + Array(tail.utf8) }

    // MARK: - Plain keys

    func testEnter() {
        XCTAssertEqual(decode([0x0D]), .enter)
        XCTAssertEqual(decode([0x0A]), .enter)
    }

    func testTabAndBackspace() {
        XCTAssertEqual(decode([0x09]), .tab)
        XCTAssertEqual(decode([0x7F]), .backspace)
        XCTAssertEqual(decode([0x08]), .backspace)
    }

    func testCtrlL() {
        XCTAssertEqual(decode([0x0C]), .ctrlL)
    }

    /// Ctrl-C (0x03) must NOT decode to the letter "c" — otherwise a typed "c"
    /// and Ctrl-C would be indistinguishable, which made "c" quit the file
    /// finder. Real Ctrl-C is delivered as SIGINT, so the byte just falls to
    /// `.other` and the literal "c" stays a normal character.
    func testCtrlCIsNotLetterC() {
        XCTAssertEqual(decode([0x03]), .other)
        XCTAssertEqual(decode([UInt8(ascii: "c")]), .char("c"))
        XCTAssertEqual(decode([UInt8(ascii: "q")]), .char("q"))
    }

    func testPrintableChar() {
        XCTAssertEqual(decode([UInt8(ascii: "a")]), .char("a"))
        XCTAssertEqual(decode([UInt8(ascii: "Z")]), .char("Z"))
        XCTAssertEqual(decode([UInt8(ascii: "}")]), .char("}"))
    }

    func testBareEscape() {
        // ESC with nothing following (next returns nil) is a bare Escape.
        XCTAssertEqual(decode([0x1B]), .escape)
    }

    // MARK: - Arrow / navigation sequences

    func testArrows() {
        XCTAssertEqual(decode(csi("A")), .up)
        XCTAssertEqual(decode(csi("B")), .down)
        XCTAssertEqual(decode(csi("C")), .right)
        XCTAssertEqual(decode(csi("D")), .left)
    }

    func testSS3Arrows() {
        // SS3 form: ESC O A  (application cursor keys)
        XCTAssertEqual(decode([0x1B, 0x4F, 0x41]), .up)
        XCTAssertEqual(decode([0x1B, 0x4F, 0x44]), .left)
    }

    func testHomeEndShiftTab() {
        XCTAssertEqual(decode(csi("H")), .home)
        XCTAssertEqual(decode(csi("F")), .end)
        XCTAssertEqual(decode(csi("Z")), .backTab)
    }

    func testTildeNavigation() {
        XCTAssertEqual(decode(csi("1~")), .home)
        XCTAssertEqual(decode(csi("7~")), .home)
        XCTAssertEqual(decode(csi("4~")), .end)
        XCTAssertEqual(decode(csi("8~")), .end)
        XCTAssertEqual(decode(csi("5~")), .pageUp)
        XCTAssertEqual(decode(csi("6~")), .pageDown)
    }

    // MARK: - Shift+Enter (modifyOtherKeys / kitty)

    func testShiftEnterModifyOtherKeys() {
        // xterm modifyOtherKeys: ESC [ 27 ; 2 ; 13 ~  → Shift+Enter
        XCTAssertEqual(decode(csi("27;2;13~")), .shiftEnter)
        // modifier 1 (none) → plain Enter
        XCTAssertEqual(decode(csi("27;1;13~")), .enter)
    }

    func testShiftEnterKitty() {
        // kitty keyboard protocol: ESC [ 13 ; 2 u  → Shift+Enter
        XCTAssertEqual(decode(csi("13;2u")), .shiftEnter)
        // ESC [ 13 u → plain Enter
        XCTAssertEqual(decode(csi("13u")), .enter)
    }

    // MARK: - Mouse (SGR 1006)

    func testMouseScroll() {
        // ESC [ < 64 ; x ; y M  → scroll up;  65 → scroll down
        XCTAssertEqual(decode(csi("<64;10;5M")), .mouseScroll(-3))
        XCTAssertEqual(decode(csi("<65;10;5M")), .mouseScroll(3))
    }

    func testMouseClick() {
        // Left-button (0) press carries 1-based (col, row).
        XCTAssertEqual(decode(csi("<0;10;5M")), .mouseClick(x: 10, y: 5))
        XCTAssertEqual(decode(csi("<0;132;48M")), .mouseClick(x: 132, y: 48))
        // Release ('m') is not a click.
        XCTAssertEqual(decode(csi("<0;10;5m")), .other)
        // Other buttons (e.g. right = 2) are ignored.
        XCTAssertEqual(decode(csi("<2;10;5M")), .other)
    }

    // MARK: - Unknown sequences

    func testUnknownCsiIsOther() {
        XCTAssertEqual(decode(csi("3~")), .other)   // Delete — not mapped
        XCTAssertEqual(decode(csi("99X")), .other)
    }
}
