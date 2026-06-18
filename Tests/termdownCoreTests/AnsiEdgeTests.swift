import XCTest
@testable import termdownCore

/// Edge cases for the ANSI width / strip / pad / truncate helpers beyond the
/// basics covered in AnsiTests.
final class AnsiEdgeTests: XCTestCase {

    func testHyperlinkWidthCountsVisibleTextOnly() {
        // OSC 8 hyperlink: only the display text contributes to width.
        let link = Ansi.hyperlink("text", url: "https://example.com/very/long/path")
        XCTAssertEqual(Ansi.width(link), 4)
        XCTAssertEqual(Ansi.strip(link), "text")
    }

    func testCombiningMarkIsZeroWidth() {
        // "e" + combining acute accent renders in one cell.
        XCTAssertEqual(Ansi.width("e\u{0301}"), 1)
    }

    func testZeroWidthSpace() {
        XCTAssertEqual(Ansi.width("a\u{200B}b"), 2)   // ZWSP contributes 0
    }

    func testStripMultipleSGRCodes() {
        let s = "\u{1B}[1;38;5;212mhi\u{1B}[0m there"
        XCTAssertEqual(Ansi.strip(s), "hi there")
    }

    func testPadWideCharToOddWidth() {
        // "日" is 2 cells wide; padding to 3 yields width exactly 3.
        XCTAssertEqual(Ansi.width(Ansi.pad("日", to: 3)), 3)
    }

    func testTruncateWideCharsKeepsWidthBound() {
        let out = Ansi.truncate("日本語テスト", to: 5)
        XCTAssertLessThanOrEqual(Ansi.width(out), 5)
        XCTAssertTrue(out.hasSuffix("\u{2026}"))   // ellipsis appended
    }

    func testPadNeverShrinks() {
        let wide = "already wider than target"
        XCTAssertEqual(Ansi.pad(wide, to: 5), wide)   // returns input untouched
    }

    func testHorizontalSlicePreservesVisibleColumns() {
        let plain = "abcdefgh"
        XCTAssertEqual(Ansi.horizontalSlice(plain, start: 2, width: 3), "cde")
    }
}
