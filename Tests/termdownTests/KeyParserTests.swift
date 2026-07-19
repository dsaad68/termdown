import XCTest
@testable import termdown

/// Tests for the terminal key-sequence decoder. `Terminal.decodeKey` is the pure
/// core of `readKey`, taking the first byte plus a `next` closure that yields
/// further bytes — so we can feed exact byte sequences without a real terminal.
final class KeyParserTests: XCTestCase {

    /// Decode a full byte sequence: the first byte seeds `decodeKey`, the rest are
    /// served in order by `next` (returning nil once exhausted, like a timeout).
    private func decode(_ bytes: [UInt8]) -> Terminal.Key {
        let rest = Array(bytes.dropFirst())
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

    func testCtrlS() {
        XCTAssertEqual(decode([0x13]), .ctrlS)
    }

    func testShiftArrows() {
        // Modified arrows: ESC [ 1 ; 2 A/B  (modifier 2 = Shift)
        XCTAssertEqual(decode(csi("1;2A")), .shiftUp)
        XCTAssertEqual(decode(csi("1;2B")), .shiftDown)
        // Other modifiers fall back to the plain arrow.
        XCTAssertEqual(decode(csi("1;5A")), .up)
        XCTAssertEqual(decode(csi("1;2C")), .right)
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
        // Other buttons (e.g. right = 2) are ignored.
        XCTAssertEqual(decode(csi("<2;10;5M")), .other)
        XCTAssertEqual(decode(csi("<2;10;5m")), .other)
    }

    func testMouseRelease() {
        // Release ('m') on the left button is its own event — it ends a drag.
        XCTAssertEqual(decode(csi("<0;10;5m")), .mouseRelease(x: 10, y: 5))
    }

    func testMouseDrag() {
        // Motion bit (32) set with the left button held = a drag.
        XCTAssertEqual(decode(csi("<32;10;5M")), .mouseDrag(x: 10, y: 5))
        XCTAssertEqual(decode(csi("<32;7;3m")), .mouseDrag(x: 7, y: 3))
        // Motion with a non-left button is still ignored (34 = right + motion).
        XCTAssertEqual(decode(csi("<34;10;5M")), .other)
    }

    func testMouseModifiersAreMasked() {
        // Modifier bits (Shift 4 / Alt 8 / Ctrl 16) must not hide the button.
        XCTAssertEqual(decode(csi("<4;10;5M")), .mouseClick(x: 10, y: 5))
        XCTAssertEqual(decode(csi("<16;10;5M")), .mouseClick(x: 10, y: 5))
        // Wheel with a modifier still scrolls (68 = 64 | 4 = shift + wheel up).
        XCTAssertEqual(decode(csi("<68;1;1M")), .mouseScroll(-3))
        XCTAssertEqual(decode(csi("<69;1;1M")), .mouseScroll(3))
    }

    func testHorizontalWheelIsIgnored() {
        // 66/67 are wheel-left/right (a tilt wheel or a two-finger swipe). They
        // carry the wheel bit, so masking the button to `& 3` read them as 2/3
        // and scrolled the document *down* for both directions.
        XCTAssertEqual(decode(csi("<66;10;5M")), .other)
        XCTAssertEqual(decode(csi("<67;10;5M")), .other)
        // …including with a modifier held (70 = 66 | 4).
        XCTAssertEqual(decode(csi("<70;10;5M")), .other)
    }

    func testWheelReleaseIsNotAClick() {
        // A wheel event only ever presses; an 'm' must not fall through to the
        // left-button path and surface as a phantom release.
        XCTAssertEqual(decode(csi("<64;10;5m")), .other)
    }

    // MARK: - Unknown sequences

    func testUnknownCsiIsOther() {
        XCTAssertEqual(decode(csi("3~")), .other)   // Delete — not mapped
        XCTAssertEqual(decode(csi("99X")), .other)
    }
}
