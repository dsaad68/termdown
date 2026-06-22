import XCTest
@testable import termdownCore

final class SourceSpanTests: XCTestCase {

    private func render(_ md: String, width: Int = 80) -> RenderedDocument {
        AnsiRenderer(width: width, theme: .dark).render(md)
    }

    /// Find the first rendered row whose stripped text contains `needle`, and
    /// return its source span.
    private func span(of needle: String, in doc: RenderedDocument) -> SourceSpan? {
        for (i, line) in doc.lines.enumerated() where Ansi.strip(line).contains(needle) {
            return doc.sourceSpans[i] ?? nil
        }
        XCTFail("row containing \(needle) not found")
        return nil
    }

    func testHeadingParagraphAndListSpans() {
        let md = """
        # Title

        Hello world

        - item one
        - item two
        """
        let doc = render(md)
        XCTAssertEqual(doc.lines.count, doc.sourceSpans.count)
        XCTAssertEqual(span(of: "Title", in: doc)?.start, 1)
        XCTAssertEqual(span(of: "Hello world", in: doc)?.start, 3)
        XCTAssertEqual(span(of: "item one", in: doc)?.start, 5)
        XCTAssertEqual(span(of: "item two", in: doc)?.start, 6)
    }

    func testSoftWrappedParagraphMapsToItsSourceLines() {
        // A paragraph split across two source lines (no blank between) is one
        // block; both its source lines fall in the span.
        let md = "first line\nsecond line"
        let doc = render(md)
        let s = span(of: "first line", in: doc)
        XCTAssertEqual(s?.start, 1)
        XCTAssertEqual(s?.end, 2)
    }

    func testFrontmatterOffsetShiftsSpansToFileLines() {
        let md = """
        ---
        title: x
        ---

        # Heading

        body text
        """
        let doc = render(md)
        // File lines: 1=---,2=title,3=---,4=blank,5=# Heading,6=blank,7=body text
        XCTAssertEqual(span(of: "Heading", in: doc)?.start, 5)
        XCTAssertEqual(span(of: "body text", in: doc)?.start, 7)
    }

    func testSourceIsRetained() {
        let md = "# A\n\ntext"
        XCTAssertEqual(render(md).source, md)
    }

    func testSyntheticRowsHaveNilSpan() {
        let doc = render("# A\n\ntext")
        // The final trailing blank rows carry no source span.
        XCTAssertNil(doc.sourceSpans.last ?? nil)
    }
}
