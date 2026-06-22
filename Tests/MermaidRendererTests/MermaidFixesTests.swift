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
}
