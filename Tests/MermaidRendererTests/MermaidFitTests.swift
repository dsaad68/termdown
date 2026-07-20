import XCTest
@testable import MermaidRenderer

/// Width fitting: a diagram embedded in a document has to live inside the text
/// column. Before `maxWidth` existed the layout always ran at its natural size,
/// and anything wider than the column was truncated downstream.
final class MermaidFitTests: XCTestCase {

    /// A left-to-right chain with labels far too long for a narrow column.
    private let wideFlow = """
    flowchart LR
        A[formula row: input + gold formula] --> B[teacher recast question]
        B --> C[verify deterministic components and sub-queries]
        C -->|fail, retries < 2 with feedback| B
        C --> D[Done]
    """

    private let simple = """
    flowchart TD
        A[Start] --> B[Middle]
        B --> C[End]
    """

    private func render(_ source: String, maxWidth: Int?) -> [String] {
        var options = MermaidOptions()
        options.colorEnabled = false
        options.maxWidth = maxWidth
        guard let rows = Mermaid.render(source, options: options) else {
            XCTFail("diagram failed to render")
            return []
        }
        return rows
    }

    private func widest(_ rows: [String]) -> Int {
        rows.reduce(0) { max($0, DisplayWidth.stringWidth($1)) }
    }

    // MARK: - The budget is respected

    func testWideDiagramFitsARangeOfBudgets() {
        for budget in [60, 70, 80, 100, 120] {
            let rows = render(wideFlow, maxWidth: budget)
            XCTAssertLessThanOrEqual(widest(rows), budget,
                                     "diagram overflowed a \(budget)-column budget")
        }
    }

    func testAlreadyNarrowDiagramIsUnchangedByAGenerousBudget() {
        let natural = render(simple, maxWidth: nil)
        XCTAssertEqual(render(simple, maxWidth: 200), natural)
    }

    /// The whole point of defaulting to nil: an unbudgeted render must be
    /// byte-for-byte what it was before fitting existed. The upstream
    /// mermaid-ascii goldens depend on this.
    func testNilBudgetLeavesLayoutUntouched() {
        let unbounded = render(wideFlow, maxWidth: nil)
        XCTAssertGreaterThan(widest(unbounded), 80, "fixture is no longer wide enough to be a test")
        XCTAssertEqual(render(wideFlow, maxWidth: 0), unbounded, "0 must mean unconstrained, not empty")
    }

    /// Fitting may only ever narrow a diagram.
    func testFittingNeverWidens() {
        let natural = widest(render(wideFlow, maxWidth: nil))
        for budget in [40, 60, 80] {
            XCTAssertLessThanOrEqual(widest(render(wideFlow, maxWidth: budget)), natural)
        }
    }

    /// A budget too small for any layout still returns the narrowest attempt
    /// rather than failing or hanging — the caller clips what is left.
    func testImpossiblyNarrowBudgetStillReturnsSomething() {
        let rows = render(wideFlow, maxWidth: 10)
        XCTAssertFalse(rows.isEmpty)
        XCTAssertLessThan(widest(rows), widest(render(wideFlow, maxWidth: nil)))
    }

    // MARK: - Label wrapping

    func testWrapBreaksOnWordBoundaries() {
        let label = newGraphLabel("verify deterministic components")
        let wrapped = label.wrapped(to: 14)
        XCTAssertLessThanOrEqual(wrapped.width, 14)
        for line in wrapped.lines {
            XCTAssertFalse(line.hasPrefix(" "), "leading space in \(line)")
            XCTAssertFalse(line.hasSuffix(" "), "trailing space in \(line)")
        }
        // Words survive intact when they fit.
        XCTAssertTrue(wrapped.lines.contains { $0.contains("verify") })
    }

    func testWrapPreservesExplicitLineBreaks() {
        let label = newGraphLabel("first<br>second")
        XCTAssertEqual(label.lines, ["first", "second"])
        // A cap wider than both lines must not join them.
        XCTAssertEqual(label.wrapped(to: 40).lines, ["first", "second"])
    }

    func testWrapHardSplitsAWordLongerThanTheCap() {
        let wrapped = newGraphLabel("supercalifragilistic").wrapped(to: 8)
        XCTAssertLessThanOrEqual(wrapped.width, 8)
        XCTAssertEqual(wrapped.lines.joined(), "supercalifragilistic", "no characters lost")
    }

    func testWrapIsANoOpWhenTheLabelAlreadyFits() {
        let label = newGraphLabel("short")
        XCTAssertEqual(label.wrapped(to: 40).lines, label.lines)
    }

    /// Splitting must measure display width, or a wide glyph lands half in and
    /// half out of the box and every row after it is off by a column.
    func testWrapMeasuresWideGlyphsByDisplayWidth() {
        let wrapped = newGraphLabel("日本語のテキストです").wrapped(to: 8)
        for line in wrapped.lines {
            XCTAssertLessThanOrEqual(DisplayWidth.stringWidth(line), 8)
        }
        XCTAssertEqual(wrapped.lines.joined(), "日本語のテキストです")
    }

    func testWrapToZeroOrNegativeIsInert() {
        let label = newGraphLabel("some text here")
        XCTAssertEqual(label.wrapped(to: 0).lines, label.lines)
        XCTAssertEqual(label.wrapped(to: -5).lines, label.lines)
    }

    // MARK: - Direction fallback

    /// A long horizontal chain cannot be rescued by wrapping alone — width grows
    /// with the whole chain. Stacking it top-down is the last resort, and it is
    /// used only when it actually fits.
    func testLongHorizontalChainIsStackedWhenNothingElseFits() {
        let rows = render(wideFlow, maxWidth: 60)
        XCTAssertLessThanOrEqual(widest(rows), 60)
        // Stacked, so it is now taller than it is wide.
        XCTAssertGreaterThan(rows.count, 20)
    }

    /// A diagram that is already top-down has no direction left to fall back to;
    /// it must still terminate and stay within budget where it can.
    func testTopDownDiagramNeedsNoFallback() {
        let rows = render(simple, maxWidth: 40)
        XCTAssertLessThanOrEqual(widest(rows), 40)
    }
}
