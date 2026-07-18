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

    // MARK: - bgRange (column-range selection tint)

    func testBgRangeIsWidthNeutral() {
        // The frame is drawn with autowrap off, so a tinted row must measure
        // exactly as many columns as the untinted one or the redraw desyncs.
        let styled = Ansi.color("hello", 212) + " world"
        let out = Ansi.bgRange(styled, from: 2, to: 8, bg: 238)
        XCTAssertEqual(Ansi.width(out), Ansi.width(styled))
        XCTAssertEqual(Ansi.strip(out), "hello world")
    }

    func testBgRangePreservesUnderlyingColor() {
        // The whole point vs. the strip-and-reverse helpers: syntax colors
        // survive underneath the selection.
        let styled = Ansi.color("hello", 212) + " world"
        let out = Ansi.bgRange(styled, from: 0, to: 5, bg: 238)
        XCTAssertTrue(out.contains(Ansi.code(Ansi.fg(212))), out.debugDescription)
        XCTAssertTrue(out.contains(Ansi.code(Ansi.bg(238))), out.debugDescription)
    }

    func testBgRangeReassertsBackgroundAfterInternalReset() {
        // Styled runs end in a full reset, which also clears our tint — it has
        // to be put back or the highlight stops at the first styled segment.
        let styled = Ansi.color("ab", 212) + Ansi.color("cd", 45)
        let out = Ansi.bgRange(styled, from: 0, to: 4, bg: 238)
        let bgSeq = Ansi.code(Ansi.bg(238))
        XCTAssertGreaterThanOrEqual(out.components(separatedBy: bgSeq).count - 1, 2, out.debugDescription)
    }

    func testBgRangeOverridesContentBackground() {
        // Code cards and table headers set their own background mid-row. Without
        // re-asserting after every SGR sequence (not just resets) the content bg
        // would silently win and the selection would vanish over a code block.
        let styled = "ab" + Ansi.code(Ansi.bg(52)) + "cd" + Ansi.reset + "ef"
        let out = Ansi.bgRange(styled, from: 0, to: 6, bg: 238)
        let selBg = Ansi.code(Ansi.bg(238))
        let contentBg = Ansi.code(Ansi.bg(52))
        // The selection background is re-asserted after the content's own one.
        let afterContent = out.components(separatedBy: contentBg)
        XCTAssertEqual(afterContent.count, 2, out.debugDescription)
        XCTAssertTrue(afterContent[1].hasPrefix(selBg), out.debugDescription)
        XCTAssertEqual(Ansi.strip(out), "abcdef")
    }

    func testBgRangeLeavesOutsideColumnsUntinted() {
        let out = Ansi.bgRange("abcdef", from: 3, to: 5, bg: 238)
        let bgSeq = Ansi.code(Ansi.bg(238))
        // Nothing before column 3 is tinted.
        let head = out.components(separatedBy: bgSeq)[0]
        XCTAssertEqual(Ansi.strip(head), "abc")
        XCTAssertEqual(Ansi.strip(out), "abcdef")
    }

    func testBgRangeWideChars() {
        // Each CJK glyph is two columns; columns 2..<4 is exactly the middle one.
        let out = Ansi.bgRange("日本語", from: 2, to: 4, bg: 238)
        XCTAssertEqual(Ansi.width(out), 6)
        XCTAssertEqual(Ansi.strip(out), "日本語")
        // Highlight and copy use the same char-start-in-range rule, so the
        // tinted cells and the sliced text agree.
        XCTAssertEqual(Ansi.strip(Ansi.horizontalSlice("日本語", start: 2, width: 2)), "本")
    }

    func testBgRangePreservesHyperlink() {
        // Unlike `horizontalSlice`, nothing is cut here, so OSC 8 survives.
        let link = Ansi.hyperlink("text", url: "https://example.com")
        let out = Ansi.bgRange(link, from: 0, to: 4, bg: 238)
        XCTAssertTrue(out.contains("]8;;"), out.debugDescription)
        XCTAssertEqual(Ansi.strip(out), "text")
    }

    func testBgRangeDegenerateRangesReturnInput() {
        XCTAssertEqual(Ansi.bgRange("abc", from: 2, to: 2, bg: 238), "abc")
        XCTAssertEqual(Ansi.bgRange("abc", from: 5, to: 3, bg: 238), "abc")
        // A range past the end leaves the string visually untouched.
        XCTAssertEqual(Ansi.strip(Ansi.bgRange("abc", from: 9, to: 12, bg: 238)), "abc")
    }

    func testBgRangeUsesReverseVideoWithoutColor() {
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = true }
        let out = Ansi.bgRange("abcdef", from: 1, to: 3, bg: 238)
        XCTAssertTrue(out.contains("\u{1B}[7m"), out.debugDescription)
        XCTAssertEqual(Ansi.strip(out), "abcdef")
    }
}
