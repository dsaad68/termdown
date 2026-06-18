import XCTest
@testable import termdownCore

/// Tests for `[[wikilink]]` parsing in the inline renderer (Phase 5).
final class WikilinkTests: XCTestCase {

    private func render(_ md: String) -> RenderedDocument {
        AnsiRenderer(width: 80, theme: .dark).render(md)
    }

    func testWikilinkBecomesInAppLink() {
        let doc = render("See [[Other Page]] here.")
        XCTAssertTrue(doc.links.contains { $0.url == "wikilink:Other Page" },
                      doc.links.map { $0.url }.description)
    }

    func testAliasIsDisplayedAndHeadingEncoded() {
        let doc = render("[[Setup#Install|the installer]]")
        let plain = Ansi.strip(doc.lines.joined(separator: "\n"))
        XCTAssertTrue(plain.contains("the installer"), plain)          // alias shown
        XCTAssertFalse(plain.contains("Setup#Install"), plain)         // raw target hidden
        XCTAssertTrue(doc.links.contains { $0.url == "wikilink:Setup#Install" },
                      doc.links.map { $0.url }.description)
    }

    func testPlainWikilinkDisplaysTarget() {
        let doc = render("[[Architecture]]")
        XCTAssertTrue(Ansi.strip(doc.lines.joined()).contains("Architecture"))
    }

    func testWikilinkInsideCodeStaysLiteral() {
        let doc = render("`[[NotALink]]` is literal")
        XCTAssertFalse(doc.links.contains { $0.url.hasPrefix("wikilink:") },
                       doc.links.map { $0.url }.description)
        XCTAssertTrue(Ansi.strip(doc.lines.joined(separator: "\n")).contains("[[NotALink]]"))
    }

    func testUnterminatedWikilinkIsLiteral() {
        let doc = render("an open [[bracket with no close")
        XCTAssertTrue(doc.links.isEmpty, doc.links.map { $0.url }.description)
        XCTAssertTrue(Ansi.strip(doc.lines.joined()).contains("[[bracket"))
    }
}
