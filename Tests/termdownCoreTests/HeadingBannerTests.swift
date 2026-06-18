import XCTest
@testable import termdownCore

/// Tests for heading-banner rendering (the `B` toggle): h1–h4 render as filled
/// background blocks, while staying navigable.
final class HeadingBannerTests: XCTestCase {

    private func line(_ doc: RenderedDocument, containing s: String) -> String {
        doc.lines.first { Ansi.strip($0).contains(s) } ?? ""
    }

    func testHeadingBecomesBackgroundBlockAndStaysNavigable() {
        let doc = AnsiRenderer(width: 40, theme: .dark, headingBanners: true)
            .render("# Title\n\nbody")
        let head = line(doc, containing: "Title")
        XCTAssertTrue(head.contains("48;5;") || head.contains("48;2;"), head)  // filled background
        // Still collected for the outline / nav (the marker hashes are invisible).
        XCTAssertEqual(doc.headings.first?.text, "Title")
        XCTAssertEqual(doc.headings.first?.level, 1)
    }

    func testNormalModeHasNoHeadingBackground() {
        let doc = AnsiRenderer(width: 40, theme: .dark, headingBanners: false).render("# Title")
        let head = line(doc, containing: "Title")
        XCTAssertFalse(head.contains("48;5;"), head)
        XCTAssertFalse(head.contains("48;2;"), head)
    }

    func testOnlyLevels1To4GetBanners() {
        let doc = AnsiRenderer(width: 40, theme: .dark, headingBanners: true)
            .render("# H1\n\n##### H5")
        XCTAssertTrue(line(doc, containing: "H1").contains("48;5;"))   // banner
        XCTAssertFalse(line(doc, containing: "H5").contains("48;5;"))  // h5 > 4 → normal
    }

    func testBannerHeadingFillsContentWidth() {
        let doc = AnsiRenderer(width: 30, theme: .dark, headingBanners: true).render("# Title")
        XCTAssertEqual(Ansi.width(line(doc, containing: "Title")), 30)
    }

    func testContrastingTextPicksDarkOnLight() {
        // A light pastel bg → near-black text; a dark bg → near-white.
        if case .rgb(let r, _, _) = Ansi.contrastingText(on: .rgb(220, 200, 255)) {
            XCTAssertLessThan(Int(r), 60)
        } else { XCTFail("expected rgb") }
        if case .rgb(let r, _, _) = Ansi.contrastingText(on: .rgb(40, 40, 50)) {
            XCTAssertGreaterThan(Int(r), 200)
        } else { XCTFail("expected rgb") }
    }
}
