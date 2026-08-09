import Markdown
import XCTest
@testable import termdownCore

final class CalloutTests: XCTestCase {

    private func lines(_ markdown: String, width: Int = 60, theme: Theme = .dark) -> [String] {
        AnsiRenderer(width: width, theme: theme).render(markdown).lines
    }

    private func plain(_ markdown: String, width: Int = 60) -> [String] {
        lines(markdown, width: width).map { Ansi.strip($0) }
    }

    private func callout(_ markdown: String) -> Callout? {
        let quote = Document(parsing: markdown).children.first(where: { $0 is BlockQuote })
        return (quote as? BlockQuote).flatMap(Callout.parse)
    }

    // MARK: - The marker is consumed

    /// The marker used to be matched for its colour and then rendered again as
    /// part of the body, so every callout read `● NOTE` over `[!NOTE] Body`.
    func testMarkerDoesNotReachTheBody() {
        let out = plain("> [!NOTE]\n> Supported.")
        XCTAssertEqual(out.first?.contains("● NOTE"), true, "\(out)")
        XCTAssertFalse(out.contains { $0.contains("[!NOTE]") }, "marker leaked into the body: \(out)")
        XCTAssertTrue(out.contains { $0.contains("Supported.") })
    }

    func testMarkerOnTheSameLineAsTheBodyIsStillConsumed() {
        let out = plain("> [!WARNING] Careful")
        XCTAssertFalse(out.contains { $0.contains("[!WARNING]") }, "\(out)")
    }

    // MARK: - Tags

    func testEveryKnownTagIsRecognised() {
        for kind in Callout.knownKinds {
            XCTAssertEqual(callout("> [!\(kind)]\n> body")?.kind, kind)
        }
    }

    func testTagsAreCaseInsensitiveAndReportedUppercase() {
        for written in ["note", "Note", "nOtE", "NOTE"] {
            XCTAssertEqual(callout("> [!\(written)]\n> body")?.kind, "NOTE", written)
        }
    }

    func testAliasTagsShareTheirColor() {
        XCTAssertEqual(callout("> [!INFO]")?.color(.dark), Theme.dark.alertNote)
        XCTAssertEqual(callout("> [!TODO]")?.color(.dark), Theme.dark.alertNote)
        XCTAssertEqual(callout("> [!SUCCESS]")?.color(.dark), Theme.dark.alertTip)
        XCTAssertEqual(callout("> [!EXAMPLE]")?.color(.dark), Theme.dark.alertImportant)
        XCTAssertEqual(callout("> [!DECISION]")?.color(.dark), Theme.dark.alertImportant)
        XCTAssertEqual(callout("> [!QUESTION]")?.color(.dark), Theme.dark.alertWarning)
        for red in ["DANGER", "FAILURE", "BUG"] {
            XCTAssertEqual(callout("> [!\(red)]")?.color(.dark), Theme.dark.alertCaution, red)
        }
        XCTAssertEqual(callout("> [!ABSTRACT]")?.color(.dark), Theme.dark.alertAbstract)
    }

    /// An unknown tag is a callout too — it just borrows the plain quote colour
    /// rather than being rejected back into prose with its marker showing.
    func testUnknownTagIsACalloutInTheQuoteColor() {
        let c = callout("> [!HOUSE-STYLE]\n> body")
        XCTAssertEqual(c?.kind, "HOUSE-STYLE")
        XCTAssertEqual(c?.color(.dark), Theme.dark.quoteBar)
        XCTAssertFalse(plain("> [!HOUSE-STYLE]\n> body").contains { $0.contains("[!") })
    }

    // MARK: - Titles

    func testTagIsTheTitleWhenNoneIsGiven() {
        XCTAssertEqual(callout("> [!TIP]\n> body")?.titleInlines.isEmpty, true)
        XCTAssertTrue(plain("> [!TIP]\n> body").contains { $0.contains("● TIP") })
    }

    func testCustomTitleReplacesTheTag() {
        let out = plain("> [!TIP] Try this instead\n> body")
        XCTAssertTrue(out.contains { $0.contains("● Try this instead") }, "\(out)")
        XCTAssertFalse(out.contains { $0.contains("TIP") }, "\(out)")
        XCTAssertTrue(out.contains { $0.contains("body") })
    }

    /// The title is markup, not a string, so styling inside it survives — and the
    /// space before that styling must survive with it.
    func testTitleKeepsInlineMarkupAndItsSpacing() {
        let out = plain("> [!TIP] Use **bold** here\n> body")
        XCTAssertTrue(out.contains { $0.contains("● Use bold here") }, "\(out)")
    }

    /// The title ends at the first line break. Reading to the end of the
    /// paragraph instead would swallow the body of every multi-line callout.
    func testTitleStopsAtTheFirstLineBreak() {
        let c = callout("> [!NOTE] Title\n> Body one\n> Body two")
        XCTAssertEqual(c?.bodyInlines.isEmpty, false)
        let out = plain("> [!NOTE] Title\n> Body one\n> Body two")
        XCTAssertTrue(out.contains { $0.contains("● Title") && !$0.contains("Body") }, "\(out)")
    }

    func testTitleOnlyCalloutRendersOneRow() {
        let out = plain("> [!EXAMPLE] Just a title").filter { !$0.isEmpty }
        XCTAssertEqual(out.count, 1, "\(out)")
    }

    // MARK: - Body

    func testBlocksAfterTheOpeningParagraphAreKept() {
        let out = plain("> [!IMPORTANT] T\n> One.\n>\n> Two.\n>\n> - item")
        XCTAssertTrue(out.contains { $0.contains("One.") })
        XCTAssertTrue(out.contains { $0.contains("Two.") })
        XCTAssertTrue(out.contains { $0.contains("item") })
    }

    /// Every row of a callout carries the bar, including the blank ones between
    /// its blocks — a gap in the bar reads as the callout having ended.
    func testEveryRowCarriesTheBar() {
        let out = plain("> [!NOTE] T\n> One.\n>\n> Two.").filter { !$0.isEmpty }
        XCTAssertTrue(out.allSatisfy { $0.hasPrefix("\u{2503}") }, "\(out)")
    }

    // MARK: - Not callouts

    func testPlainQuoteIsUntouched() {
        XCTAssertNil(callout("> Just a quote."))
        XCTAssertTrue(plain("> Just a quote.").contains { $0.contains("Just a quote.") })
    }

    /// A tag has to be a single word: `[!NOT VALID]` is prose that happens to
    /// start with a bracket, and must survive verbatim.
    func testTagWithASpaceIsNotAMarker() {
        XCTAssertNil(callout("> [!NOT VALID] text"))
        XCTAssertTrue(plain("> [!NOT VALID] text").contains { $0.contains("[!NOT VALID]") })
    }

    func testMarkerMustLeadTheQuote() {
        XCTAssertNil(callout("> Lead-in text [!NOTE] here"))
    }

    // MARK: - Callouts in context

    /// A callout inside a callout keeps both bars, so the nesting is visible
    /// rather than the inner one silently replacing the outer.
    func testCalloutsNest() {
        let out = plain("> [!NOTE]\n> > [!WARNING]\n> > Inner.")
        XCTAssertTrue(out.contains { $0.contains("● NOTE") })
        XCTAssertTrue(out.contains { $0.hasPrefix("\u{2503} \u{2503}") && $0.contains("● WARNING") }, "\(out)")
        XCTAssertFalse(out.contains { $0.contains("[!") })
    }

    func testCalloutInsideAListItemIsIndentedNotFlattened() {
        let out = plain("- item\n  > [!TIP]\n  > Inside a list.")
        XCTAssertTrue(out.contains { $0.contains("\u{2503} ● TIP") }, "\(out)")
        XCTAssertTrue(out.contains { $0.hasPrefix("  ") && $0.contains("● TIP") }, "\(out)")
    }

    /// cmark leaves the indentation of `>   [!NOTE]` on the text node, so the
    /// marker has to tolerate leading whitespace or such a callout reads as prose.
    func testMarkerToleratesLeadingWhitespace() {
        XCTAssertEqual(callout(">   [!CAUTION]\n> body")?.kind, "CAUTION")
    }

    func testTagWithNoBodyRendersJustTheHeader() {
        let out = plain("> [!NOTE]").filter { !$0.isEmpty }
        XCTAssertEqual(out, ["\u{2503} ● NOTE"])
    }

    /// Under `--no-color` every `Ansi.color` call is a no-op, so the marker has
    /// to be consumed by the parse rather than painted over.
    func testMarkerIsConsumedWithoutColor() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = previous }

        let out = lines("> [!NOTE]\n> Supported.", theme: .mono)
        XCTAssertFalse(out.contains { $0.contains("[!NOTE]") }, "\(out)")
        XCTAssertTrue(out.contains { $0.contains("● NOTE") }, "\(out)")
    }

    /// The bar shifts every body row two columns right. `LinkInfo.column` drives
    /// the Tab-focus highlight, which paints the wrong cells if it misses that.
    func testLinkInsideACalloutReportsShiftedColumns() {
        let doc = AnsiRenderer(width: 60, theme: .dark)
            .render("> [!INFO]\n> A [link](https://example.com) here.")
        guard let link = doc.links.first(where: { $0.url == "https://example.com" }) else {
            return XCTFail("link not collected: \(doc.links)")
        }
        let row = Ansi.strip(doc.lines[link.lineIndex])
        XCTAssertEqual(Ansi.clusterSlice(row, start: link.column, width: link.length), "link")
    }

    /// Rows carry a source span or the line cursor and the inline `e` editor have
    /// nothing to map back to the file with.
    func testEveryCalloutRowCarriesASourceSpan() {
        let doc = AnsiRenderer(width: 60, theme: .dark)
            .render("> [!NOTE] Title\n> Body one.\n>\n> Body two.")
        for (i, line) in doc.lines.enumerated() where !Ansi.strip(line).isEmpty {
            XCTAssertNotNil(doc.sourceSpans[i], "no span for row \(i): \(Ansi.strip(line))")
        }
    }

    func testFootnoteRefInsideACalloutIsSubstituted() {
        let out = plain("> [!TIP]\n> See ref[^1].\n\n[^1]: the note.")
        XCTAssertTrue(out.contains { $0.contains("\u{2503}") && $0.contains("[1]") }, "\(out)")
        XCTAssertFalse(out.contains { $0.contains("[^1]") }, "\(out)")
    }

    // MARK: - Colour

    /// Bold picks up `theme.strong` only where the run has no colour of its own,
    /// and a callout title has one — otherwise `> [!TIP] Use **--width**` would
    /// repaint half its own header a different colour from the bar beside it.
    func testBoldInACalloutTitleKeepsTheCalloutColor() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = true
        defer { Ansi.colorEnabled = previous }

        let row = lines("> [!TIP] Use **bold** here")[0]
        XCTAssertTrue(row.contains(Ansi.code([1] + Ansi.fg(Theme.dark.alertTip)) + "bold"), row.debugDescription)
        XCTAssertFalse(row.contains(Ansi.code(Ansi.fg(Theme.dark.strong))), row.debugDescription)
    }

    // MARK: - Width

    /// The blocks after a callout's opening paragraph are rendered two columns
    /// narrower and then prefixed with the bar. A card or a table that ignored
    /// the narrowing would fit its own box and still overhang the row.
    func testBlocksInsideACalloutStayWithinTheWidth() {
        for width in [24, 40, 78] {
            let out = lines("""
            > [!NOTE] Blocks
            > ```swift
            > let x = averylongidentifier + anotherlongidentifier
            > ```
            >
            > | column one | column two |
            > | --- | --- |
            > | a value here | another value |
            """, width: width)
            for row in out {
                XCTAssertLessThanOrEqual(Ansi.width(row), width, "width \(width): \(Ansi.strip(row))")
            }
            XCTAssertTrue(out.contains { Ansi.strip($0).contains("│") }, "no table/card rows at \(width)")
        }
    }

    /// Callout rows are content rows like any other: one column over the width
    /// and the pager's frame desyncs, because autowrap is off.
    func testRowsStayWithinTheWidth() {
        for width in [24, 40, 78] {
            let out = lines("""
            > [!IMPORTANT] A title long enough that it has to wrap at every width tested here
            > A body paragraph that also needs wrapping to fit the narrower cases.
            """, width: width)
            for row in out {
                XCTAssertLessThanOrEqual(Ansi.width(row), width, "width \(width): \(Ansi.strip(row))")
            }
        }
    }
}
