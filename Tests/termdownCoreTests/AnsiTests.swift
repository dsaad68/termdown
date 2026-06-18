import XCTest
@testable import termdownCore

final class AnsiTests: XCTestCase {

    func testWidthAscii() {
        XCTAssertEqual(Ansi.width("hello"), 5)
        XCTAssertEqual(Ansi.width("world"), 5)
    }

    func testWidthCJK() {
        XCTAssertEqual(Ansi.width("你好"), 4) // Each CJK char is 2 columns
        XCTAssertEqual(Ansi.width("日本語"), 6)
    }

    func testWidthEmoji() {
        XCTAssertEqual(Ansi.width("😀"), 2) // Emoji is typically 2 columns
        XCTAssertEqual(Ansi.width("🎉"), 2)
    }

    func testWidthMixed() {
        XCTAssertEqual(Ansi.width("Hello你好"), 9) // 5 + 4 (each CJK char is 2)
        XCTAssertEqual(Ansi.width("A😀B"), 4) // 1 + 2 + 1 (emoji is 2)
    }

    func testStripBasic() {
        let styled = "\u{1B}[38;5;212mHello\u{1B}[0m"
        let stripped = Ansi.strip(styled)
        XCTAssertEqual(stripped, "Hello")
    }

    func testStripMultiple() {
        let styled = "\u{1B}[1m\u{1B}[38;5;212mBold and colored\u{1B}[0m"
        let stripped = Ansi.strip(styled)
        XCTAssertEqual(stripped, "Bold and colored")
    }

    func testStripHyperlinks() {
        let link = "\u{1B}]8;;https://example.com\u{1B}\\Click here\u{1B}]8;;\u{1B}\\"
        let stripped = Ansi.strip(link)
        XCTAssertEqual(stripped, "Click here")
    }

    func testWidthWithStyles() {
        let styled = "\u{1B}[38;5;212mHello\u{1B}[0m"
        XCTAssertEqual(Ansi.width(styled), 5) // Should count visible width only
    }

    func testTruncate() {
        let text = "Hello World"
        XCTAssertEqual(Ansi.truncate(text, to: 5), "Hell…")
        XCTAssertEqual(Ansi.truncate(text, to: 10), "Hello Wor…")
        XCTAssertEqual(Ansi.truncate(text, to: 20), "Hello World") // No truncation
    }

    func testTruncateWithCJK() {
        let text = "你好世界"
        XCTAssertEqual(Ansi.truncate(text, to: 4), "你…")
        XCTAssertEqual(Ansi.truncate(text, to: 6), "你好…")
    }

    func testPad() {
        XCTAssertEqual(Ansi.pad("hi", to: 5), "hi   ")
        XCTAssertEqual(Ansi.pad("hi", to: 5, align: .right), "   hi") // 3 spaces to reach width 5
        XCTAssertEqual(Ansi.pad("hi", to: 5, align: .center), " hi  ")
    }

    func testPadWithStyles() {
        let styled = "\u{1B}[38;5;212mhi\u{1B}[0m"
        let padded = Ansi.pad(styled, to: 5)
        // Should pad to visible width, preserving styles
        XCTAssertTrue(padded.hasSuffix("   "))
    }
}
