import XCTest
@testable import termdown
@testable import termdownCore

/// Mouse events in modal states. Every modal branch in `run()` consumed the key
/// and continued, so these events were silently dropped — none of these paths
/// had any mouse coverage.
final class PagerModalMouseTests: XCTestCase {

    private func makePager(_ lines: [String] = Array(repeating: "some text here", count: 60),
                           headings: [HeadingInfo] = []) -> Pager {
        var p = Pager(title: "t", lines: lines, headings: headings)
        p.lines = lines
        p.plainLines = lines
        p.headings = headings
        p.contentRows = 10
        p.maxTop = max(0, lines.count - 10)
        p.top = 0
        p.sidebarActive = false
        return p
    }

    // MARK: - Fall-through

    func testNoModalMeansNoConsumption() {
        var p = makePager()
        XCTAssertFalse(p.handleModalMouse(.mouseScroll(3)), "normal view must fall through")
        XCTAssertFalse(p.handleModalMouse(.mouseClick(x: 5, y: 3)))
    }

    func testNonMouseKeysAreNeverConsumed() {
        var p = makePager()
        p.searchMode = true
        XCTAssertFalse(p.handleModalMouse(.char("a")))
        XCTAssertFalse(p.handleModalMouse(.enter))
        XCTAssertTrue(p.searchMode, "the keyboard path must still own these")
    }

    // MARK: - Search / goto

    func testScrollWorksWhileSearching() {
        var p = makePager()
        p.searchMode = true
        p.searchQuery = "text"
        XCTAssertTrue(p.handleModalMouse(.mouseScroll(3)))
        XCTAssertEqual(p.top, 3)
        XCTAssertTrue(p.searchMode, "scrolling must not dismiss the prompt")
        XCTAssertEqual(p.searchQuery, "text", "the query stays live")
    }

    func testClickOnContentAcceptsSearchAndPositionsCursor() {
        var p = makePager()
        p.searchMode = true
        p.top = 10
        XCTAssertTrue(p.handleModalMouse(.mouseClick(x: 5, y: 4)))
        XCTAssertFalse(p.searchMode)
        XCTAssertEqual(p.cursorLine, 13)      // top + (y - 1)
    }

    func testClickOnStatusBarCancelsGoto() {
        var p = makePager()
        p.gotoMode = true
        XCTAssertTrue(p.handleModalMouse(.mouseClick(x: 5, y: p.contentRows + 1)))
        XCTAssertFalse(p.gotoMode)
    }

    // MARK: - Save prompt

    /// A modal that answers on a stray click risks discarding unsaved work, so
    /// it stays deliberately inert.
    func testSavePromptIgnoresMouseEntirely() {
        var p = makePager()
        p.savePromptMode = true
        XCTAssertTrue(p.handleModalMouse(.mouseScroll(3)))
        XCTAssertTrue(p.handleModalMouse(.mouseClick(x: 5, y: 3)))
        XCTAssertTrue(p.savePromptMode, "must not be dismissed by a click")
        XCTAssertEqual(p.top, 0, "must not scroll underneath")
    }

    // MARK: - Theme picker

    func testScrollMovesThemeSelection() {
        var p = makePager()
        p.themePickerMode = true
        p.themePickerSel = 0
        var previewed: [String] = []
        p.onPreviewTheme = { previewed.append($0) }
        XCTAssertTrue(p.handleModalMouse(.mouseScroll(2)))
        XCTAssertEqual(p.themePickerSel, 2)
        XCTAssertFalse(previewed.isEmpty, "scrolling should live-preview")
    }

    func testClickOutsideThemeBoxCancels() {
        var p = makePager()
        p.themePickerMode = true
        p.currentThemeName = "dark"
        var previewed: [String] = []
        p.onPreviewTheme = { previewed.append($0) }
        XCTAssertTrue(p.handleModalMouse(.mouseClick(x: 1, y: 1)))
        XCTAssertFalse(p.themePickerMode)
        XCTAssertEqual(previewed.last, "dark", "cancelling restores the active theme")
    }

    // MARK: - Sidebar focus

    private func sidebarPager() -> Pager {
        let heads = (0..<20).map { HeadingInfo(lineIndex: $0 * 3, level: 1, text: "H\($0)") }
        var p = makePager(headings: heads)
        p.sidebarActive = true
        p.sidebarFocus = true
        p.sidebarCursor = 0
        return p
    }

    func testScrollMovesSidebarCursor() {
        var p = sidebarPager()
        XCTAssertTrue(p.handleModalMouse(.mouseScroll(3)))
        XCTAssertEqual(p.sidebarCursor, 3)
    }

    func testClickSelectsSidebarHeadingThenJumps() {
        var p = sidebarPager()
        // Row 1 is the panel header, so screen row 6 is outline entry 4 — far
        // enough down that the jump clears `scrolloff` and `top` actually moves.
        XCTAssertTrue(p.handleModalMouse(.mouseClick(x: 4, y: 6)))
        XCTAssertEqual(p.sidebarCursor, 4)
        XCTAssertEqual(p.top, 0, "first click only selects")
        XCTAssertTrue(p.handleModalMouse(.mouseClick(x: 4, y: 6)))
        XCTAssertEqual(p.top, p.headings[4].lineIndex - Pager.scrolloff, "second click jumps")
    }

    func testClickInContentAreaLeavesSidebarFocus() {
        var p = sidebarPager()
        let consumed = p.handleModalMouse(.mouseClick(x: Pager.sidebarWidth + 6, y: 3))
        XCTAssertFalse(consumed, "the event should fall through to the document")
        XCTAssertFalse(p.sidebarFocus)
    }

    func testSidebarHeadingIndexSkipsPanelHeader() {
        let p = sidebarPager()
        XCTAssertNil(p.sidebarHeadingIndex(atRow: 1, top: 0, contentRows: 10,
                                           sidebarFocus: true, sidebarCursor: 0))
        XCTAssertEqual(p.sidebarHeadingIndex(atRow: 2, top: 0, contentRows: 10,
                                             sidebarFocus: true, sidebarCursor: 0), 0)
    }

    // MARK: - List box geometry

    func testListBoxHitTesting() {
        let items = (0..<5).map { "item \($0)" }
        let size = Terminal.Size(rows: 30, cols: 100, widthPx: 0, heightPx: 0)
        let g = Terminal.listBoxGeometry(title: "Theme", items: items, selected: 0,
                                         hint: "hint", size: size)
        XCTAssertNil(g.itemIndex(atRow: g.startRow, count: items.count), "top border")
        XCTAssertEqual(g.itemIndex(atRow: g.startRow + 1, count: items.count), 0)
        XCTAssertEqual(g.itemIndex(atRow: g.startRow + 3, count: items.count), 2)
        XCTAssertNil(g.itemIndex(atRow: g.startRow + 99, count: items.count))
        XCTAssertTrue(g.contains(x: g.startCol, y: g.startRow))
        XCTAssertFalse(g.contains(x: 1, y: 1))
    }
}
