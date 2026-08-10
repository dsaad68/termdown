import XCTest
@testable import termdown
@testable import termdownCore

/// Tests for the file picker's chrome: the launch wordmark vs. the slim
/// contextual header used when the finder is opened for a new tab, and the
/// folder browser's rows.
final class TerminalMenuDrawTests: XCTestCase {

    private func sampleMenu() -> TerminalMenu {
        var m = TerminalMenu(title: "termdown",
                             items: ["a.md", "docs/b.md"],
                             details: ["1d", "2h"])
        m.path = "~/notes"
        m.list.tree = FolderTree(entries: entries(m.items))
        return m
    }

    private func entries(_ paths: [String]) -> [FileScanner.Entry] {
        paths.map { FileScanner.Entry(url: URL(fileURLWithPath: "/tmp/" + $0), relativePath: $0) }
    }

    /// File rows as the picker shows them, with nothing fuzzy-matched.
    private func filtered(_ items: [String], details: [String: String] = [:]) -> [MenuList.Visible] {
        items.enumerated().map { index, label in
            MenuList.Visible(row: MenuList.Row(kind: .file(index), label: label,
                                               detail: details[label] ?? ""),
                             indices: [])
        }
    }

    /// Folder rows, as the browser shows them.
    private func folderRows(_ names: [String]) -> [MenuList.Visible] {
        names.map { name in
            MenuList.Visible(row: MenuList.Row(kind: .folder(name), label: name + "/", detail: "3 files"),
                             indices: [])
        }
    }

    /// At launch the picker shows the "markdown viewer" tagline and no tab context.
    func testLaunchHeaderShowsTagline() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false,
                           visible: filtered(m.items, details: ["a.md": "1d", "docs/b.md": "2h"]),
                           total: m.items.count, context: nil)
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("markdown viewer"), plain)   // launch tagline
        XCTAssertTrue(plain.contains("v" + appVersion), plain)    // release version in the header
        XCTAssertFalse(plain.contains("New tab"), plain)
    }

    /// In "New tab" context the launch tagline is swapped for a slim picker header,
    /// while the top-border legend stays the app name (so the context isn't shown
    /// twice).
    func testContextHeaderReplacesLaunchChrome() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false,
                           visible: filtered(m.items, details: ["a.md": "1d", "docs/b.md": "2h"]),
                           total: m.items.count, context: "New tab")
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("New tab"), plain)           // slim contextual title
        XCTAssertTrue(plain.contains("pick a file"), plain)       // contextual hint
        XCTAssertFalse(plain.contains("markdown viewer"), plain)  // not the launch tagline
        XCTAssertTrue(plain.contains("termdown"), plain)          // legend stays the app name

        // The context label must appear exactly once (not duplicated in the legend).
        let occurrences = plain.lowercased().components(separatedBy: "new tab").count - 1
        XCTAssertEqual(occurrences, 1, plain)
    }

    /// The "termdown" legend above the new-tab finder uses the wordmark's
    /// per-letter gradient, not a single flat color.
    func testContextLegendIsGradient() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false, visible: filtered(m.items),
                           total: m.items.count, context: "New tab")
        let topBorder = frame[0]   // the legend lives on the top border row
        // The blue→mauve ramp's first and last stops must both appear (a gradient,
        // not a single flat color).
        XCTAssertTrue(topBorder.contains("38;5;75"), topBorder)   // 't' — blue stop
        XCTAssertTrue(topBorder.contains("38;5;183"), topBorder)  // 'n' — mauve stop
    }

    /// The launch view shows the app name once (the wordmark), with no duplicate
    /// legend tab on the top border. A narrow width forces the literal-text
    /// wordmark fallback so the name is countable in the stripped output.
    func testLaunchViewShowsNameOnce() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 3, rows: 16, cols: 30,
                           query: "", searching: false, visible: filtered(m.items),
                           total: m.items.count, context: nil)
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        let occurrences = plain.lowercased().components(separatedBy: "termdown").count - 1
        XCTAssertEqual(occurrences, 1, plain)
    }

    /// The search box is modal: unfocused it prompts to press `/`; focused it
    /// shows the typing affordance. This guards the fix where letters like q / c
    /// used to be intercepted as commands instead of filtering.
    func testSearchBoxReflectsFocus() {
        let m = sampleMenu()
        let unfocused = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                               query: "", searching: false, visible: filtered(m.items),
                               total: m.items.count, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(unfocused.contains("/ search"), unfocused)
        XCTAssertFalse(unfocused.contains("Esc done"), unfocused)

        let focused = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                             query: "cfg", searching: true, visible: filtered(["config.md"]),
                             total: m.items.count, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(focused.contains("cfg"), focused)        // the typed query is shown
        XCTAssertTrue(focused.contains("Esc done"), focused)   // focused-mode hint
    }

    /// The frame fills the full terminal height (11 chrome rows + viewport), so a
    /// plain `render` overwrites every row and no screen-clear flash is needed.
    func testFrameFillsRows() {
        let m = sampleMenu()
        let rows = 24
        let frame = m.draw(selected: 0, top: 0, viewport: rows - 11, rows: rows, cols: 80,
                           query: "", searching: false, visible: filtered(m.items),
                           total: m.items.count, context: nil)
        XCTAssertEqual(frame.count, rows)
    }

    // MARK: - Folder browser

    private func browsing(_ cwd: String = "") -> TerminalMenu {
        var m = sampleMenu()
        m.list.mode = .folders
        m.list.cwd = cwd
        return m
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

    /// The header path has to say which folder you are standing in; one level of a
    /// hierarchy otherwise looks exactly like another.
    func testHeaderPathFollowsTheBrowsedFolder() {
        let m = browsing("docs/api")
        let plain = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 100,
                           query: "", searching: false, visible: folderRows(["docs/api/v1"]),
                           total: 1, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("~/notes/docs/api"), plain)
    }

    /// A project with no folders is not a filter that matched nothing, and saying
    /// "no matching files" there would send the user looking for a query to clear.
    func testEmptyBrowserSaysThereAreNoFolders() {
        let m = browsing()
        let plain = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false, visible: [], total: 0, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("No folders here"), plain)

        // With a query it *is* a filter miss, and the noun follows the mode.
        let filteredOut = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                                 query: "zz", searching: false, visible: [], total: 4, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(filteredOut.contains("No matching folders"), filteredOut)
    }

    // MARK: - Every row is exactly `cols` wide

    /// Autowrap is off, so a row wider than the terminal does not wrap: it clips
    /// at the right margin and takes the frame's border with it. This file had
    /// no width assertions at all, which is how the picker header (a fixed ~53
    /// columns) and the find-box hint (a fixed ~79) went unnoticed.
    func testEveryRowIsExactlyColsWide() {
        // The fixtures have to *reach* every branch. The first version of this
        // sweep passed 2 items with `viewport: 3`, so `filteredItems.count >
        // viewport` was never true and the paginated bottom border — two columns
        // too wide at every size — went unnoticed. Likewise an empty filter, and
        // a query long enough to outgrow the search field.
        let m = sampleMenu()
        let many = (1...9).map { "file-\($0).md" }
        let corpus: [(String, [MenuList.Visible], Int)] = [
            ("two items", filtered(m.items), 3),
            ("paginated", filtered(many), 2),          // count > viewport
            ("empty filter", [], 3),                   // "No matching files"
            // The browser: a deep path in the header, long folder names, and the
            // per-folder count column all have to fit the same frame.
            ("folders", folderRows(["notes", "a-folder-with-a-very-long-name"]), 2),
        ]
        for cols in [4, 6, 10, 14, 18, 20, 24, 30, 40, 52, 60, 78, 80, 120] {
            for searching in [false, true] {
                for context in [nil, "New tab"] as [String?] {
                    for query in ["", "read", "a-fairly-long-search-query-typed-in-full"] {
                        for (label, items, viewport) in corpus {
                        var menu = m
                        if label == "folders" {
                            menu.list.mode = .folders
                            menu.list.cwd = "deeply/nested/folder/path"
                        }
                        let frame = menu.draw(selected: 0, top: 0, viewport: viewport, rows: 14,
                                              cols: cols, query: query, searching: searching,
                                              visible: items, total: max(items.count, 4),
                                              context: context)
                        for (index, row) in frame.enumerated() {
                            XCTAssertEqual(
                                Ansi.width(row), cols,
                                """
                                row \(index) is \(Ansi.width(row)) not \(cols) \
                                (\(label), searching: \(searching), \
                                context: \(context ?? "nil"), query: '\(query)')
                                \(Ansi.strip(row))
                                """)
                        }
                        }
                    }
                }
            }
        }
    }

    /// The caret has to stay visible: the field is what tells you what you are
    /// typing, and cutting it from the right removed both the cursor and the
    /// characters just entered while the list below kept filtering.
    func testTheSearchCaretStaysVisibleAsTheQueryGrows() {
        let m = sampleMenu()
        for cols in [30, 40, 60] {
            for length in [5, 20, 40, 80] {
                let query = String(repeating: "x", count: length)
                let frame = m.draw(selected: 0, top: 0, viewport: 3, rows: 14, cols: cols,
                                   query: query, searching: true, visible: filtered(m.items),
                                   total: m.items.count, context: nil)
                let field = frame.map { Ansi.strip($0) }.first { $0.contains("\u{276F}") }
                XCTAssertNotNil(field, "no search field at cols \(cols)")
                XCTAssertTrue(field?.contains("\u{2588}") ?? false,
                              "caret lost at cols \(cols), query length \(length): \(field ?? "")")
            }
        }
    }

    /// The folder path says *which* termdown window this is; a static tagline
    /// says nothing. When only one fits, the path wins.
    func testThePathOutranksTheTagline() {
        var m = sampleMenu()
        m.path = "~/projects/termdown"
        let frame = m.draw(selected: 0, top: 0, viewport: 3, rows: 14, cols: 48,
                           query: "", searching: false, visible: filtered(m.items),
                           total: m.items.count, context: nil)
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("termdown"), "the path was dropped:\n\(plain)")
    }

    /// A folder path is unbounded, so it must be elided rather than allowed to
    /// push the header past the border.
    func testALongPathDoesNotWidenTheHeader() {
        var m = sampleMenu()
        m.path = "~/very/deeply/nested/project/with/an/extremely/long/folder/path/indeed/notes"
        for cols in [30, 60, 80, 120] {
            let frame = m.draw(selected: 0, top: 0, viewport: 3, rows: 14, cols: cols,
                               query: "", searching: false, visible: filtered(m.items),
                               total: m.items.count, context: nil)
            for row in frame {
                XCTAssertEqual(Ansi.width(row), cols, "at \(cols): \(Ansi.strip(row))")
            }
        }
    }

    /// Hints are dropped rather than cut, so a narrow terminal shows fewer of
    /// them — never a truncated stub like `? he…`.
    func testHintsAreDroppedNotTruncated() {
        let m = sampleMenu()
        let narrow = m.draw(selected: 0, top: 0, viewport: 3, rows: 14, cols: 40,
                            query: "", searching: false, visible: filtered(m.items),
                            total: m.items.count, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertFalse(narrow.contains("? he\u{2026}"), narrow)
        XCTAssertFalse(narrow.contains("sear\u{2026}"), narrow)

        let wide = m.draw(selected: 0, top: 0, viewport: 3, rows: 14, cols: 100,
                          query: "", searching: false, visible: filtered(m.items),
                          total: m.items.count, context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(wide.contains("? help"), "the full legend should survive at 100: \(wide)")
    }
}
