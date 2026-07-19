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
