import XCTest
@testable import termdownCore

/// Edge cases for the renderer that complement the golden snapshots with
/// targeted structural invariants.
final class AnsiRendererEdgeTests: XCTestCase {

    private func renderPlain(_ md: String, width: Int = 80) -> [String] {
        AnsiRenderer(width: width, theme: .dark).render(md).lines.map { Ansi.strip($0) }
    }

    func testNestedListRendersBothLevels() {
        let md = "- outer\n  - inner\n    1. deep\n"
        let joined = renderPlain(md).joined(separator: "\n")
        XCTAssertTrue(joined.contains("outer"))
        XCTAssertTrue(joined.contains("inner"))
        XCTAssertTrue(joined.contains("deep"))
    }

    func testTaskListShowsCheckboxes() {
        let md = "- [ ] todo\n- [x] done\n"
        let joined = renderPlain(md).joined(separator: "\n")
        XCTAssertTrue(joined.contains("todo"))
        XCTAssertTrue(joined.contains("done"))
        XCTAssertTrue(joined.contains("\u{2610}") || joined.contains("\u{2611}"),
                      "expected a checkbox glyph")
    }

    func testStrikethroughTextSurvives() {
        let joined = renderPlain("~~gone~~ kept").joined(separator: "\n")
        XCTAssertTrue(joined.contains("gone"))
        XCTAssertTrue(joined.contains("kept"))
    }

    func testTableRowsAreWidthAligned() {
        // Every framed table row (those containing │) must share one display width
        // — the property most at risk from wide CJK cells.
        let md = "| name | val |\n|------|-----|\n| 日本語 | x |\n| a | 中文 |\n"
        let tableLines = renderPlain(md).filter { $0.contains("\u{2502}") || $0.contains("\u{250C}") || $0.contains("\u{2514}") }
        let widths = Set(tableLines.map { Ansi.width($0) })
        XCTAssertEqual(widths.count, 1, "table rows differ in width: \(widths)")
    }

    func testMalformedInputDoesNotCrash() {
        let md = "```swift\nlet x = 1\nno closing fence\n\n## still parses\n"
        let lines = renderPlain(md)
        XCTAssertFalse(lines.joined().isEmpty)
        XCTAssertTrue(lines.joined(separator: "\n").contains("let x = 1"))
    }

    func testVeryLongUnbrokenWordHardSplits() {
        // A word longer than the column must wrap (hard-split) rather than overflow.
        let word = String(repeating: "x", count: 200)
        let lines = renderPlain(word, width: 40)
        XCTAssertTrue(lines.count >= 2, "expected the long word to wrap across lines")
        XCTAssertTrue(lines.allSatisfy { Ansi.width($0) <= 40 })
    }

    func testEmptyDocumentRendersWithoutCrash() {
        XCTAssertNotNil(AnsiRenderer(width: 80, theme: .dark).render(""))
    }
}
