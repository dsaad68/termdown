import XCTest
@testable import termdown
@testable import termdownCore

/// Drawing tests for the folder browser: its rows, its own key legend, and the
/// breadcrumb row that opens the list. Split from `TerminalMenuDrawTests`, which
/// covers the launch chrome and sits on the 400-line lint ceiling.
final class TerminalMenuBrowseDrawTests: XCTestCase {

    private func entries(_ paths: [String]) -> [FileScanner.Entry] {
        paths.map { FileScanner.Entry(url: URL(fileURLWithPath: "/tmp/" + $0), relativePath: $0) }
    }

    /// A picker rooted on `~/notes`, browsing the folder `cwd`.
    private func browsing(_ cwd: String = "") -> TerminalMenu {
        var m = TerminalMenu(title: "termdown", items: ["a.md", "docs/b.md"], details: ["1d", "2h"])
        m.path = "~/notes"
        m.list.tree = FolderTree(entries: entries(m.items))
        m.list.mode = .folders
        m.list.cwd = cwd
        return m
    }

    /// Folder rows, as the browser shows them.
    private func folderRows(_ names: [String]) -> [MenuList.Visible] {
        names.map { name in
            MenuList.Visible(row: MenuList.Row(kind: .folder(name), label: name + "/", detail: "3 files"),
                             indices: [])
        }
    }

    /// File rows, for the tests that compare the two lists.
    private func filtered(_ items: [String]) -> [MenuList.Visible] {
        items.enumerated().map { index, label in
            MenuList.Visible(row: MenuList.Row(kind: .file(index), label: label, detail: ""),
                             indices: [])
        }
    }

    /// The browser has to look like a different list, not the same one with odd
    /// names in it: folder rows are teal and carry a trailing slash, and the
    /// header counts folders rather than files.
    func testFolderRowsAreTealAndCounted() {
        let m = browsing()
        let frame = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false, visible: folderRows(["docs", "notes"]),
                           total: 2, context: nil)
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("docs/"), plain)
        XCTAssertTrue(plain.contains("3 files"), plain)          // the per-folder count column
        XCTAssertTrue(plain.contains("2 folders"), plain)        // the header noun follows the mode
        XCTAssertFalse(plain.contains("2 files"), plain)

        // The selected row keeps the picker's bright-on-matte selection styling, so
        // the teal is what an *unselected* folder row is painted with.
        let notesRow = frame.first { Ansi.strip($0).contains("notes/") }
        let teal = Ansi.code(Ansi.fg(Ansi.Pastel.tealAccent))
        XCTAssertTrue(notesRow?.contains(teal) ?? false,
                      "folder name is not teal: \(notesRow.debugDescription)")
    }

    /// The browser's keys are its own, so it must advertise those and not the file
    /// list's — `d` there means "back to the files", and Enter means "go in".
    func testBrowserShowsItsOwnHints() {
        let m = browsing("docs")
        let plain = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 100,
                           query: "", searching: false, visible: folderRows(["docs/api"]),
                           total: 1, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("d files"), plain)
        XCTAssertTrue(plain.contains("up"), plain)
        XCTAssertFalse(plain.contains("/ search"), plain)
    }

    /// The header keeps the folder termdown was opened on — that is what says which
    /// window this is — and where you are *inside* it goes in a row of its own,
    /// relative to that folder, so the opened path is never repeated or rewritten.
    func testTheOpenedPathIsNeverRewritten() {
        let rows = browsing("docs/api")
            .draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 100,
                  query: "", searching: false, visible: folderRows(["docs/api/v1"]),
                  total: 1, context: nil)
            .map { Ansi.strip($0) }

        // Row 0 is the border and 1–3 the wordmark, so the subtitle is row 4.
        XCTAssertTrue(rows[4].contains("~/notes"), rows[4])
        XCTAssertFalse(rows[4].contains("~/notes/docs"), "the opened path was rewritten: \(rows[4])")
    }

    /// The breadcrumb belongs to the list, not the header: it sits just inside the
    /// separator, directly above the first row — including `../`, which is the way
    /// back out of the folder the breadcrumb names.
    func testTheBreadcrumbOpensTheListAboveTheUpRow() {
        var m = browsing("docs")
        m.list.tree = FolderTree(entries: entries(["docs/api/v1.md"]))
        let rows = m.draw(selected: 0, top: 0, viewport: 6, rows: 20, cols: 100,
                          query: "", searching: false,
                          visible: [MenuList.Visible(row: MenuList.Row(kind: .folder(""),
                                                                       label: "../", detail: "up"),
                                                     indices: [])]
                              + folderRows(["docs/api"]),
                          total: 2, context: nil)
            .map { Ansi.strip($0) }

        let separator = rows.firstIndex { $0.hasPrefix("\u{251C}") }
        XCTAssertNotNil(separator, rows.description)
        let crumb = separator! + 1
        XCTAssertTrue(rows[crumb].contains("\u{276F} docs"), "no chevron breadcrumb: \(rows[crumb])")
        XCTAssertTrue(rows[crumb + 1].contains("../"), "the up row is not under it: \(rows[crumb + 1])")
    }

    /// The row is carved out of the list, not the chrome, so the header above it
    /// never moves — `headerLines` and the click-to-row arithmetic both assume a
    /// fixed header — and the list gives up exactly one row for it.
    func testTheBreadcrumbCostsAListRowNotAHeaderRow() {
        let many = filtered((1...9).map { "file-\($0).md" })
        let atRoot = browsing().draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                                     query: "", searching: false, visible: many,
                                     total: 9, context: nil)
        var inside = browsing("docs")
        inside.list.scope = "docs"
        let deeper = inside.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                                 query: "", searching: false, visible: many,
                                 total: 9, context: nil)

        XCTAssertEqual(atRoot.count, deeper.count, "the frame changed height")
        let findBox = { (frame: [String]) in frame.firstIndex { Ansi.strip($0).contains("find") } }
        XCTAssertEqual(findBox(atRoot), findBox(deeper), "the header moved")

        let fileRows = { (frame: [String]) in frame.filter { Ansi.strip($0).contains("file-") }.count }
        XCTAssertEqual(fileRows(atRoot), 5)
        XCTAssertEqual(fileRows(deeper), 4, "the breadcrumb did not take a row from the list")
    }

    /// The deepest component is the answer the row exists to give, so a path too
    /// long for the terminal loses its *start*, not its end.
    func testALongBreadcrumbIsElidedFromTheLeft() {
        let parts = "one/two/three/four/five/six/seven/eight"
        let m = browsing(parts)
        for cols in [20, 24, 32, 40, 60, 80] {
            let rows = m.draw(selected: 0, top: 0, viewport: 3, rows: 16, cols: cols,
                              query: "", searching: false, visible: folderRows(["x"]),
                              total: 1, context: nil)
            for row in rows { XCTAssertEqual(Ansi.width(row), cols, Ansi.strip(row)) }

            // The row just inside the separator — the search box's caret is also a
            // chevron, so pick the row by position rather than by glyph.
            let plain = rows.map { Ansi.strip($0) }
            let crumb = plain[(plain.firstIndex { $0.hasPrefix("\u{251C}") } ?? 0) + 1]
            // Whatever else is dropped, the folder you are standing in survives —
            // the `… › ` marker has to be paid for out of the room for the
            // *ancestors*, which is the bug this caught: it was spent after the
            // components were chosen, so the tail overflowed and `fit` cut it.
            XCTAssertTrue(crumb.contains("eight"), "the folder we are in was cut at \(cols): \(crumb)")
            let elided = !crumb.contains("one \u{203A} two")
            XCTAssertEqual(elided, crumb.contains("\u{2026}"),
                           "elision and its marker disagree at \(cols): \(crumb)")
        }
    }

    /// Teal is how a folder row reads as a folder — but `--no-color` takes that
    /// away, so the trailing slash has to carry it alone, and no escape may be left
    /// behind in what is supposed to be plain text.
    func testWithoutColorAFolderIsStillMarkedByItsSlash() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = previous }

        let m = browsing()
        let frame = m.draw(selected: 0, top: 0, viewport: 4, rows: 20, cols: 60,
                           query: "", searching: false, visible: folderRows(["docs", "notes"]),
                           total: 2, context: nil)
        for row in frame {
            XCTAssertFalse(row.contains("\u{1B}"), "escape in --no-color output: \(row.debugDescription)")
            XCTAssertEqual(Ansi.width(row), 60, row)
        }
        let plain = frame.joined(separator: "\n")
        XCTAssertTrue(plain.contains("docs/"), plain)
        XCTAssertTrue(plain.contains("2 folders"), plain)
    }
}
