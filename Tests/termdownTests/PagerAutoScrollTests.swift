import XCTest
@testable import termdown
@testable import termdownCore

/// Word / line click escalation and the idle-tick autoscroll that keeps a drag
/// running while the pointer is held past an edge.
final class PagerAutoScrollTests: XCTestCase {

    /// A pager sized so screen col = content col + 3 and screen row = line + 1
    /// (no sidebar → chromeLeft = leftMargin = 2, so x = 1 + 2 + col).
    private func makePager(_ lines: [String]) -> Pager {
        var p = Pager(title: "test", lines: lines, links: [])
        p.lines = lines
        p.plainLines = lines.map { Ansi.strip($0) }
        p.contentRows = 10
        p.top = 0
        p.hscroll = 0
        p.sidebarActive = false
        p.mouseSelectEnabled = true
        return p
    }

    private func x(_ col: Int) -> Int { col + 3 }
    private func y(_ line: Int) -> Int { line + 1 }

    // MARK: - Multi-click

    func testWordRangeFindsWordUnderColumn() {
        let p = makePager(["The quick brown fox"])
        XCTAssertEqual(p.wordRange(line: 0, col: 6), 4..<9)    // inside "quick"
        XCTAssertEqual(p.wordRange(line: 0, col: 4), 4..<9)    // on its first cell
        XCTAssertEqual(p.wordRange(line: 0, col: 8), 4..<9)    // on its last cell
        XCTAssertNil(p.wordRange(line: 0, col: 3))             // the space
        XCTAssertNil(p.wordRange(line: 0, col: 99))            // past the end
    }

    /// Word boundaries are display columns, so a CJK prefix must not shift them.
    func testWordRangeUsesDisplayColumns() {
        let p = makePager(["日本 quick end"])   // "日本 " spans columns 0..<5
        XCTAssertEqual(p.wordRange(line: 0, col: 6), 5..<10)
    }

    func testDoubleClickSelectsWord() {
        var p = makePager(["The quick brown fox"])
        p.beginDrag(x: x(6), y: y(0))
        p.beginDrag(x: x(6), y: y(0))          // second press, same cell
        XCTAssertEqual(p.selectedText(p.textSelection!), "quick")
    }

    func testTripleClickSelectsLine() {
        var p = makePager(["The quick brown fox"])
        for _ in 0..<3 { p.beginDrag(x: x(6), y: y(0)) }
        XCTAssertEqual(p.selectedText(p.textSelection!), "The quick brown fox")
    }

    func testClickCountResetsOnADifferentCell() {
        var p = makePager(["The quick brown fox"])
        _ = p.registerClick(at: TextPoint(line: 0, col: 6))
        XCTAssertEqual(p.registerClick(at: TextPoint(line: 0, col: 12)), 1)
    }

    func testClickCountResetsAfterTheInterval() {
        var p = makePager(["The quick brown fox"])
        let t0 = Date()
        _ = p.registerClick(at: TextPoint(line: 0, col: 6), now: t0)
        let late = t0.addingTimeInterval(Pager.multiClickInterval + 0.1)
        XCTAssertEqual(p.registerClick(at: TextPoint(line: 0, col: 6), now: late), 1)
    }

    func testFourthClickStartsOver() {
        var p = makePager(["word here"])
        let t = Date()
        XCTAssertEqual(p.registerClick(at: TextPoint(line: 0, col: 1), now: t), 1)
        XCTAssertEqual(p.registerClick(at: TextPoint(line: 0, col: 1), now: t), 2)
        XCTAssertEqual(p.registerClick(at: TextPoint(line: 0, col: 1), now: t), 3)
        XCTAssertEqual(p.registerClick(at: TextPoint(line: 0, col: 1), now: t), 1)
    }

    // MARK: - Autoscroll while held

    func testTickAutoScrollContinuesWhilePointerHeldAtEdge() {
        var p = makePager(Array(repeating: "xxxxxxxxxx", count: 100))
        p.maxTop = 90
        p.beginDrag(x: x(0), y: y(0))
        p.extendDrag(x: x(4), y: p.contentRows + 1)   // past the bottom edge
        let afterDrag = p.top
        p.tickAutoScroll()                            // no further motion reported
        XCTAssertEqual(p.top, afterDrag + 1, "a held drag must keep scrolling")
        p.tickAutoScroll()
        XCTAssertEqual(p.top, afterDrag + 2)
    }

    func testTickAutoScrollInertWithoutADrag() {
        var p = makePager(Array(repeating: "x", count: 100))
        p.maxTop = 90
        p.top = 5
        p.tickAutoScroll()
        XCTAssertEqual(p.top, 5)
    }

    func testAutoScrollStopsWhenPointerReturnsInsideViewport() {
        var p = makePager(Array(repeating: "xxxxxxxxxx", count: 100))
        p.maxTop = 90
        p.beginDrag(x: x(0), y: y(0))
        p.extendDrag(x: x(4), y: p.contentRows + 1)
        p.extendDrag(x: x(4), y: y(2))               // back inside
        let held = p.top
        p.tickAutoScroll()
        XCTAssertEqual(p.top, held, "scrolling must stop once the pointer is back")
    }

    /// Live reload replaces every row underneath the selection, so its stored
    /// rows and columns would address different text than the highlight still
    /// shows — and `y` is in the preserve list, so pressing it would copy that
    /// other text without a visible cue. `reflowIfNeeded` already guards this;
    /// `pollReload` swaps the same state and has to guard it too.
    func testLiveReloadClearsSelection() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termdown-reload-\(UUID().uuidString).md")
        try "reloaded content here".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        var p = makePager(["The quick brown fox"])
        p.currentURL = url
        p.lastModDate = .distantPast          // any mtime counts as newer
        p.renderFile = { _, _ in
            RenderedDocument(lines: ["reloaded content here"], headings: [], links: [])
        }
        p.beginDrag(x: x(4), y: y(0))
        p.extendDrag(x: x(9), y: y(0))
        XCTAssertNotNil(p.textSelection)

        p.pollReload()
        XCTAssertNil(p.textSelection, "a reload must not leave a selection addressing the old rows")
    }

    func testReflowClearsSelection() {
        // Re-wrapping moves every row and column; a stale selection would paint
        // over unrelated text.
        var p = makePager(["The quick brown fox"])
        p.beginDrag(x: x(4), y: y(0))
        p.extendDrag(x: x(9), y: y(0))
        XCTAssertNotNil(p.textSelection)
        p.currentRenderWidth = 80
        p.reflowIfNeeded(renderWidth: 40)
        XCTAssertNil(p.textSelection)
    }
}
