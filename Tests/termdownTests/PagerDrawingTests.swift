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
                       searchQuery: "", linkFocus: nil, foldedHeadings: [], lastModDate: nil,
                       cursorLine: 0)
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

    // MARK: - Mouse text selection

    private func selectionPager() -> Pager {
        var p = Pager(title: "doc.md", lines: [])
        p.lines = (0..<30).map { "line \($0) with some text" }
        p.plainLines = p.lines
        p.mouseSelectEnabled = true
        return p
    }

    /// The frame invariant, swept across content classes, widths and pager
    /// states. Autowrap is off, so a row that measures wrong is not merely ugly
    /// — it desyncs every later redraw. The single-state ASCII test below is the
    /// origin of this sweep; wide and zero-width content is where the width
    /// table is actually at risk.
    func testFrameRowsAreExactlyColsWideAcrossStatesAndContent() {
        let corpus: [(String, [String])] = [
            ("ascii", (0..<30).map { "line \($0) with some text" }),
            ("cjk", (0..<30).map { "行 \($0) 日本語 中文 한국어 テスト" }),
            ("emoji", (0..<30).map { "row \($0) ✅ ⭐ 😀 ❤️ ⚠️ done" }),
            ("zwj", (0..<30).map { "fam \($0) 👨‍👩‍👧 👩‍💻 🏳️‍🌈 end" }),
            ("skin-tone", (0..<30).map { "tone \($0) 👍🏻 👍🏽 👍🏿 end" }),
            ("flags", (0..<30).map { "flag \($0) 🇺🇸 🇩🇪 🇯🇵 end" }),
            ("combining", (0..<30).map { "acc \($0) e\u{301}a\u{300}u\u{308} end" }),
            ("mixed", (0..<30).map { "mix \($0) 日本 ✅ ❤️ 👍🏽 abc" }),
        ]
        let states: [(String, (inout Pager) -> Void)] = [
            ("plain", { _ in }),
            ("cursor", { p in p.cursorVisible = true; p.cursorLine = 2 }),
            ("line-selection", { p in p.cursorVisible = true; p.cursorLine = 4; p.selectionAnchor = 1 }),
            ("text-selection", { p in
                p.textSelection = TextSelection(anchor: TextPoint(line: 1, col: 3),
                                                head: TextPoint(line: 3, col: 9))
            }),
        ]
        for (contentName, lines) in corpus {
            for (stateName, apply) in states {
                for cols in [40, 60, 80, 120] {
                    for wrapOn in [true, false] {
                        var p = Pager(title: "doc.md", lines: [])
                        p.lines = lines
                        p.plainLines = lines
                        p.mouseSelectEnabled = true
                        apply(&p)
                        let available = max(20, cols - 4)
                        let frame = p.buildFrame(
                            top: 0, contentRows: 8, cols: cols, maxTop: 20, available: available,
                            sidebarActive: false, sidebarFocus: false, sidebarCursor: 0,
                            wrapOn: wrapOn, hscroll: wrapOn ? 0 : 4, followMode: false,
                            reloadFlashActive: false, title: "doc.md",
                            searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                            searchMode: false, gotoMode: false, gotoInput: "",
                            linkFocus: nil, copyFlash: nil)
                        for (i, row) in frame.enumerated() {
                            XCTAssertEqual(
                                Ansi.width(row), cols,
                                "\(contentName)/\(stateName)/cols=\(cols)/wrap=\(wrapOn) row \(i) "
                                    + "measured \(Ansi.width(row))")
                        }
                    }
                }
            }
        }
    }

    /// The frame invariant: autowrap is off, so every row must be exactly `cols`
    /// display columns. A selection tint inserts escape sequences only, so it
    /// must not change any row's measured width — if it did, the right border
    /// and scrollbar column would be clipped away under tmux.
    func testSelectionKeepsEveryRowExactlyColsWide() {
        var p = selectionPager()
        p.textSelection = TextSelection(anchor: TextPoint(line: 1, col: 4),
                                        head: TextPoint(line: 3, col: 8))
        let frame = p.buildFrame(top: 0, contentRows: 10, cols: 80, maxTop: 20, available: 70,
                                 sidebarActive: false, sidebarFocus: false, sidebarCursor: 0,
                                 wrapOn: true, hscroll: 0, followMode: false,
                                 reloadFlashActive: false, title: "doc.md",
                                 searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                                 searchMode: false, gotoMode: false, gotoInput: "",
                                 linkFocus: nil, copyFlash: nil)
        for (i, row) in frame.enumerated() {
            XCTAssertEqual(Ansi.width(row), 80, "row \(i) is \(Ansi.width(row)) cols, not 80")
        }
    }

    /// Selection columns are stored in content coordinates, so a horizontally
    /// scrolled viewport must shift them left by `hscroll` — otherwise the tint
    /// slides away from the text it belongs to.
    func testSelectionShiftsWithHorizontalScroll() {
        var p = selectionPager()
        p.lines = ["0123456789abcdefghij"]
        p.plainLines = p.lines
        // Content columns 10..<14 ("abcd") with the view scrolled right by 10
        // land on screen columns 0..<4 of the clipped row.
        p.textSelection = TextSelection(anchor: TextPoint(line: 0, col: 10),
                                        head: TextPoint(line: 0, col: 14))
        let frame = p.buildFrame(top: 0, contentRows: 3, cols: 40, maxTop: 0, available: 30,
                                 sidebarActive: false, sidebarFocus: false, sidebarCursor: 0,
                                 wrapOn: false, hscroll: 10, followMode: false,
                                 reloadFlashActive: false, title: "doc.md",
                                 searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                                 searchMode: false, gotoMode: false, gotoInput: "",
                                 linkFocus: nil, copyFlash: nil)
        let bg = Ansi.code(Ansi.bg(Ansi.Pastel.selectBg))
        let parts = frame[0].components(separatedBy: bg)
        XCTAssertEqual(parts.count, 2, frame[0].debugDescription)
        // Everything before the tint is chrome only — the tint starts at "abcd".
        XCTAssertEqual(Ansi.strip(parts[0]), "  ")
        XCTAssertTrue(Ansi.strip(parts[1]).hasPrefix("abcd"), Ansi.strip(parts[1]))
        XCTAssertEqual(Ansi.width(frame[0]), 40)
    }

    /// Tinting must not disturb the text itself — same visible characters with
    /// and without a selection.
    func testSelectionLeavesVisibleTextUnchanged() {
        var plain = selectionPager()
        let base = plain.buildFrame(top: 0, contentRows: 10, cols: 80, maxTop: 20, available: 70,
                                    sidebarActive: false, sidebarFocus: false, sidebarCursor: 0,
                                    wrapOn: true, hscroll: 0, followMode: false,
                                    reloadFlashActive: false, title: "doc.md",
                                    searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                                    searchMode: false, gotoMode: false, gotoInput: "",
                                    linkFocus: nil, copyFlash: nil)
        var sel = selectionPager()
        sel.textSelection = TextSelection(anchor: TextPoint(line: 1, col: 4),
                                          head: TextPoint(line: 3, col: 8))
        let tinted = sel.buildFrame(top: 0, contentRows: 10, cols: 80, maxTop: 20, available: 70,
                                    sidebarActive: false, sidebarFocus: false, sidebarCursor: 0,
                                    wrapOn: true, hscroll: 0, followMode: false,
                                    reloadFlashActive: false, title: "doc.md",
                                    searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                                    searchMode: false, gotoMode: false, gotoInput: "",
                                    linkFocus: nil, copyFlash: nil)
        XCTAssertEqual(base.map { Ansi.strip($0) }, tinted.map { Ansi.strip($0) })
    }
}
