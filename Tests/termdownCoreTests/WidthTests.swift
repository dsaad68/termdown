import XCTest
@testable import termdownCore

/// Display width measured against what terminals actually draw.
///
/// This is the oracle the frame sweep cannot be: that test measures rows with
/// `Ansi.width` and asserts they pad to `cols`, which holds no matter how wrong
/// the table is. Only explicit per-sequence expectations catch a bad table.
final class WidthTests: XCTestCase {

    override func tearDown() {
        Ansi.emojiWidthMode = .cluster
        super.tearDown()
    }

    // MARK: - Sequences that must measure 2

    func testZWJSequencesAreOneGlyph() {
        // Summing scalars counted 6 and 8 here — the components are joined into
        // a single glyph, so the row padded short and the frame's right edge
        // drifted by four columns.
        XCTAssertEqual(Ansi.width("👨‍👩‍👧"), 2)
        XCTAssertEqual(Ansi.width("👨‍👩‍👧‍👦"), 2)
        XCTAssertEqual(Ansi.width("👩‍💻"), 2)
        XCTAssertEqual(Ansi.width("🏳️‍🌈"), 2)
    }

    func testSkinToneModifiersAddNoColumn() {
        XCTAssertEqual(Ansi.width("👍🏻"), 2)
        XCTAssertEqual(Ansi.width("👍🏽"), 2)
        XCTAssertEqual(Ansi.width("👍🏿"), 2)
    }

    /// The under-count, and the one that bites the shipped `:shortcode:` map —
    /// 31 of its 220 entries expand to VS16 sequences whose base is narrow.
    func testVS16SequencesRenderWide() {
        XCTAssertEqual(Ansi.width("❤️"), 2)
        XCTAssertEqual(Ansi.width("⚠️"), 2)
        XCTAssertEqual(Ansi.width("✔️"), 2)
        XCTAssertEqual(Ansi.width("➡️"), 2)
        XCTAssertEqual(Ansi.width("⌨️"), 2)
        XCTAssertEqual(Ansi.width("✏️"), 2)
    }

    func testRegionalIndicatorFlags() {
        XCTAssertEqual(Ansi.width("🇺🇸"), 2)
        XCTAssertEqual(Ansi.width("🇩🇪"), 2)
    }

    func testPlainEmojiUnchanged() {
        XCTAssertEqual(Ansi.width("😀"), 2)
        XCTAssertEqual(Ansi.width("✅"), 2)   // sub-U+1F300, Emoji_Presentation=Yes
        XCTAssertEqual(Ansi.width("⭐"), 2)
        XCTAssertEqual(Ansi.width("⚡"), 2)
    }

    // MARK: - Things that must stay narrow

    /// The trap: these are renderer-generated task-list checkboxes present in
    /// two committed goldens. They are `Emoji_Presentation=No` and one column
    /// wide — a naive "looks like an emoji, call it 2" rule breaks both.
    func testTaskListCheckboxesStayNarrow() {
        XCTAssertEqual(Ansi.width("\u{2610}"), 1)   // ☐
        XCTAssertEqual(Ansi.width("\u{2611}"), 1)   // ☑
        XCTAssertEqual(Ansi.width("\u{2197}"), 1)   // ↗
        XCTAssertEqual(Ansi.width("\u{25BA}"), 1)   // ►
    }

    func testAsciiAndCJKUnchanged() {
        XCTAssertEqual(Ansi.width("hello"), 5)
        XCTAssertEqual(Ansi.width("日本語"), 6)
        XCTAssertEqual(Ansi.width("한국어"), 6)
        XCTAssertEqual(Ansi.width("ｆｕｌｌ"), 8)   // fullwidth forms
    }

    /// Marks outside Latin were scored 1 each, so every Hebrew, Arabic,
    /// Devanagari and Thai document over-counted and padded short.
    func testCombiningMarksAreZeroWidthInEveryScript() {
        XCTAssertEqual(Ansi.width("e\u{0301}"), 1)          // Latin
        XCTAssertEqual(Ansi.width("\u{05D0}\u{05B7}"), 1)   // Hebrew alef + patah
        XCTAssertEqual(Ansi.width("\u{0627}\u{064B}"), 1)   // Arabic alef + fathatan
        XCTAssertEqual(Ansi.width("\u{0915}\u{0941}"), 1)   // Devanagari ka + u
        XCTAssertEqual(Ansi.width("\u{0E01}\u{0E34}"), 1)   // Thai ko kai + sara i
    }

    // MARK: - charWidth must agree with width

    /// `charWidth` is the per-cell advance in `horizontalSlice` and `bgRange`.
    /// If it disagrees with `width`, a selection tint covers different cells
    /// than the copied text.
    func testCharWidthAgreesWithWidth() {
        for s in ["👨‍👩‍👧", "👍🏽", "❤️", "🇺🇸", "😀", "日", "a", "\u{2611}", "e\u{0301}"] {
            let viaChars = s.reduce(0) { $0 + Ansi.charWidth($1) }
            XCTAssertEqual(viaChars, Ansi.width(s), "disagreement on \(s.debugDescription)")
        }
    }

    // MARK: - Escape hatch

    func testScalarModeRestoresLegacySumming() {
        Ansi.emojiWidthMode = .scalar
        XCTAssertEqual(Ansi.width("👨‍👩‍👧"), 6)
        XCTAssertEqual(Ansi.width("👍🏽"), 4)
        // Plain content is identical in both modes.
        XCTAssertEqual(Ansi.width("日本語"), 6)
        XCTAssertEqual(Ansi.width("hello"), 5)
    }

    // MARK: - Padding and slicing follow the width

    func testPadUsesClusterWidth() {
        let padded = Ansi.pad("👨‍👩‍👧", to: 10)
        XCTAssertEqual(Ansi.width(padded), 10)
    }

    func testHorizontalSliceAdvancesByCluster() {
        // "👍🏽" occupies columns 0..<2, so a slice at column 2 starts after it.
        XCTAssertEqual(Ansi.strip(Ansi.horizontalSlice("👍🏽ab", start: 2, width: 2)), "ab")
    }
}
