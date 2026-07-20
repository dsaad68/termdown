import XCTest
@testable import termdownCore
@testable import MermaidRenderer

/// Integration tests for ```mermaid handling inside the markdown renderer:
/// diagram rendering, charset selection, the enable flag, and graceful fallback.
final class MermaidRenderTests: XCTestCase {
    private func render(_ md: String, enabled: Bool = true,
                        charset: MermaidCharset = .unicode) -> String {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = previous }
        return AnsiRenderer(width: 80, theme: .dark, mermaidEnabled: enabled, mermaidCharset: charset)
            .render(md).lines.joined(separator: "\n")
    }

    private let flowchart = """
    ```mermaid
    graph LR
    A --> B
    ```
    """

    func testFlowchartRendersUnicodeBox() {
        let out = render(flowchart)
        XCTAssertTrue(out.contains("┌─ mermaid"), "expected a mermaid card header")
        XCTAssertTrue(out.contains("►"), "expected a unicode arrowhead")
        XCTAssertTrue(out.contains("A"), "expected node A")
        XCTAssertTrue(out.contains("B"), "expected node B")
        // The raw graph source must NOT appear — it was rendered as a diagram.
        XCTAssertFalse(out.contains("graph LR"), "raw source should not appear when rendered")
    }

    func testFlowchartRendersAsciiCharset() {
        let out = render(flowchart, charset: .ascii)
        // The diagram body uses ASCII glyphs; the card frame is always Unicode
        // chrome (matching code-block cards), so only check diagram-specific glyphs.
        XCTAssertTrue(out.contains(">"), "expected an ASCII arrowhead")
        XCTAssertTrue(out.contains("+---+"), "expected an ASCII node box")
        XCTAssertFalse(out.contains("►"), "ASCII diagram must not contain unicode arrowheads")
    }

    func testSequenceRenders() {
        let out = render("""
        ```mermaid
        sequenceDiagram
        Alice->>Bob: Hi
        ```
        """)
        XCTAssertTrue(out.contains("Alice"))
        XCTAssertTrue(out.contains("Bob"))
        XCTAssertTrue(out.contains("Hi"))
        XCTAssertFalse(out.contains("sequenceDiagram"), "keyword should be consumed, not printed")
    }

    func testUnsupportedDiagramFallsBackToSource() {
        let out = render("""
        ```mermaid
        pie title Pets
        "Dogs": 3
        ```
        """)
        // Falls back to the highlighted code block, so the raw source is shown.
        XCTAssertTrue(out.contains("pie title Pets"), "unsupported diagram should fall back to source")
    }

    func testMalformedFlowchartFallsBackToSource() {
        // `style`/`class` statements aren't supported; rather than render a
        // bogus node the block must fall back to the highlighted source.
        let out = render("""
        ```mermaid
        graph LR
        A --> B
        style A fill:#fff
        ```
        """)
        XCTAssertTrue(out.contains("style A fill:#fff"), "unsupported syntax should fall back to source")
        XCTAssertFalse(out.contains("►"), "nothing should have been rendered as a diagram")
    }

    func testDisabledShowsSource() {
        let out = render(flowchart, enabled: false)
        XCTAssertTrue(out.contains("graph LR"), "with mermaid disabled the source should render as code")
        XCTAssertFalse(out.contains("►"))
    }

    // MARK: - The two width tables must not drift apart

    /// `Ansi` measures the rows and `DisplayWidth` measures the box borders
    /// drawn inside them. They are deliberate duplicates — MermaidRenderer stays
    /// dependency-free so it can be vendored alone — which makes a silent
    /// divergence the failure mode: a diagram sized by one table and padded by
    /// the other sits a cell off on every row containing the disputed glyph.
    /// This sweeps the assigned planes so an edit to one table fails loudly.
    func testWidthTablesAgreeOnEveryScalar() {
        // Compare the per-cluster measurement, not `width`/`stringWidth`: only
        // the former strips ANSI escapes, which would report ESC as a false
        // divergence rather than a table one.
        var mismatches: [String] = []
        for v in UInt32(0)...0x3FFFF {
            guard let scalar = Unicode.Scalar(v) else { continue }
            let c = Character(scalar)
            let ansi = Ansi.charWidth(c)
            let mermaid = DisplayWidth.clusterWidth(c)
            if ansi != mermaid, mismatches.count < 12 {
                mismatches.append(String(format: "U+%04X: Ansi=%d DisplayWidth=%d", v, ansi, mermaid))
            }
        }
        XCTAssertEqual(mismatches, [], "width tables diverged")
    }

    func testWidthTablesAgreeOnEmojiSequences() {
        for s in ["👨‍👩‍👧", "👍🏽", "❤️", "🇺🇸", "🆕", "✅", "日本語", "🀄", "🈚"] {
            XCTAssertEqual(Ansi.width(s), DisplayWidth.stringWidth(s), "disagreed on \(s)")
        }
    }

    // MARK: - The card never exceeds the document width

    /// Wide enough that it used to overflow an 80-column document by ~53
    /// columns, which the pager then truncated destructively.
    private static let wideDiagram = """
    ```mermaid
    flowchart LR
        A[formula row: input + gold formula] --> B[teacher recast question]
        B --> C[verify deterministic components and sub-queries]
        C -->|fail, retries < 2 with feedback| B
        C --> D[Done]
    ```
    """

    /// Every row of a rendered document is padded to the full width; autowrap is
    /// off, so a row wider than that pushes the frame's right border off-screen.
    /// The mermaid card was the one construct that could produce one.
    func testMermaidCardNeverExceedsTheDocumentWidth() {
        for width in [40, 60, 80, 100, 120] {
            let doc = AnsiRenderer(width: width, theme: .dark).render(Self.wideDiagram)
            for (index, line) in doc.lines.enumerated() {
                XCTAssertLessThanOrEqual(Ansi.width(line), width,
                                         "row \(index) overflowed at width \(width)")
            }
        }
    }

    /// The card is a box: if the borders do not line up the frame looks broken,
    /// so the top and bottom rules must span the full width exactly.
    func testMermaidCardBordersSpanTheFullWidth() {
        let width = 72
        let doc = AnsiRenderer(width: width, theme: .dark).render(Self.wideDiagram)
        let top = try? XCTUnwrap(doc.lines.first { Ansi.strip($0).hasPrefix("┌─ mermaid") })
        let bottom = try? XCTUnwrap(doc.lines.first { Ansi.strip($0).hasPrefix("└") })
        XCTAssertEqual(Ansi.width(top ?? ""), width)
        XCTAssertEqual(Ansi.width(bottom ?? ""), width)
    }

    /// A diagram that fits must not be clipped — the ellipsis marker only ever
    /// appears when a row genuinely could not be made to fit.
    func testFittingDiagramIsNotMarkedAsClipped() {
        let doc = AnsiRenderer(width: 100, theme: .dark).render(Self.wideDiagram)
        let body = doc.lines.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertFalse(body.contains("…"), "a diagram that fits should not be clipped:\n\(body)")
    }
}
