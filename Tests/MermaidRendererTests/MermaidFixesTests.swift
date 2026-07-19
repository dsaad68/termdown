import XCTest
@testable import MermaidRenderer

/// Regression tests for the robustness fixes layered on top of the upstream
/// fidelity goldens: malformed-line fallback, CRLF normalization, bracket/quote
/// aware operator matching, classDef key trimming, and display-width-safe
/// sequence rendering. Each is written to fail against the pre-fix behavior.
final class MermaidFixesTests: XCTestCase {

    // MARK: - Fix 1: malformed lines fall back (render returns nil)

    func testValidFlowchartStillRenders() {
        XCTAssertNotNil(Mermaid.render("graph LR\nA[Start] --> B[End]"))
    }

    func testStyleStatementFallsBack() {
        // `style`/`class` are real Mermaid we don't support; they must not turn
        // into a bogus node named "style A ...".
        XCTAssertNil(Mermaid.render("graph LR\nA --> B\nstyle A fill:#fff"))
        XCTAssertNil(Mermaid.render("graph LR\nA --> B\nclass A warn"))
    }

    func testTypoLineFallsBack() {
        // A single dash is not an edge; the line is unsupported syntax.
        XCTAssertNil(Mermaid.render("graph LR\nA - B"))
    }

    func testBareNodesWithLabelsStillParse() {
        // A label with spaces is fine — the *id* has no whitespace.
        let out = Mermaid.renderToString("graph LR\nA[Two words] --> B")
        XCTAssertNotNil(out)
        XCTAssertEqual(out?.contains("Two words"), true)
    }

    // MARK: - Fix 3: CRLF input

    func testFlowchartHandlesCRLF() {
        let out = Mermaid.renderToString("graph LR\r\nA --> B\r\n")
        XCTAssertNotNil(out, "CRLF input must still parse")
        XCTAssertEqual(out?.contains("\r"), false, "no carriage returns may leak into output")
        XCTAssertEqual(out?.contains("A"), true)
        XCTAssertEqual(out?.contains("B"), true)
    }

    func testSequenceHandlesCRLF() {
        let out = Mermaid.renderToString("sequenceDiagram\r\nAlice->>Bob: Hi\r\n")
        XCTAssertNotNil(out)
        XCTAssertEqual(out?.contains("\r"), false)
        XCTAssertEqual(out?.contains("Alice"), true)
        XCTAssertEqual(out?.contains("Hi"), true)
    }

    // MARK: - Fix 4: operators inside labels are not syntax

    func testAmpersandInsideLabelIsNotGrouping() {
        var opts = MermaidOptions()
        opts.colorEnabled = false
        let out = Mermaid.renderToString("graph LR\nA[\"foo & bar\"] --> B", options: opts)
        XCTAssertNotNil(out)
        // The whole label survives intact rather than splitting on the `&`.
        XCTAssertEqual(out?.contains("foo & bar"), true)
    }

    func testArrowInsideLabelIsNotAnEdge() {
        var opts = MermaidOptions()
        opts.colorEnabled = false
        let out = Mermaid.renderToString("graph LR\nA[\"x --> y\"] --> B", options: opts)
        XCTAssertNotNil(out)
        XCTAssertEqual(out?.contains("x --> y"), true)
    }

    func testStandaloneLabelWithOperator() {
        var opts = MermaidOptions()
        opts.colorEnabled = false
        let out = Mermaid.renderToString("graph LR\nA[\"a & b\"]", options: opts)
        XCTAssertNotNil(out)
        XCTAssertEqual(out?.contains("a & b"), true)
    }

    // MARK: - Unbalanced delimiters inside a label

    /// Counting `(` and `{` toward one depth counter meant a single unbalanced
    /// opener never returned the depth to zero, so every following statement was
    /// swallowed into the label that opened it. Matching each closer back to its
    /// own opener keeps one malformed label local to its line.
    func testUnbalancedParenInLabelDoesNotSwallowTheDiagram() {
        // Three statements stay three; the old counter left depth at 1 after the
        // stray `(`, so no later newline split and it collapsed to two.
        XCTAssertEqual(splitGraphLines("graph TD\nA[Retry (3x] --> B[Done]\nB --> C[End]").count, 3)
        var opts = MermaidOptions()
        opts.colorEnabled = false
        let out = Mermaid.renderToString("graph TD\nA[Retry (3x] --> B[Done]\nB --> C[End]", options: opts)
        XCTAssertNotNil(out)
        // All three nodes survive as nodes rather than collapsing into one box
        // whose caption is the rest of the diagram's source text.
        XCTAssertEqual(out?.contains("Done"), true)
        XCTAssertEqual(out?.contains("End"), true)
        XCTAssertEqual(out?.contains("--> B[Done]"), false, "the arrow must still parse as an edge")
    }

    func testUnbalancedParenInLabelStillMasksItsOwnArrow() {
        // `A[Cost (USD --> B`: the `]`-less label ends at the bracket, so the
        // top-level `-->` after it is real syntax and must not be masked.
        let masked = maskNested("A[Cost (USD] --> B")
        XCTAssertTrue(masked.contains("-->"), "a top-level arrow must survive masking")
    }

    func testStrayCloserInLabelIsTreatedAsText() {
        // A `:-)` smiley must not pop the depth below its enclosing `[`.
        let masked = maskNested("A[happy :-) day] --> B")
        XCTAssertTrue(masked.contains("-->"))
        XCTAssertFalse(masked.contains(":-)"), "the label's own dash stays masked")
    }

    func testOddQuoteDoesNotLatchForTheRestOfTheDiagram() {
        // An odd `"` in a comment used to latch `inQuotes` for the whole input,
        // so no later newline split and everything after it became one
        // statement — four lines came back as two.
        XCTAssertEqual(splitGraphLines("graph TD\n%% it\"s a note\nA --> B\nB --> C").count, 4)
    }

    // MARK: - Fix 6: classDef key/value trimming

    func testParseStyleClassTrimsSpacedList() {
        let sc = parseStyleClass(name: "warn", styles: "fill:#fff, color:#f00")
        XCTAssertEqual(sc.styles["color"], "#f00", "key must be trimmed to \"color\"")
        XCTAssertEqual(sc.styles["fill"], "#fff")
        XCTAssertNil(sc.styles[" color"], "leading-space key must not exist")
    }

    func testSpacedClassDefColorEmitsAnsi() {
        var opts = MermaidOptions()
        opts.colorEnabled = true
        let src = """
        graph LR
        classDef warn fill:#fff, color:#f00
        A:::warn --> B
        """
        let out = Mermaid.renderToString(src, options: opts)
        XCTAssertNotNil(out)
        // #f00 -> truecolor foreground 255;0;0; only reachable once the key is trimmed.
        XCTAssertEqual(out?.contains("\u{1B}[38;2;255;0;0m"), true)
    }

    // MARK: - Fix 2: display-width-safe sequence rendering

    func testSequenceBoxesAlignWithWideLabels() throws {
        let sd = try parseSequence("""
        sequenceDiagram
        participant A as 客户
        participant B as Bob
        A->>B: Hi
        """)
        let lines = renderSequenceDiagram(sd, useAscii: false).components(separatedBy: "\n")
        XCTAssertGreaterThanOrEqual(lines.count, 3)
        // Top border, label row and bottom border must share the same display
        // width; a scalar-count layout drifts the wide-label row to the right.
        let top = DisplayWidth.stringWidth(lines[0])
        let label = DisplayWidth.stringWidth(lines[1])
        let bottom = DisplayWidth.stringWidth(lines[2])
        XCTAssertEqual(top, label, "wide-label box row must align with the top border")
        XCTAssertEqual(top, bottom, "wide-label box row must align with the bottom border")
        XCTAssertTrue(lines[1].contains("客户"))
    }

    // MARK: - Node shapes: syntax must never reach the label

    /// Every shape is drawn as a rectangle (this renderer has no shape model,
    /// like upstream), but the delimiters must be stripped. Before the fix only
    /// `[...]` was recognized, so `A{"Hi"}` rendered as a box captioned
    /// `A{"Hi"}` — braces and quotes included.
    func testAllNodeShapesStripTheirDelimiters() {
        let shapes = [
            "A[\"Hi\"]", "A{\"Hi\"}", "A(\"Hi\")", "A([\"Hi\"])", "A[[\"Hi\"]]",
            "A[(\"Hi\")]", "A((\"Hi\"))", "A>\"Hi\"]", "A{{\"Hi\"}}",
        ]
        for shape in shapes {
            let out = Mermaid.renderToString("graph TD\nT --> \(shape)")
            XCTAssertNotNil(out, shape)
            guard let out else { continue }
            XCTAssertTrue(out.contains("Hi"), "\(shape): label text missing\n\(out)")
            for ch in ["{", "}", "(", ")", "[", "]", "\"", ">"] {
                XCTAssertFalse(out.contains("A\(ch)"), "\(shape): raw syntax leaked\n\(out)")
            }
        }
    }

    func testUnquotedShapeLabelsAlsoParse() {
        let out = Mermaid.renderToString("graph TD\nT --> A{Decide}")
        XCTAssertNotNil(out)
        XCTAssertTrue(out?.contains("Decide") ?? false, out ?? "")
        XCTAssertFalse(out?.contains("A{") ?? true, out ?? "")
    }

    // MARK: - Line splitting must respect quotes and every shape

    /// `\n` separates statements, but not inside a label. `splitGraphLines`
    /// tracked only `[`/`]` depth, so a `\n` inside `{...}` split the statement
    /// mid-label: the tail became a phantom node, or — when it contained a
    /// space — tripped the bare-node-id guard and failed the whole diagram.
    func testEscapedNewlineInsideRhombusDoesNotSplitTheStatement() {
        let out = Mermaid.renderToString(#"graph TD\#nT --> V{"aaa\nbbb ccc"}"#)
        XCTAssertNotNil(out, "rhombus with a multi-line label must render")
        guard let out else { return }
        XCTAssertTrue(out.contains("aaa"), out)
        XCTAssertTrue(out.contains("bbb ccc"), out)
        // The tail must not become a node of its own.
        XCTAssertFalse(out.contains("\"}"), "phantom node from a split label\n\(out)")
    }

    func testEscapedNewlineSplitsOnlyAtTopLevel() {
        // Two statements on one line: the split must still happen outside labels.
        let out = Mermaid.renderToString(#"graph TD\#nA["x"] --> B["y"]\nB --> C["z"]"#)
        XCTAssertNotNil(out)
        guard let out else { return }
        for label in ["x", "y", "z"] { XCTAssertTrue(out.contains(label), "\(label)\n\(out)") }
    }

    func testMultiLineLabelsInEveryShape() {
        for shape in ["[\"a\\nb\"]", "{\"a\\nb\"}", "(\"a\\nb\")", "([\"a\\nb\"])"] {
            let out = Mermaid.renderToString("graph TD\nT --> V\(shape)")
            XCTAssertNotNil(out, shape)
            XCTAssertTrue(out?.contains("a") ?? false, "\(shape)\n\(out ?? "")")
            XCTAssertTrue(out?.contains("b") ?? false, "\(shape)\n\(out ?? "")")
        }
    }

    // MARK: - Edge labels

    /// Edge labels are quoted to protect commas and comparison operators; the
    /// quotes and any `\n` must not reach the canvas. They render inline along a
    /// one-row arrow, so a line break flattens to a space rather than wrapping.
    func testQuotedEdgeLabelStripsQuotesAndFlattensNewlines() {
        let out = Mermaid.renderToString(#"graph TD\#nV -->|"fail, retries < 2\n(with feedback)"| T"#)
        XCTAssertNotNil(out)
        guard let out else { return }
        XCTAssertFalse(out.contains("\\n"), "escape reached the canvas\n\(out)")
        XCTAssertFalse(out.contains("\""), "quotes reached the canvas\n\(out)")
        XCTAssertTrue(out.contains("retries"), out)
    }

    func testPlainEdgeLabelUnchanged() {
        let out = Mermaid.renderToString("graph TD\nV -->|pass| F[Done]")
        XCTAssertNotNil(out)
        XCTAssertTrue(out?.contains("pass") ?? false, out ?? "")
    }

    func testFlattenEdgeLabelCollapsesBreaksAndWhitespace() {
        XCTAssertEqual(flattenEdgeLabel(#"a\nb"#), "a b")
        XCTAssertEqual(flattenEdgeLabel("a<br/>b"), "a b")
        XCTAssertEqual(flattenEdgeLabel("a<BR>b"), "a b")
        XCTAssertEqual(flattenEdgeLabel("  a   b  "), "a b")
        XCTAssertEqual(flattenEdgeLabel("plain"), "plain")
    }

    /// The reported failure: a rhombus whose multi-line label contains spaces
    /// after the `\n`, plus a quoted edge label on a back edge.
    func testReportedFlowchartRenders() {
        let src = #"""
        flowchart LR
            L["formula row:\ninput + gold formula\n+ company/year"] --> T["teacher\nrecast question +\nsub-queries + trace"]
            T --> V{"verify (deterministic):\ncomponents ↔ sub-queries\nbijection; NL-only; lint"}
            V -->|pass| F["finalize\nemit planner record"]
            V -->|"fail, retries < 2\n(with verifier feedback)"| T
            V -->|fail twice| X["rejected sink"]
        """#
        let out = Mermaid.renderToString(src)
        XCTAssertNotNil(out, "the reported diagram must render instead of falling back")
        guard let out else { return }
        XCTAssertTrue(out.contains("verify (deterministic):"), out)
        XCTAssertTrue(out.contains("bijection; NL-only; lint"), out)
        XCTAssertTrue(out.contains("rejected sink"), out)
        XCTAssertFalse(out.contains("\\n"), "escape reached the canvas\n\(out)")
    }
}
