import XCTest
@testable import termdown
@testable import termdownCore

/// Tests for the line cursor and inline block editing.
final class PagerEditTests: XCTestCase {

    // MARK: - applyEdit (pure)

    func testApplyEditSingleLine() {
        XCTAssertEqual(
            Pager.applyEdit(source: "a\nb\nc", span: SourceSpan(start: 2, end: 2), newLines: ["B"]),
            "a\nB\nc")
    }

    func testApplyEditMultiLineSpanCollapses() {
        XCTAssertEqual(
            Pager.applyEdit(source: "a\nb\nc", span: SourceSpan(start: 1, end: 2), newLines: ["X"]),
            "X\nc")
    }

    func testApplyEditExpandsLineCount() {
        XCTAssertEqual(
            Pager.applyEdit(source: "a\nb\nc", span: SourceSpan(start: 2, end: 2), newLines: ["x", "y"]),
            "a\nx\ny\nc")
    }

    func testApplyEditPreservesTrailingNewline() {
        XCTAssertEqual(
            Pager.applyEdit(source: "a\nb\n", span: SourceSpan(start: 1, end: 1), newLines: ["A"]),
            "A\nb\n")
    }

    func testApplyEditOutOfRangeIsNoop() {
        XCTAssertEqual(
            Pager.applyEdit(source: "a\nb", span: SourceSpan(start: 9, end: 9), newLines: ["z"]),
            "a\nb")
    }

    // MARK: - Cursor movement

    private func pager(lineCount: Int, rows: Int) -> Pager {
        var p = Pager(title: "t", lines: Array(repeating: "x", count: lineCount))
        p.lines = Array(repeating: "x", count: lineCount)
        p.contentRows = rows
        return p
    }

    func testCursorMovesWithinShortDocWithoutScrolling() {
        var p = pager(lineCount: 5, rows: 20)   // doc fits on screen
        p.setCursor(4)
        XCTAssertEqual(p.cursorLine, 4)
        XCTAssertEqual(p.top, 0)                // nothing to scroll
    }

    func testCursorScrollsViewportAtMargin() {
        var p = pager(lineCount: 100, rows: 10)
        p.setCursor(50)
        XCTAssertEqual(p.cursorLine, 50)
        XCTAssertTrue(p.top > 0, "viewport should have scrolled")
        XCTAssertTrue(p.cursorLine >= p.top && p.cursorLine < p.top + 10, "cursor stays visible")
    }

    func testCursorReachesLastLine() {
        var p = pager(lineCount: 100, rows: 10)
        p.setCursor(99)
        XCTAssertEqual(p.cursorLine, 99)
        XCTAssertTrue(p.cursorLine < p.top + 10)
    }

    func testClampCursorPullsIntoView() {
        var p = pager(lineCount: 100, rows: 10)
        p.top = 40
        p.cursorLine = 0          // above the viewport
        p.clampCursorToView()
        XCTAssertEqual(p.cursorLine, 40)   // pulled to the top of the window
    }

    // MARK: - Edit mode (end-to-end against a temp file)

    private func tempFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("td-edit-\(UUID().uuidString).md")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func loadedPager(file url: URL, width: Int = 80, rows: Int = 20) -> Pager {
        var p = Pager(title: url.lastPathComponent, lines: [])
        p.currentURL = url
        p.contentRows = rows
        p.renderFile = { fileURL, w in
            guard let s = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
            return AnsiRenderer(width: w, theme: .dark).render(s)
        }
        p.renderText = { s, w in AnsiRenderer(width: w, theme: .dark).render(s) }
        p.currentRenderWidth = -1
        p.reflowIfNeeded(renderWidth: width)
        return p
    }

    /// Display index of the first rendered row containing `needle`.
    private func row(_ needle: String, in p: Pager) -> Int {
        for (i, line) in p.lines.enumerated() where Ansi.strip(line).contains(needle) { return i }
        XCTFail("row containing \(needle) not found"); return 0
    }

    func testBeginEditSeedsBufferFromSource() throws {
        let url = try tempFile("# Title\n\nHello world\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("Hello world", in: p))
        p.beginEdit()
        XCTAssertTrue(p.editMode)
        XCTAssertEqual(p.editBuffer, ["Hello world"])
        XCTAssertEqual(p.editFileSpan?.start, 3)
    }

    func testBeginEditOnBlankLineIsNoop() throws {
        let url = try tempFile("# Title\n\ntext\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        // The final trailing rows are synthetic (nil span).
        p.cursorLine = p.lines.count - 1
        p.beginEdit()
        XCTAssertFalse(p.editMode)
    }

    func testEditCommitIsDirtyButUnwritten() throws {
        let url = try tempFile("# Title\n\nHello\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("Hello", in: p))
        p.beginEdit()
        p.handleEditMode(.char("!"))           // caret at end of "Hello" → "Hello!"
        p.handleEditMode(.enter)               // commit to buffer (NOT disk)
        XCTAssertFalse(p.editMode)
        XCTAssertTrue(p.isDirty)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# Title\n\nHello\n")  // unchanged
        _ = p.handleKey(.ctrlS)                // explicit save
        XCTAssertFalse(p.isDirty)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# Title\n\nHello!\n")
    }

    func testCancelEditLeavesFileUnchanged() throws {
        let original = "# Title\n\nHello\n"
        let url = try tempFile(original)
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("Hello", in: p))
        p.beginEdit()
        p.handleEditMode(.char("Z"))
        p.handleEditMode(.escape)
        XCTAssertFalse(p.editMode)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
    }

    func testEditRespectsFrontmatterOffset() throws {
        let url = try tempFile("---\ntitle: x\n---\n\n# Heading\n\nbody text\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("body text", in: p))
        XCTAssertEqual(p.dispSourceSpans[p.cursorLine]?.start, 7)   // file line 7
        p.beginEdit()
        XCTAssertEqual(p.editBuffer, ["body text"])
        p.handleEditMode(.char("!"))
        p.handleEditMode(.enter)
        _ = p.handleKey(.ctrlS)
        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(written, "---\ntitle: x\n---\n\n# Heading\n\nbody text!\n")
    }

    func testEditListItemChangesOnlyThatItem() throws {
        let url = try tempFile("- one\n- two\n- three\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("two", in: p))
        p.beginEdit()
        XCTAssertEqual(p.editBuffer, ["- two"])     // per-item granularity
        p.handleEditMode(.char("!"))
        p.handleEditMode(.enter)
        _ = p.handleKey(.ctrlS)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "- one\n- two!\n- three\n")
    }

    func testEditTableRowChangesOnlyThatRow() throws {
        let url = try tempFile("| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("3", in: p))               // the "| 3 | 4 |" body row
        p.beginEdit()
        XCTAssertEqual(p.editBuffer, ["| 3 | 4 |"]) // per-row granularity
        p.handleEditMode(.char("!"))
        p.handleEditMode(.enter)
        _ = p.handleKey(.ctrlS)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8),
                       "| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |!\n")
    }

    // MARK: - Drawing path

    func testStatusBarShowsCursorSourceLine() {
        var p = Pager(title: "t", lines: Array(repeating: "x", count: 20))
        p.lines = Array(repeating: "x", count: 20)
        p.dispSourceSpans = (1...20).map { SourceSpan(start: $0, end: $0) }
        p.cursorVisible = true
        p.cursorLine = 4
        let bar = p.statusBar(top: 0, contentRows: 10, cols: 80, maxTop: 10, wrapOn: true,
                              followMode: false, reloadFlashActive: false, title: "t",
                              searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                              searchMode: false, gotoMode: false, gotoInput: "",
                              sidebarFocus: false, sidebarCursor: 0, linkFocus: nil)
        XCTAssertTrue(Ansi.strip(bar).contains("L5"), Ansi.strip(bar))   // span start for cursorLine 4
    }

    func testEditModeFrameShowsFieldInPlace() throws {
        let url = try tempFile("# Title\n\nHello\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url, rows: 12)
        p.maxTop = max(0, p.lines.count - p.contentRows)
        p.setCursor(row("Hello", in: p))
        p.beginEdit()
        p.handleEditMode(.char("!"))
        let frame = p.buildFrame(top: p.top, contentRows: p.contentRows, cols: 80, maxTop: p.maxTop,
                                 available: 76, sidebarActive: false, sidebarFocus: false, sidebarCursor: 0,
                                 wrapOn: true, hscroll: 0, followMode: false, reloadFlashActive: false,
                                 title: "t", searchQuery: "", searchMatches: [], currentMatchIndex: 0,
                                 searchMode: false, gotoMode: false, gotoInput: "", linkFocus: nil,
                                 copyFlash: nil)
        let text = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(text.contains("Hello!"), text)   // editable raw line shown in place
        XCTAssertTrue(text.contains("EDIT"), text)      // status bar mode label
    }

    func testEditingNeedsAFile() {
        var p = Pager(title: "stdin", lines: ["x"])
        p.lines = ["x"]
        p.contentRows = 10
        p.dispSourceSpans = [SourceSpan(start: 1, end: 1)]
        p.rawSource = "x"
        p.beginEdit()
        XCTAssertFalse(p.editMode)   // no currentURL → editing disabled
    }

    // MARK: - Cursor visibility + selection

    func testCursorHiddenByDefaultScrolls() {
        var p = pager(lineCount: 100, rows: 10)
        p.maxTop = 90
        XCTAssertFalse(p.cursorVisible)
        _ = p.handleKey(.char("j"))
        XCTAssertEqual(p.top, 1)        // j scrolls when the cursor is hidden
    }

    func testVTogglesCursorAndMovesIt() {
        var p = pager(lineCount: 5, rows: 20)   // short doc, nothing to scroll
        _ = p.handleKey(.char("v"))
        XCTAssertTrue(p.cursorVisible)
        _ = p.handleKey(.char("j"))
        XCTAssertEqual(p.cursorLine, 1)
        XCTAssertEqual(p.top, 0)
        _ = p.handleKey(.char("v"))
        XCTAssertFalse(p.cursorVisible)
    }

    func testShiftJAutoEntersCursorModeAndSelects() {
        var p = pager(lineCount: 20, rows: 10)
        XCTAssertFalse(p.cursorVisible)
        _ = p.handleKey(.char("J"))        // Shift+J
        XCTAssertTrue(p.cursorVisible)
        _ = p.handleKey(.char("J"))
        XCTAssertEqual(p.selectionRange(), 0...2)
    }

    func testShiftArrowExtendsSelection() {
        var p = pager(lineCount: 20, rows: 10)
        _ = p.handleKey(.char("v"))
        _ = p.handleKey(.shiftDown)
        XCTAssertEqual(p.selectionRange(), 0...1)
    }

    func testPlainMotionClearsSelection() {
        var p = pager(lineCount: 20, rows: 10)
        _ = p.handleKey(.char("v"))
        _ = p.handleKey(.char("J"))
        XCTAssertNotNil(p.selectionAnchor)
        _ = p.handleKey(.char("j"))
        XCTAssertNil(p.selectionAnchor)
    }

    func testEscapeExitsCursorModeWithoutLeaving() {
        var p = pager(lineCount: 20, rows: 10)
        _ = p.handleKey(.char("v"))
        let leave = p.handleKey(.escape)
        XCTAssertFalse(leave)            // stayed in the viewer
        XCTAssertFalse(p.cursorVisible)  // just exited cursor mode
    }

    func testSelectedMarkdownSlicesRawSource() {
        var p = Pager(title: "t", lines: ["A", "B", "C"])
        p.lines = ["A", "B", "C"]
        p.plainLines = ["A", "B", "C"]
        p.dispSourceSpans = [SourceSpan(start: 1, end: 1), SourceSpan(start: 2, end: 2), SourceSpan(start: 3, end: 3)]
        p.rawSource = "alpha\nbeta\ngamma"
        p.cursorVisible = true
        p.selectionAnchor = 0
        p.cursorLine = 1
        XCTAssertEqual(p.selectionRange(), 0...1)
        XCTAssertEqual(p.selectedMarkdown(0...1), "alpha\nbeta")  // raw markdown, not "A\nB"
    }

    // MARK: - Dirty / save prompt

    func testQuitWhileDirtyPromptsThenSaves() throws {
        let url = try tempFile("# T\n\nHello\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("Hello", in: p))
        p.beginEdit(); p.handleEditMode(.char("!")); p.handleEditMode(.enter)
        XCTAssertTrue(p.isDirty)
        p.cursorVisible = false                 // skip the cursor-mode peel for this test
        XCTAssertFalse(p.handleKey(.char("q"))) // intercepted, doesn't leave
        XCTAssertTrue(p.savePromptMode)
        XCTAssertTrue(p.handleSavePrompt(.char("s")))   // save → leave
        XCTAssertFalse(p.isDirty)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# T\n\nHello!\n")
    }

    func testQuitWhileDirtyDiscards() throws {
        let url = try tempFile("# T\n\nHello\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("Hello", in: p))
        p.beginEdit(); p.handleEditMode(.char("!")); p.handleEditMode(.enter)
        p.cursorVisible = false
        _ = p.handleKey(.char("q"))
        XCTAssertTrue(p.handleSavePrompt(.char("d")))   // discard → leave
        XCTAssertFalse(p.isDirty)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# T\n\nHello\n")  // unchanged
    }

    func testSavePromptCancelStaysDirty() throws {
        let url = try tempFile("# T\n\nHello\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        p.setCursor(row("Hello", in: p))
        p.beginEdit(); p.handleEditMode(.char("!")); p.handleEditMode(.enter)
        p.cursorVisible = false
        _ = p.handleKey(.char("q"))
        XCTAssertFalse(p.handleSavePrompt(.escape))     // cancel → stay
        XCTAssertFalse(p.savePromptMode)
        XCTAssertTrue(p.isDirty)
    }
}
