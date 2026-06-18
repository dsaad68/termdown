import XCTest
@testable import termdown
@testable import termdownCore

/// Tests for Pager's pure / extracted logic, reachable now that the event-loop
/// state was promoted to internal properties and the nested funcs to methods.
final class PagerLogicTests: XCTestCase {

    private func makePager(lines: [String] = [],
                           headings: [HeadingInfo] = [],
                           links: [LinkInfo] = []) -> Pager {
        Pager(title: "test", lines: lines, headings: headings, links: links)
    }

    // MARK: - foldTransform (pure)

    /// Folding an H1 hides its body down to the next equal-or-higher heading,
    /// keeps the underline rule, swallows a nested H2, and adds a `▸ N lines` tag.
    func testFoldTransformHidesSectionBody() {
        let baseLines = ["# A", "═══", "para under A", "## B", "───", "under B", "# C", "under C"]
        let headings = [HeadingInfo(lineIndex: 0, level: 1, text: "A"),
                        HeadingInfo(lineIndex: 3, level: 2, text: "B"),
                        HeadingInfo(lineIndex: 6, level: 1, text: "C")]
        let t = Pager.foldTransform(baseLines: baseLines, baseHeadings: headings, baseLinks: [], folded: [0])

        // A's heading + its kept rule, then C's heading + body remain.
        XCTAssertEqual(t.lines.count, 4)
        XCTAssertEqual(t.headings.map { $0.text }, ["A", "C"])   // B is hidden inside A
        XCTAssertEqual(t.foldHiddenCount[0], 4)                  // lines 2..5 hidden
        XCTAssertTrue(Ansi.strip(t.lines[0]).contains("▸ 4 lines"))
        // base→display mapping: line 0 visible at 0, hidden lines map to -1.
        XCTAssertEqual(t.baseToDisp[0], 0)
        XCTAssertEqual(t.baseToDisp[3], -1)
        XCTAssertEqual(t.baseToDisp[6], 2)
    }

    func testFoldTransformEmptyIsIdentity() {
        let baseLines = ["# A", "body", "# B", "body2"]
        let headings = [HeadingInfo(lineIndex: 0, level: 1, text: "A"),
                        HeadingInfo(lineIndex: 2, level: 1, text: "B")]
        let t = Pager.foldTransform(baseLines: baseLines, baseHeadings: headings, baseLinks: [], folded: [])
        XCTAssertEqual(t.lines, baseLines)
        XCTAssertEqual(t.headings.count, 2)
        XCTAssertEqual(t.foldHiddenCount.count, 0)
    }

    // MARK: - Mouse click → link

    func testClickOnLinkFocusesIt() {
        // Link on display line 2, spanning content columns [4, 7).
        var p = makePager(lines: Array(repeating: "x", count: 30),
                          links: [LinkInfo(lineIndex: 2, url: "wikilink:Foo", text: "Foo",
                                           column: 4, length: 3)])
        p.contentRows = 20; p.top = 0; p.hscroll = 0; p.sidebarActive = false
        // No sidebar → chromeLeft = leftMargin (2). Screen col = 2 + column + 1 = 7;
        // screen row = lineIndex - top + 1 = 3. resolveWikilink is nil → inert open.
        p.handleClick(x: 7, y: 3)
        XCTAssertEqual(p.linkFocus, 0)
    }

    func testClickOffAnyLinkDoesNothing() {
        var p = makePager(lines: Array(repeating: "x", count: 30),
                          links: [LinkInfo(lineIndex: 2, url: "wikilink:Foo", text: "Foo",
                                           column: 4, length: 3)])
        p.contentRows = 20
        p.handleClick(x: 100, y: 3)   // far past the link span
        XCTAssertNil(p.linkFocus)
        p.handleClick(x: 7, y: 19)    // a row with no link
        XCTAssertNil(p.linkFocus)
    }

    func testFoldTransformDropsLinksInFoldedRegion() {
        let baseLines = ["# A", "rule", "para with link", "# B"]
        let headings = [HeadingInfo(lineIndex: 0, level: 1, text: "A"),
                        HeadingInfo(lineIndex: 3, level: 1, text: "B")]
        let links = [LinkInfo(lineIndex: 2, url: "x.md", text: "link")]
        let t = Pager.foldTransform(baseLines: baseLines, baseHeadings: headings, baseLinks: links, folded: [0])
        XCTAssertTrue(t.links.isEmpty)   // the link lived on a hidden line
    }

    // MARK: - detectCodeBlocks (pure)

    func testDetectCodeBlockFenced() {
        let lines = ["\u{250C}\u{2500} swift",
                     "\u{2502} let x = 1",
                     "\u{2502} print(x)",
                     "\u{2514}\u{2500}\u{2500}",
                     "",
                     "plain text"]
        let blocks = Pager.detectCodeBlocks(lines)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].range, 0..<4)
        XCTAssertEqual(blocks[0].text, "let x = 1\nprint(x)")
    }

    func testDetectCodeBlockSkipsTables() {
        let lines = ["\u{250C}\u{2500}\u{2500}\u{252C}\u{2500}\u{2500}\u{2510}",
                     "\u{2502} a \u{2502} b \u{2502}",
                     "\u{2514}\u{2500}\u{2534}\u{2500}\u{2518}"]
        XCTAssertTrue(Pager.detectCodeBlocks(lines).isEmpty)
    }

    // MARK: - Link resolution & slugs

    func testIsExternalURL() {
        let p = makePager()
        XCTAssertTrue(p.isExternalURL("https://example.com"))
        XCTAssertTrue(p.isExternalURL("mailto:a@b.com"))
        XCTAssertFalse(p.isExternalURL("other.md"))
        XCTAssertFalse(p.isExternalURL("file:///x.md"))
    }

    func testIsMarkdownPath() {
        let p = makePager()
        XCTAssertTrue(p.isMarkdownPath(URL(fileURLWithPath: "/x/a.md")))
        XCTAssertTrue(p.isMarkdownPath(URL(fileURLWithPath: "/x/a.markdown")))
        XCTAssertFalse(p.isMarkdownPath(URL(fileURLWithPath: "/x/a.png")))
    }

    func testResolveLink() {
        let p = makePager()
        let base = URL(fileURLWithPath: "/tmp/docs/", isDirectory: true)
        XCTAssertEqual(p.resolveLink("other.md", base: base)?.path, "/tmp/docs/other.md")
        // fragment / query are stripped before resolving
        XCTAssertEqual(p.resolveLink("other.md#sec", base: base)?.path, "/tmp/docs/other.md")
        // a pure anchor has no path → nil
        XCTAssertNil(p.resolveLink("#anchor", base: base))
    }

    func testSlug() {
        let p = makePager()
        XCTAssertEqual(p.slug("Hello World"), "hello-world")
        XCTAssertEqual(p.slug("API v2"), "api-v2")
        XCTAssertEqual(p.slug("C++"), "c")
    }

    func testHeadingIndexForAnchor() {
        let p = makePager(headings: [HeadingInfo(lineIndex: 0, level: 1, text: "Introduction"),
                                     HeadingInfo(lineIndex: 5, level: 2, text: "Usage")])
        XCTAssertEqual(p.headingIndex(forAnchor: "#introduction"), 0)
        XCTAssertEqual(p.headingIndex(forAnchor: "#usage"), 1)
        XCTAssertNil(p.headingIndex(forAnchor: "#missing"))
    }

    // MARK: - Viewport helpers

    func testNearestCodeBlock() {
        let p = makePager()
        let blocks = [Pager.CodeBlockInfo(range: 0..<3, text: "a"),
                      Pager.CodeBlockInfo(range: 20..<25, text: "b")]
        XCTAssertEqual(p.nearestCodeBlock(blocks, top: 0, rows: 10)?.text, "a")   // ref 5
        XCTAssertEqual(p.nearestCodeBlock(blocks, top: 18, rows: 10)?.text, "b")  // ref 23
        XCTAssertNil(p.nearestCodeBlock([], top: 0, rows: 10))
    }

    func testFirstVisibleLink() {
        let p = makePager(links: [LinkInfo(lineIndex: 2, url: "a", text: "a"),
                                  LinkInfo(lineIndex: 30, url: "b", text: "b")])
        XCTAssertEqual(p.firstVisibleLink(top: 0, rows: 10), 0)   // link on line 2 visible
        XCTAssertEqual(p.firstVisibleLink(top: 20, rows: 5), 1)   // fallback: first at/after top
    }

    // MARK: - Search

    func testPerformSearch() {
        var p = makePager()
        p.plainLines = ["the quick brown", "the lazy dog", "nothing here"]
        p.searchQuery = "the"
        p.performSearch()
        XCTAssertEqual(p.searchMatches.count, 2)
        XCTAssertEqual(p.searchMatches[0].lineIndex, 0)
        XCTAssertEqual(p.searchMatches[0].range, 0..<3)
        XCTAssertEqual(p.searchMatches[1].lineIndex, 1)
    }

    func testPerformSearchMultiplePerLineCaseInsensitive() {
        var p = makePager()
        p.plainLines = ["aXAxa"]
        p.searchQuery = "a"
        p.performSearch()
        XCTAssertEqual(p.searchMatches.count, 3)   // positions 0, 2, 4 (case-insensitive)
    }

    // MARK: - Navigation & tabs (state transitions)

    func testNavigateAndGoBack() {
        var p = makePager()
        let a = URL(fileURLWithPath: "/tmp/a.md")
        let b = URL(fileURLWithPath: "/tmp/b.md")
        p.currentURL = a; p.titleText = "a.md"
        p.navigate(to: b, query: nil)
        XCTAssertEqual(p.currentURL, b)
        XCTAssertEqual(p.navStack, [a])
        XCTAssertEqual(p.titleText, "b.md")
        XCTAssertEqual(p.top, 0)
        p.goBack()
        XCTAssertEqual(p.currentURL, a)
        XCTAssertTrue(p.navStack.isEmpty)
    }

    func testTabOpenSwitchClose() {
        var p = makePager()
        let a = URL(fileURLWithPath: "/tmp/a.md")
        let b = URL(fileURLWithPath: "/tmp/b.md")
        p.currentURL = a; p.titleText = "a.md"
        p.tabs = [p.liveTabState()]
        p.activeTab = 0

        p.openInNewTab(b)
        XCTAssertEqual(p.tabs.count, 2)
        XCTAssertEqual(p.activeTab, 1)
        XCTAssertEqual(p.currentURL, b)
        XCTAssertEqual(p.titleText, "b.md")

        // switch back to tab 0 (snapshot live state first, as the loop does)
        p.snapshot(); p.activate(0)
        XCTAssertEqual(p.activeTab, 0)
        XCTAssertEqual(p.currentURL, a)

        // closing the active tab drops to the remaining one
        XCTAssertTrue(p.closeActiveTab())
        XCTAssertEqual(p.tabs.count, 1)
        XCTAssertEqual(p.currentURL, b)

        // closing the last tab returns false (caller exits the viewer)
        XCTAssertFalse(p.closeActiveTab())
    }
}
