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

    // MARK: - Every rung of the ladder is reachable

    /// Two adjacent rungs render identically whenever no label is near the
    /// tighter cap — rungs 4 and 5 also share a padding, so they tie outright.
    /// Treating that plateau as "the floor" abandoned the ladder before its last
    /// and narrowest rung, and the caller then showed raw source for a diagram
    /// that had a fitting layout one step further down.
    func testAPlateauDoesNotAbandonTheLadder() {
        // Labels are all ≤13 columns, so the cap does nothing; only the padding
        // moves, and it takes the final rung to reach 32.
        let plateau = """
        flowchart TD
            A[Start here] --> B[Left branch]
            A --> C[Right branch]
            B --> D[The end]
            C --> D
        """
        XCTAssertLessThanOrEqual(widest(render(plateau, maxWidth: 32)), 32)
    }

    // MARK: - Subgraphs

    /// `setSubgraphs` builds its own labels from the parse output, so wrapping
    /// only `g.nodes` beforehand left a subgraph title untouched by every rung.
    /// A diagram held open by a long title never narrowed at all.
    func testSubgraphTitlesWrapToo() {
        let titled = """
        flowchart TD
            subgraph A very long subgraph title that will never be wrapped at all
            X[One] --> Y[Two]
            end
        """
        XCTAssertGreaterThan(widest(render(titled, maxWidth: nil)), 40, "fixture is not wide enough to test")
        XCTAssertLessThanOrEqual(widest(render(titled, maxWidth: 40)), 40)
    }

    /// A subgraph frame is drawn in the gap beside its boxes. Squeezed to a
    /// single column it lands in the same column as the node walls and the
    /// renderer merges the two into `┤`/`├` tees — a diagram that fits the
    /// budget and is unreadable. Fitting is judged on width alone, so the floor
    /// has to be part of the plan rather than something the search discovers.
    func testSubgraphFramesKeepTheirOwnColumn() {
        let framed = """
        flowchart LR
            A[Ingest documents] --> B
            subgraph P[Pipeline stage]
            B[Chunk and embed] --> C[Index vectors]
            end
            C --> D[Serve queries]
        """
        for budget in stride(from: 40, through: 110, by: 2) {
            let joined = render(framed, maxWidth: budget).joined(separator: "\n")
            XCTAssertFalse(joined.contains("\u{2524} \u{250C}"),
                           "subgraph wall merged into a node box at budget \(budget):\n\(joined)")
            XCTAssertFalse(joined.contains("\u{251C}\u{25BA}\u{2502}"),
                           "arrowhead merged into a box wall at budget \(budget):\n\(joined)")
        }
    }

    // MARK: - Measurement

    /// `colorEnabled` is true by default on the public options, and a styled
    /// span carries an SGR prefix and reset. Counting those as visible columns
    /// made every rung look like an overflow, so a diagram that already fit came
    /// back squeezed to the tightest layout for nothing.
    func testDiagramWidthIgnoresEscapeSequences() {
        XCTAssertEqual(diagramWidth("\u{1B}[38;2;1;2;3mabc\u{1B}[0m"), 3)
        XCTAssertEqual(diagramWidth("\u{1B}[31mab\u{1B}[0m\n\u{1B}[32mabcd\u{1B}[0m"), 4)
        XCTAssertEqual(diagramWidth("plain"), 5)
    }

    /// A colored render must reach the same fitting decision as an uncolored
    /// one — the escapes are invisible, so they cannot change the layout.
    func testColorDoesNotChangeTheChosenLayout() {
        func rendered(color: Bool) -> String? {
            var options = MermaidOptions()
            options.colorEnabled = color
            options.maxWidth = 60
            return Mermaid.render(wideFlow, options: options)?.joined(separator: "\n")
        }
        let plain = rendered(color: false) ?? ""
        let colored = rendered(color: true) ?? ""
        XCTAssertFalse(plain.isEmpty)
        XCTAssertEqual(plain.split(separator: "\n").count, colored.split(separator: "\n").count,
                       "color changed the layout")
    }

    // MARK: - Sequence diagrams

    private let wideSequence = """
    sequenceDiagram
        participant Browser
        participant Gateway
        participant Auth
        participant Orders
        participant Payments
        participant Ledger
        Browser->>Gateway: POST /checkout
        Gateway->>Auth: verify
        Auth-->>Gateway: ok
        Orders->>Payments: charge
        Payments->>Ledger: record
    """

    /// A sequence layout grows with the participant count and got no fitting at
    /// all, while still facing the caller's width check — so anything past about
    /// four participants degraded to raw source in an ordinary terminal, which
    /// the framed-card change turned into a regression against the old renderer.
    func testWideSequenceDiagramFitsItsBudget() {
        XCTAssertGreaterThan(widest(render(wideSequence, maxWidth: nil)), 80,
                             "fixture is not wide enough to test")
        for budget in [76, 80, 100] {
            XCTAssertLessThanOrEqual(widest(render(wideSequence, maxWidth: budget)), budget,
                                     "sequence diagram overflowed a \(budget)-column budget")
        }
    }

    /// The same guarantee flowcharts get: no budget means the layout is exactly
    /// what it was before fitting existed. The sequence goldens depend on it.
    func testSequenceWithNoBudgetIsUntouched() {
        let natural = render(wideSequence, maxWidth: nil)
        XCTAssertEqual(render(wideSequence, maxWidth: 500), natural)
        XCTAssertEqual(render(wideSequence, maxWidth: 0), natural, "0 must mean unconstrained")
    }

    /// Tightening may only ever narrow.
    func testSequenceFittingNeverWidens() {
        let natural = widest(render(wideSequence, maxWidth: nil))
        for budget in [40, 60, 80] {
            XCTAssertLessThanOrEqual(widest(render(wideSequence, maxWidth: budget)), natural)
        }
    }

    /// Message labels are drawn inline along a one-row arrow, so a budget under
    /// the participant boxes themselves cannot be met. It must still terminate
    /// and return the narrowest attempt rather than nothing.
    func testImpossiblyNarrowSequenceBudgetStillReturnsSomething() {
        let rows = render(wideSequence, maxWidth: 10)
        XCTAssertFalse(rows.isEmpty)
        XCTAssertLessThan(widest(rows), widest(render(wideSequence, maxWidth: nil)))
    }

    // MARK: - Wrapping preserves the author's spacing

    /// Splitting on whitespace and re-joining with single spaces is a content
    /// change, not a re-flow: it deletes indentation and column alignment. And
    /// because it only happens under a budget, the same label came out aligned
    /// in a wide terminal and flush-left in a narrow one.
    func testWrapKeepsIndentationAndColumnGaps() {
        let label = newGraphLabel("col A          col B<br>    indented continuation line here")
        let wrapped = label.wrapped(to: 32)

        XCTAssertTrue(wrapped.lines.contains { $0.contains("col A          col B") },
                      "a run of spaces was collapsed: \(wrapped.lines)")
        XCTAssertTrue(wrapped.lines.contains { $0.hasPrefix("    indented") },
                      "leading indentation was dropped: \(wrapped.lines)")
    }

    /// …but indentation is not worth an overflow, which is the failure the whole
    /// file exists to prevent.
    func testWrapDropsIndentationRatherThanOverflow() {
        let wrapped = newGraphLabel("          padded").wrapped(to: 10)
        for line in wrapped.lines {
            XCTAssertLessThanOrEqual(DisplayWidth.stringWidth(line), 10, "overflowed: \(line)")
        }
    }
}
