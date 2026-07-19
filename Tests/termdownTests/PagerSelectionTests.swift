import XCTest
@testable import termdown
@testable import termdownCore

/// Character-precise mouse selection: the drag state machine, the column
/// geometry and the column-sliced copy.
final class PagerSelectionTests: XCTestCase {

    /// A pager sized so screen col = content col + 3 and screen row = line + 1
    /// (no sidebar → chromeLeft = leftMargin = 2, so x = 1 + 2 + col).
    private func makePager(_ lines: [String], links: [LinkInfo] = []) -> Pager {
        var p = Pager(title: "test", lines: lines, links: links)
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

    // MARK: - Column geometry

    func testColumnRangeSingleLine() {
        let sel = TextSelection(anchor: TextPoint(line: 1, col: 2),
                                head: TextPoint(line: 1, col: 6))
        XCTAssertEqual(sel.columnRange(forLine: 1, width: 40), 2..<6)
        XCTAssertNil(sel.columnRange(forLine: 0, width: 40))
        XCTAssertNil(sel.columnRange(forLine: 2, width: 40))
    }

    func testColumnRangeSpansMultipleLines() {
        // Text-flow shaped: first row runs to the edge, interior rows are full
        // width, the last row stops at the head column.
        let sel = TextSelection(anchor: TextPoint(line: 1, col: 4),
                                head: TextPoint(line: 3, col: 2))
        XCTAssertEqual(sel.columnRange(forLine: 1, width: 20), 4..<20)
        XCTAssertEqual(sel.columnRange(forLine: 2, width: 20), 0..<20)
        XCTAssertEqual(sel.columnRange(forLine: 3, width: 20), 0..<2)
    }

    func testBackwardDragNormalizes() {
        let forward = TextSelection(anchor: TextPoint(line: 1, col: 2),
                                    head: TextPoint(line: 3, col: 5))
        let backward = TextSelection(anchor: TextPoint(line: 3, col: 5),
                                     head: TextPoint(line: 1, col: 2))
        XCTAssertEqual(forward.columnRange(forLine: 2, width: 20),
                       backward.columnRange(forLine: 2, width: 20))
        XCTAssertEqual(backward.ordered.start, TextPoint(line: 1, col: 2))
        XCTAssertEqual(backward.ordered.end, TextPoint(line: 3, col: 5))
    }

    // MARK: - Copy

    func testSelectedTextSlicesByColumnOnOneLine() {
        var p = makePager(["The quick brown fox"])
        let sel = TextSelection(anchor: TextPoint(line: 0, col: 4),
                                head: TextPoint(line: 0, col: 9))
        p.textSelection = sel
        XCTAssertEqual(p.selectedText(sel), "quick")
    }

    func testSelectedTextSpansLinesAndTrimsPadding() {
        let p = makePager(["The quick brown fox jumps", "over the lazy dog."])
        // Mid-word on the first row ("br|own") through mid-word on the second.
        let sel = TextSelection(anchor: TextPoint(line: 0, col: 12),
                                head: TextPoint(line: 1, col: 13))
        XCTAssertEqual(p.selectedText(sel), "own fox jumps\nover the lazy")
    }

    func testSelectedTextSlicesByDisplayColumnNotCharacterIndex() {
        // Each CJK glyph is two columns wide: columns 2..<4 is the middle one,
        // which is character index 1 — the two must not be confused.
        let p = makePager(["日本語"])
        let sel = TextSelection(anchor: TextPoint(line: 0, col: 2),
                                head: TextPoint(line: 0, col: 4))
        XCTAssertEqual(p.selectedText(sel), "本")
    }

    // MARK: - Drag state machine

    func testDragBuildsSelectionAndCopiesOnRelease() {
        var p = makePager(["The quick brown fox"])
        p.beginDrag(x: x(4), y: y(0))
        XCTAssertNil(p.textSelection)          // a press alone selects nothing
        p.extendDrag(x: x(9), y: y(0))
        XCTAssertEqual(p.textSelection?.head, TextPoint(line: 0, col: 9))
        p.endDrag(x: x(9), y: y(0))
        // The highlight stays lit after release as confirmation of the copy.
        XCTAssertNotNil(p.textSelection)
        XCTAssertEqual(p.copyFlashMsg, "copied 5 chars")
    }

    func testReleaseWithoutMotionFollowsLink() {
        // Press-then-release on one spot is a click: the link still opens.
        var p = makePager(Array(repeating: "x", count: 30),
                          links: [LinkInfo(lineIndex: 2, url: "wikilink:Foo", text: "Foo",
                                           column: 4, length: 3)])
        p.beginDrag(x: x(4), y: y(2))
        p.endDrag(x: x(4), y: y(2))
        XCTAssertEqual(p.linkFocus, 0)
        XCTAssertNil(p.textSelection)
    }

    func testReleaseAfterMotionDoesNotFollowLink() {
        var p = makePager(Array(repeating: "xxxxxxxxxx", count: 30),
                          links: [LinkInfo(lineIndex: 2, url: "wikilink:Foo", text: "Foo",
                                           column: 4, length: 3)])
        p.beginDrag(x: x(4), y: y(2))
        p.extendDrag(x: x(7), y: y(2))
        p.endDrag(x: x(7), y: y(2))
        XCTAssertNil(p.linkFocus)              // dragged, so it selected instead
        XCTAssertNotNil(p.textSelection)
    }

    func testMouseSelectDisabledKeepsClickToOpen() {
        // Default config must behave exactly as before.
        var p = makePager(Array(repeating: "x", count: 30),
                          links: [LinkInfo(lineIndex: 2, url: "wikilink:Foo", text: "Foo",
                                           column: 4, length: 3)])
        p.mouseSelectEnabled = false
        _ = p.handleKey(.mouseClick(x: x(4), y: y(2)))
        XCTAssertEqual(p.linkFocus, 0)
        XCTAssertNil(p.textSelection)
    }

    func testDragClearsKeyboardSelection() {
        // The full-row matte and a character tint must never both be live.
        var p = makePager(Array(repeating: "xxxxx", count: 30))
        p.cursorVisible = true
        p.selectionAnchor = 3
        p.beginDrag(x: x(1), y: y(1))
        p.extendDrag(x: x(4), y: y(1))
        XCTAssertFalse(p.cursorVisible)
        XCTAssertNil(p.selectionAnchor)
    }

    func testBarePressKeepsKeyboardSelection() {
        // Only a real character selection takes the highlight over. A press that
        // turns out to be a click — following a link, or a stray one — must not
        // silently throw away a line selection built with `v` / `Shift+J`.
        var p = makePager(Array(repeating: "xxxxx", count: 30))
        p.cursorVisible = true
        p.selectionAnchor = 3
        p.beginDrag(x: x(1), y: y(1))
        XCTAssertTrue(p.cursorVisible)
        XCTAssertEqual(p.selectionAnchor, 3)
        p.endDrag(x: x(1), y: y(1))
        XCTAssertTrue(p.cursorVisible)
        XCTAssertEqual(p.selectionAnchor, 3)
    }

    func testPressOutsideContentDropsAStaleSelection() {
        // A drag leaves its highlight lit as copy confirmation. A later click on
        // the status bar has no anchor, so it must neither re-copy that stale
        // selection nor leave it addressable.
        var p = makePager(["The quick brown fox"])
        p.beginDrag(x: x(4), y: y(0))
        p.extendDrag(x: x(9), y: y(0))
        p.endDrag(x: x(9), y: y(0))
        XCTAssertNotNil(p.textSelection)
        p.copyFlashMsg = ""
        p.beginDrag(x: x(4), y: p.contentRows + 1)   // the status bar
        p.endDrag(x: x(4), y: p.contentRows + 1)
        XCTAssertNil(p.textSelection)
        XCTAssertEqual(p.copyFlashMsg, "", "a status-bar click must not re-copy")
    }

    func testPressInSidebarDoesNotStartASelection() {
        var p = makePager(Array(repeating: "xxxxx", count: 30))
        p.sidebarActive = true
        p.cursorVisible = true
        p.beginDrag(x: 1, y: y(1))                   // inside the outline column
        XCTAssertNil(p.dragAnchor)
        XCTAssertNil(p.textSelection)
        XCTAssertTrue(p.cursorVisible)
    }

    func testKeypressClearsSelectionButYRecopiesIt() {
        var p = makePager(["The quick brown fox"])
        p.beginDrag(x: x(4), y: y(0))
        p.extendDrag(x: x(9), y: y(0))
        p.endDrag(x: x(9), y: y(0))
        // `y` re-copies rather than clearing.
        _ = p.handleKey(.char("y"))
        XCTAssertNotNil(p.textSelection)
        XCTAssertEqual(p.copyFlashMsg, "copied 5 chars")
        // Any other key drops it.
        _ = p.handleKey(.char("j"))
        XCTAssertNil(p.textSelection)
    }

    func testDragPastBottomEdgeAutoscrolls() {
        var p = makePager(Array(repeating: "xxxxxxxxxx", count: 100))
        p.maxTop = 90
        p.beginDrag(x: x(0), y: y(0))
        XCTAssertEqual(p.top, 0)
        p.extendDrag(x: x(4), y: p.contentRows + 1)   // below the last content row
        XCTAssertEqual(p.top, 1)
        XCTAssertNotNil(p.textSelection)
    }

    func testDragAboveTopEdgeAutoscrollsUp() {
        var p = makePager(Array(repeating: "xxxxxxxxxx", count: 100))
        p.maxTop = 90
        p.top = 5
        p.beginDrag(x: x(0), y: y(2))
        // Terminals clamp to the window, so "above the viewport" arrives as the
        // topmost content row — y: 0 is a coordinate no terminal ever emits.
        p.extendDrag(x: x(4), y: y(0))
        XCTAssertEqual(p.top, 4)
    }

    func testDragAlongTheTopRowDoesNotAutoscroll() {
        // Selecting rightward across the first visible row is not an up-edge
        // gesture; scrolling there would run the document out from under it.
        var p = makePager(Array(repeating: "xxxxxxxxxx", count: 100))
        p.maxTop = 90
        p.top = 5
        p.beginDrag(x: x(0), y: y(0))
        p.extendDrag(x: x(6), y: y(0))
        XCTAssertEqual(p.top, 5)
        XCTAssertEqual(p.autoScrollDir, 0)
    }

    func testTickAutoScrollKeepsExtendingTheSelection() {
        // The head has to advance with `top`; deriving it from the last reported
        // pointer alone froze it after one tick while the document kept moving.
        var p = makePager(Array(repeating: "xxxxxxxxxx", count: 100))
        p.maxTop = 90
        p.beginDrag(x: x(0), y: y(0))
        p.extendDrag(x: x(4), y: p.contentRows + 1)
        let firstHead = p.textSelection!.head.line
        p.tickAutoScroll()
        XCTAssertEqual(p.textSelection?.head.line, firstHead + 1)
        p.tickAutoScroll()
        XCTAssertEqual(p.textSelection?.head.line, firstHead + 2)
    }

    func testDragAndReleaseIgnoredWhenMouseSelectDisabled() {
        var p = makePager(["The quick brown fox"])
        p.mouseSelectEnabled = false
        _ = p.handleKey(.mouseDrag(x: x(9), y: y(0)))
        _ = p.handleKey(.mouseRelease(x: x(9), y: y(0)))
        XCTAssertNil(p.textSelection)
        XCTAssertNil(p.copyFlashUntil)   // nothing was copied, so no toast
    }

    func testSelectionPointAccountsForHorizontalScroll() {
        // In no-wrap mode the viewport is scrolled right, so a screen column maps
        // to a content column further along the line.
        var p = makePager(["0123456789abcdefghij"])
        p.hscroll = 5
        XCTAssertEqual(p.selectionPoint(x: x(0), y: y(0)), TextPoint(line: 0, col: 5))
        XCTAssertEqual(p.selectionPoint(x: x(3), y: y(0)), TextPoint(line: 0, col: 8))
    }

    func testSelectionPointRejectsRowsOutsideViewport() {
        let p = makePager(["a", "b"])
        XCTAssertNil(p.selectionPoint(x: x(0), y: 0))                 // above row 1
        XCTAssertNil(p.selectionPoint(x: x(0), y: p.contentRows + 1)) // the status bar
    }

    func testSelectionPointAccountsForScrollOffset() {
        var p = makePager(Array(repeating: "xxxxx", count: 100))
        p.top = 20
        XCTAssertEqual(p.selectionPoint(x: x(2), y: y(3)), TextPoint(line: 23, col: 2))
    }

    func testSelectedTextClampsPastEndOfDocument() {
        // Autoscrolling to the bottom can leave the head beyond the last row.
        let p = makePager(["only line"])
        let sel = TextSelection(anchor: TextPoint(line: 0, col: 0),
                                head: TextPoint(line: 40, col: 5))
        XCTAssertEqual(p.selectedText(sel), "only line")
    }
}
