import XCTest
@testable import termdown
@testable import termdownCore

/// Tests for Pager's chrome rendering (status bar, tab strip, outline sidebar).
/// These build the styled string then strip ANSI to assert on structure.
final class PagerDrawingTests: XCTestCase {

    private func tab(_ title: String) -> Pager.TabState {
        Pager.TabState(url: nil, navStack: [], title: title, top: 0, hscroll: 0,
                       wrapOn: true, widthOverride: nil, followMode: false,
                       sidebarOn: false, sidebarFocus: false, sidebarCursor: 0,
                       searchQuery: "", linkFocus: nil, foldedHeadings: [], lastModDate: nil)
    }

    // MARK: - Status bar

    func testStatusBarNormal() {
        var p = Pager(title: "doc.md", lines: [])
        p.lines = Array(repeating: "x", count: 50)
        let bar = p.statusBar(top: 0, contentRows: 10, cols: 80, maxTop: 40, wrapOn: true,
                              followMode: false, reloadFlashActive: false, title: "doc.md",
                              searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                              searchMode: false, gotoMode: false, gotoInput: "",
                              sidebarFocus: false, sidebarCursor: 0, linkFocus: nil)
        let plain = Ansi.strip(bar)
        XCTAssertTrue(plain.contains("doc.md"), plain)
        XCTAssertTrue(plain.contains("1-10/50"), plain)   // position
        XCTAssertTrue(plain.contains("0%"), plain)        // at top
        XCTAssertTrue(plain.contains("? help"), plain)
    }

    func testStatusBarNowrapAndFollowFlags() {
        var p = Pager(title: "doc.md", lines: [])
        p.lines = Array(repeating: "x", count: 50)
        let bar = p.statusBar(top: 0, contentRows: 10, cols: 100, maxTop: 40, wrapOn: false,
                              followMode: true, reloadFlashActive: false, title: "doc.md",
                              searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                              searchMode: false, gotoMode: false, gotoInput: "",
                              sidebarFocus: false, sidebarCursor: 0, linkFocus: nil)
        let plain = Ansi.strip(bar)
        XCTAssertTrue(plain.contains("NOWRAP"), plain)
        XCTAssertTrue(plain.contains("FOLLOW"), plain)
    }

    func testStatusBarSearchMode() {
        var p = Pager(title: "doc.md", lines: [])
        p.lines = Array(repeating: "x", count: 50)
        let matches = [(lineIndex: 3, range: 0..<2), (lineIndex: 7, range: 1..<3)]
        let bar = p.statusBar(top: 0, contentRows: 10, cols: 80, maxTop: 40, wrapOn: true,
                              followMode: false, reloadFlashActive: false, title: "doc.md",
                              searchQuery: "ab", searchMatches: matches, currentMatchIndex: 0,
                              searchMode: true, gotoMode: false, gotoInput: "",
                              sidebarFocus: false, sidebarCursor: 0, linkFocus: nil)
        let plain = Ansi.strip(bar)
        XCTAssertTrue(plain.contains("/ab"), plain)
        XCTAssertTrue(plain.contains("1/2"), plain)       // match counter
        XCTAssertTrue(plain.contains("accept"), plain)
    }

    // MARK: - Tab strip

    func testTabStripActiveAndInactive() {
        let p = Pager(title: "x", lines: [])
        let strip = p.tabStrip([tab("first.md"), tab("second.md")], active: 0)
        let plain = Ansi.strip(strip)
        XCTAssertTrue(plain.contains("1 first.md"), plain)
        XCTAssertTrue(plain.contains("2 second.md"), plain)
    }

    func testTabStripUntitledFallback() {
        let p = Pager(title: "x", lines: [])
        let plain = Ansi.strip(p.tabStrip([tab(""), tab("b.md")], active: 1))
        XCTAssertTrue(plain.contains("1 untitled"), plain)
    }

    // MARK: - Outline sidebar

    func testSidebarColumnListsHeadings() {
        var p = Pager(title: "x", lines: [])
        p.lines = Array(repeating: "x", count: 30)
        p.headings = [HeadingInfo(lineIndex: 0, level: 1, text: "Intro"),
                      HeadingInfo(lineIndex: 5, level: 2, text: "Setup"),
                      HeadingInfo(lineIndex: 10, level: 1, text: "Usage")]
        let cells = p.sidebarColumn(top: 0, contentRows: 10, sidebarFocus: false, sidebarCursor: 0)
        XCTAssertEqual(cells.count, 10)                          // header + 9 list rows
        let plain = cells.map { Ansi.strip($0) }
        XCTAssertTrue(plain[0].contains("OUTLINE"), plain[0])    // header row
        let joined = plain.joined(separator: "\n")
        XCTAssertTrue(joined.contains("Intro"), joined)
        XCTAssertTrue(joined.contains("Setup"), joined)
        XCTAssertTrue(joined.contains("Usage"), joined)
    }

    func testSidebarHeaderShowsFocusAffordance() {
        var p = Pager(title: "x", lines: [])
        p.lines = Array(repeating: "x", count: 30)
        p.headings = [HeadingInfo(lineIndex: 0, level: 1, text: "Intro")]
        let focused = p.sidebarColumn(top: 0, contentRows: 6, sidebarFocus: true, sidebarCursor: 0)
        // The focused header carries an ↑↓ affordance.
        XCTAssertTrue(Ansi.strip(focused[0]).contains("\u{2191}\u{2193}"))
    }
}
