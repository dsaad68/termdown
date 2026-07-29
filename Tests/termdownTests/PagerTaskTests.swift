import XCTest
@testable import termdown
@testable import termdownCore

/// End-to-end tests for toggling task checkboxes from the viewer: cursor → span
/// → source line → buffer → Ctrl-S.
final class PagerTaskTests: XCTestCase {

    private func tempFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("td-task-\(UUID().uuidString).md")
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
        p.maxTop = max(0, p.lines.count - rows)   // the run loop's job; do it by hand here
        return p
    }

    /// Display index of the first rendered row containing `needle`.
    private func row(_ needle: String, in p: Pager) -> Int {
        for (i, line) in p.lines.enumerated() where Ansi.strip(line).contains(needle) { return i }
        XCTFail("row containing \(needle) not found"); return 0
    }

    /// Put the cursor on the row showing `needle`, in cursor mode.
    private func focus(_ needle: String, in p: inout Pager) {
        p.cursorVisible = true
        p.setCursor(row(needle, in: p))
    }

    // MARK: - The happy path

    func testSpaceTogglesTaskUnderCursor() throws {
        let url = try tempFile("# Todo\n\n- [ ] buy milk\n- [ ] walk dog\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        focus("buy milk", in: &p)

        _ = p.handleKey(.char(" "))
        XCTAssertTrue(p.isDirty, "toggling marks the document unsaved")
        XCTAssertTrue(p.rawSource.contains("- [x] buy milk"))
        XCTAssertTrue(p.rawSource.contains("- [ ] walk dog"), "other items untouched")

        _ = p.handleKey(.ctrlS)
        XCTAssertFalse(p.isDirty)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8),
                       "# Todo\n\n- [x] buy milk\n- [ ] walk dog\n")
    }

    func testToggleIsReversible() throws {
        let url = try tempFile("- [x] done already\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        focus("done already", in: &p)

        _ = p.handleKey(.char(" "))
        XCTAssertTrue(p.rawSource.contains("- [ ] done already"))
        p.reflowIfNeeded(renderWidth: 80)
        focus("done already", in: &p)
        _ = p.handleKey(.char(" "))
        XCTAssertTrue(p.rawSource.contains("- [x] done already"))
    }

    func testCursorStaysOnTheItemAfterToggling() throws {
        let url = try tempFile("- [ ] alpha\n- [ ] beta\n- [ ] gamma\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        focus("beta", in: &p)

        _ = p.handleKey(.char(" "))
        p.reflowIfNeeded(renderWidth: 80)
        p.applyPendingCursor()
        XCTAssertEqual(p.cursorLine, row("beta", in: p), "cursor re-anchors to the toggled item")
    }

    func testTogglingNestedItemLeavesParentAlone() throws {
        let url = try tempFile("- [ ] parent\n  - [ ] child\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        focus("child", in: &p)

        _ = p.handleKey(.char(" "))
        XCTAssertTrue(p.rawSource.contains("- [ ] parent"), "parent untouched")
        XCTAssertTrue(p.rawSource.contains("  - [x] child"), "indentation preserved")
    }

    func testWrappedTaskTogglesFromAContinuationRow() throws {
        let long = String(repeating: "word ", count: 30)
        let url = try tempFile("- [ ] \(long)\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url, width: 40)
        let first = row("word", in: p)
        p.cursorVisible = true
        p.setCursor(first + 1)   // a continuation row of the same item

        _ = p.handleKey(.char(" "))
        XCTAssertTrue(p.rawSource.hasPrefix("- [x] "), "continuation row resolves to the same checkbox")
    }

    func testTaskRespectsFrontmatterOffset() throws {
        let url = try tempFile("---\ntitle: x\n---\n\n- [ ] after frontmatter\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        focus("after frontmatter", in: &p)

        _ = p.handleKey(.char(" "))
        _ = p.handleKey(.ctrlS)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8),
                       "---\ntitle: x\n---\n\n- [x] after frontmatter\n")
    }

    // MARK: - Space keeps its page-down meaning

    func testSpacePagesDownOutsideCursorMode() throws {
        let items = (1...80).map { "- [ ] item \($0)" }.joined(separator: "\n")
        let url = try tempFile(items + "\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url, rows: 10)
        XCTAssertFalse(p.cursorVisible)

        _ = p.handleKey(.char(" "))
        XCTAssertTrue(p.top > 0, "Space still pages down when the cursor is hidden")
        XCTAssertFalse(p.isDirty, "and touches nothing")
    }

    func testSpacePagesDownOnANonTaskLine() throws {
        let body = "# Heading\n\n" + (1...80).map { "para \($0)" }.joined(separator: "\n\n")
        let url = try tempFile(body + "\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url, rows: 10)
        focus("para 1", in: &p)
        let before = p.cursorLine

        _ = p.handleKey(.char(" "))
        XCTAssertFalse(p.isDirty, "no checkbox here, nothing edited")
        XCTAssertTrue(p.cursorLine > before, "falls through to page-down")
    }

    func testPageDownKeysNeverToggle() throws {
        let url = try tempFile("- [ ] keep me\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        focus("keep me", in: &p)

        _ = p.handleKey(.char("f"))
        _ = p.handleKey(.pageDown)
        XCTAssertFalse(p.isDirty, "f and PgDn page down even on a task line")
        XCTAssertTrue(p.rawSource.contains("- [ ] keep me"))
    }

    // MARK: - Guards

    func testToggleWithoutAFileIsANoop() {
        var p = Pager(title: "t", lines: ["- [ ] x"])
        p.cursorVisible = true
        p.rawSource = "- [ ] x"
        p.dispSourceSpans = [SourceSpan(start: 1, end: 1)]
        XCTAssertFalse(p.toggleTaskUnderCursor(), "no currentURL → nothing to save into")
        XCTAssertFalse(p.isDirty)
    }

    func testTaskSourceLineFindsNothingOnProse() throws {
        let url = try tempFile("just a paragraph\n")
        defer { try? FileManager.default.removeItem(at: url) }
        var p = loadedPager(file: url)
        focus("just a paragraph", in: &p)
        XCTAssertNil(p.taskSourceLine())
    }
}
