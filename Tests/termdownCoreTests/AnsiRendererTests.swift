import XCTest
@testable import termdownCore

final class AnsiRendererTests: XCTestCase {

    func testRenderHeading() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = "# Heading 1"
        let output = renderer.render(markdown).lines

        // Strip ANSI codes for stable comparison
        let stripped = output.map { Ansi.strip($0) }
        let joined = stripped.joined()
        // Check that heading content is present
        XCTAssertTrue(joined.contains("Heading 1") || joined.contains("HEADING 1"), "Output: \(joined)")
    }

    func testRenderHeadingLevels() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = """
        # H1
        ## H2
        ### H3
        """
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        let joined = stripped.joined()
        // Check that heading content is present (might be uppercase)
        XCTAssertTrue(joined.contains("H1") || joined.contains("h1"), "Output: \(joined)")
        XCTAssertTrue(joined.contains("H2") || joined.contains("h2"), "Output: \(joined)")
        XCTAssertTrue(joined.contains("H3") || joined.contains("h3"), "Output: \(joined)")
    }

    func testRenderParagraph() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = "This is a paragraph."
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        XCTAssertTrue(stripped.contains("This is a paragraph."))
    }

    func testRenderCodeBlock() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = """
        ```swift
        let x = 42
        ```
        """
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        let joined = stripped.joined()
        // Should contain the code content (might be split across lines with bar characters)
        XCTAssertTrue(joined.contains("let") && joined.contains("x"), "Output: \(joined)")
    }

    func testRenderInlineCode() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = "This has `inline code` in it."
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        XCTAssertTrue(stripped.joined().contains("inline code"))
    }

    func testRenderList() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        XCTAssertTrue(stripped.joined().contains("Item 1"))
        XCTAssertTrue(stripped.joined().contains("Item 2"))
        XCTAssertTrue(stripped.joined().contains("Item 3"))
    }

    func testRenderTable() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = """
        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |
        """
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        XCTAssertTrue(stripped.joined().contains("Header 1"))
        XCTAssertTrue(stripped.joined().contains("Cell 1"))
    }

    func testRenderQuote() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = "> This is a quote"
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        XCTAssertTrue(stripped.joined().contains("This is a quote"))
    }

    func testRenderLink() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = "[Link text](https://example.com)"
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        XCTAssertTrue(stripped.joined().contains("Link text"))
    }

    func testCollectLinks() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = "See [Example](https://example.com) and [docs](other.md)."
        let doc = renderer.render(markdown)

        XCTAssertEqual(doc.links.count, 2)
        let urls = doc.links.map { $0.url }
        XCTAssertTrue(urls.contains("https://example.com"))
        XCTAssertTrue(urls.contains("other.md"))

        // The recorded column range should align with the visible link text.
        // Sliced by display column, matching what `column`/`length` mean — the
        // old character indexing agreed only because this fixture is ASCII, and
        // so certified the confusion it was meant to catch.
        if let example = doc.links.first(where: { $0.url == "https://example.com" }) {
            let plain = Ansi.strip(doc.lines[example.lineIndex])
            let slice = Ansi.horizontalSlice(plain, start: example.column, width: example.length)
            XCTAssertEqual(Ansi.strip(slice), "Example")
        } else {
            XCTFail("expected an Example link")
        }
    }

    /// The same assertion on a line whose link is preceded by wide glyphs, where
    /// a display column and a character index genuinely diverge.
    func testCollectLinksColumnsAreDisplayColumnsWithWideText() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let doc = renderer.render("日本語 と [Example](https://example.com) です。")
        guard let link = doc.links.first(where: { $0.url == "https://example.com" }) else {
            return XCTFail("expected an Example link")
        }
        let plain = Ansi.strip(doc.lines[link.lineIndex])
        let slice = Ansi.horizontalSlice(plain, start: link.column, width: link.length)
        XCTAssertEqual(Ansi.strip(slice), "Example")
        // And the column really is past the CJK run, not a character offset.
        XCTAssertGreaterThanOrEqual(link.column, 8)
    }

    func testRenderThematicBreak() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = "---"
        let output = renderer.render(markdown).lines

        // Should render some kind of horizontal rule
        XCTAssertGreaterThan(output.count, 0)
    }

    func testRenderWrapping() {
        let renderer = AnsiRenderer(width: 20, theme: .dark)
        let longText = "This is a very long paragraph that should wrap at 20 characters"
        let output = renderer.render(longText).lines

        let stripped = output.map { Ansi.strip($0) }
        // Check that lines are wrapped (no line should be longer than width)
        for line in stripped {
            let lineWidth = Ansi.width(line)
            XCTAssertLessThanOrEqual(lineWidth, 20, "Line '\(line)' exceeds width of 20")
        }
    }

    func testRenderEmptyInput() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let output = renderer.render("").lines

        // Empty input might still produce blank lines (we added 2 blank lines at the end)
        // So we expect 2 blank lines rather than 0
        XCTAssertEqual(output.count, 2)
        XCTAssertTrue(output.allSatisfy { $0.isEmpty })
    }

    // MARK: - Strong

    /// `**bold**` used to emit a bare `ESC[1m`, which a terminal draws only if the
    /// font ships a bold face — under tmux, or with a font that has none, bold
    /// prose was indistinguishable from the text around it. It now carries the
    /// theme's `strong` foreground alongside the weight.
    func testStrongCarriesWeightAndTheThemeColor() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = true
        defer { Ansi.colorEnabled = previous }

        let line = AnsiRenderer(width: 80, theme: .dark).render("a **b** c").lines[0]
        let expected = Ansi.code([1] + Ansi.fg(Theme.dark.strong))
        XCTAssertTrue(line.contains(expected + "b"), "expected \(expected.debugDescription) in \(line.debugDescription)")
    }

    /// The colour is a fallback, not an override: a run that already has one of
    /// its own — a heading, a link, an alert — must keep it, or bold inside a
    /// heading would repaint the heading's colour away.
    func testStrongLeavesAnExistingColorAlone() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = true
        defer { Ansi.colorEnabled = previous }

        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let strong = Ansi.code(Ansi.fg(Theme.dark.strong))

        let heading = renderer.render("# h **b**").lines[0]
        XCTAssertTrue(heading.contains(Ansi.code([1] + Ansi.fg(Theme.dark.heading[0])) + "b"))
        XCTAssertFalse(heading.contains(strong))

        let link = renderer.render("[**b**](https://example.com)").lines[0]
        XCTAssertTrue(link.contains("b"))
        XCTAssertFalse(link.contains(strong))
    }

    /// The strong colour is styling, so `--no-color` has to drop it along with the
    /// weight rather than leaving a bare `ESC[38;5;…m` in plain-text output.
    func testStrongEmitsNothingWithoutColor() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = previous }

        let line = AnsiRenderer(width: 80, theme: .dark).render("a **b** c").lines[0]
        XCTAssertEqual(line, "a b c")
    }

    /// Inline code inside bold keeps the code colour and drops the weight — the
    /// rule that predates this change, restated so the strong colour can't leak in.
    func testInlineCodeInsideStrongStaysCodeColored() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = true
        defer { Ansi.colorEnabled = previous }

        let line = AnsiRenderer(width: 80, theme: .dark).render("**a `c`**").lines[0]
        XCTAssertTrue(line.contains(Ansi.code(Ansi.fg(Theme.dark.inlineCode)) + "c"))
    }

    func testRenderMultipleParagraphs() {
        let renderer = AnsiRenderer(width: 80, theme: .dark)
        let markdown = """
        First paragraph.

        Second paragraph.
        """
        let output = renderer.render(markdown).lines

        let stripped = output.map { Ansi.strip($0) }
        let joined = stripped.joined()
        XCTAssertTrue(joined.contains("First paragraph"))
        XCTAssertTrue(joined.contains("Second paragraph"))
    }
}
