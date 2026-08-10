import Foundation
import XCTest
@testable import termdown
@testable import termdownCore

/// The picker's two lists and the navigation between them. `run()` needs a TTY and
/// a key stream; this is the same state machine it drives, tested directly.
final class MenuListTests: XCTestCase {

    private let paths = [
        "README.md",
        "docs/index.md",
        "docs/api/v1.md",
        "docs/api/v2.md",
        "notes/today.md",
    ]

    private func list(_ paths: [String]? = nil) -> MenuList {
        let used = paths ?? self.paths
        var l = MenuList()
        l.tree = FolderTree(entries: used.map {
            FileScanner.Entry(url: URL(fileURLWithPath: "/tmp/" + $0), relativePath: $0)
        })
        return l
    }

    private func labels(_ l: MenuList, _ paths: [String]? = nil) -> [String] {
        l.rows(labels: paths ?? self.paths, details: []).map(\.label)
    }

    // MARK: - The file list

    func testFilesModeListsEveryFileByDefault() {
        XCTAssertEqual(labels(list()), paths)
    }

    func testDetailsRideAlongWithTheRows() {
        let rows = list().rows(labels: paths, details: ["1d", "2h", "3d", "4d", "5d"])
        XCTAssertEqual(rows.map(\.detail), ["1d", "2h", "3d", "4d", "5d"])
    }

    /// A row carries the entry index, so what the picker opens never depends on
    /// looking a label back up — which is what a narrowed list would break.
    func testRowsCarryTheEntryIndexEvenWhenNarrowed() {
        var l = list()
        l.scope = "docs/api"
        let rows = l.rows(labels: paths, details: [])
        XCTAssertEqual(rows.map(\.kind), [.file(2), .file(3)])
    }

    /// Labels are relative to the folder you chose: repeating `docs/api/` on every
    /// row of a folder you just picked is noise, and the filter matches the label.
    func testNarrowedLabelsAreRelativeToTheFolder() {
        var l = list()
        l.scope = "docs"
        XCTAssertEqual(labels(l), ["index.md", "api/v1.md", "api/v2.md"])
    }

    // MARK: - The folder browser

    func testFoldersModeListsTheTopLevelWithCounts() {
        var l = list()
        l.toggleMode()
        let rows = l.rows(labels: paths, details: [])
        XCTAssertEqual(rows.map(\.label), ["docs/", "notes/"])
        XCTAssertEqual(rows.map(\.detail), ["3 files", "1 file"])
    }

    /// Enter descends, and the list that comes back is the *next* level — which is
    /// the whole point of the mode.
    func testEnteringAFolderShowsItsSubfolders() {
        var l = list()
        l.toggleMode()
        let docs = l.rows(labels: paths, details: [])[0]
        XCTAssertNil(l.activate(docs))
        XCTAssertEqual(l.cwd, "docs")
        XCTAssertEqual(labels(l), ["../", "api/"])
    }

    /// The `..` row is the clickable half of Backspace: it has to go up, not
    /// deeper, even though it is a folder row like any other.
    func testTheUpRowGoesBackToTheParent() {
        var l = list()
        l.toggleMode()
        _ = l.activate(l.rows(labels: paths, details: [])[0])   // into docs
        let up = l.rows(labels: paths, details: [])[0]
        XCTAssertEqual(up.label, "../")
        XCTAssertNil(l.activate(up))
        XCTAssertEqual(l.cwd, "")
        XCTAssertEqual(labels(l), ["docs/", "notes/"])
    }

    /// A folder with nothing inside it would be a dead end, so Enter hands over its
    /// files instead of an empty list.
    func testEnteringALeafFolderShowsItsFiles() {
        var l = list()
        l.toggleMode()
        let notes = l.rows(labels: paths, details: [])[1]
        XCTAssertEqual(notes.label, "notes/")
        XCTAssertNil(l.activate(notes))
        XCTAssertEqual(l.mode, .files)
        XCTAssertEqual(l.scope, "notes")
        XCTAssertEqual(labels(l), ["today.md"])
    }

    /// Enter on a file is the one case that opens something, and it reports the
    /// entry index the caller uses.
    func testEnteringAFileReturnsItsIndex() {
        var l = list()
        XCTAssertEqual(l.activate(l.rows(labels: paths, details: [])[2]), 2)
    }

    func testUpStopsAtTheRootAndDoesNothingInTheFileList() {
        var l = list()
        XCTAssertFalse(l.up(), "the file list has no levels to climb")
        l.toggleMode()
        XCTAssertFalse(l.up(), "already at the root")
        l.cwd = "docs/api"
        XCTAssertTrue(l.up())
        XCTAssertEqual(l.cwd, "docs")
    }

    // MARK: - Switching

    /// The two keys are each other's inverse: browse to a folder, press `d`, and
    /// the file list is that folder's; press `d` again and you are back where you
    /// were standing.
    func testTogglingCarriesTheFolderBothWays() {
        var l = list()
        l.toggleMode()
        _ = l.activate(l.rows(labels: paths, details: [])[0])   // into docs
        l.toggleMode()
        XCTAssertEqual(l.mode, .files)
        XCTAssertEqual(l.scope, "docs")
        XCTAssertEqual(labels(l), ["index.md", "api/v1.md", "api/v2.md"])

        l.toggleMode()
        XCTAssertEqual(l.mode, .folders)
        XCTAssertEqual(l.cwd, "docs")
        XCTAssertEqual(labels(l), ["../", "api/"])
    }

    /// Esc widens the narrowed list back to the whole project — and reports whether
    /// it did anything, so Esc can fall through to quitting when there is no scope.
    func testClearingTheScopeWidensTheListOnce() {
        var l = list()
        l.scope = "docs"
        XCTAssertTrue(l.clearScope())
        XCTAssertEqual(labels(l), paths)
        XCTAssertFalse(l.clearScope(), "nothing left to widen — Esc must fall through")
    }

    func testClearingTheScopeIsAFileListJob() {
        var l = list()
        l.toggleMode()
        l.cwd = "docs"
        XCTAssertFalse(l.clearScope())
        XCTAssertEqual(l.mode, .folders)
    }

    // MARK: - Search

    /// The search box searches the whole project, so it leaves the browser — and
    /// clearing the query has to put it back exactly where it was, or `/` becomes a
    /// one-way door out of a folder you had navigated to.
    func testSearchLeavesTheBrowserAndComesBack() {
        var l = list()
        l.toggleMode()
        l.cwd = "docs/api"
        l.searchAllFiles()
        XCTAssertEqual(l.mode, .files)
        XCTAssertEqual(l.scope, "", "the search covers every folder")
        XCTAssertEqual(labels(l), paths)

        XCTAssertTrue(l.restoreAfterSearch())
        XCTAssertEqual(l.mode, .folders)
        XCTAssertEqual(l.cwd, "docs/api")
    }

    /// A narrowed file list is not the browser: `/` there widens the search, and
    /// clearing the query must not teleport into a mode the user never opened.
    func testSearchFromTheFileListDoesNotOpenTheBrowser() {
        var l = list()
        l.scope = "docs"
        l.searchAllFiles()
        XCTAssertEqual(l.mode, .files)
        XCTAssertEqual(l.scope, "docs", "the file list keeps what it was narrowed to")
        XCTAssertFalse(l.restoreAfterSearch())
    }

    /// Navigating after a search abandons the return trip — otherwise clearing a
    /// query much later would yank the list back to a folder from minutes ago.
    func testNavigatingAfterASearchDropsTheReturnTrip() {
        var l = list()
        l.toggleMode()
        l.cwd = "docs"
        l.searchAllFiles()
        _ = l.activate(MenuList.Row(kind: .folder("notes"), label: "notes/", detail: ""))
        XCTAssertFalse(l.restoreAfterSearch())
    }

    // MARK: - Header

    /// Narrowing to a single folder — or a folder with one file in it — is the
    /// ordinary case now, so "1 files" would be on screen constantly.
    func testTheCountIsSingularWhenThereIsOneOfThem() {
        var l = list()
        XCTAssertEqual(l.countText(shown: 5, total: 5), "5 files")
        XCTAssertEqual(l.countText(shown: 2, total: 5), "2/5 files")
        XCTAssertEqual(l.countText(shown: 1, total: 1), "1 file")
        l.toggleMode()
        XCTAssertEqual(l.countText(shown: 3, total: 3), "3 folders")
        XCTAssertEqual(l.countText(shown: 1, total: 1), "1 folder")
    }

    func testHeaderShowsTheFolderForBothLists() {
        var l = list()
        XCTAssertEqual(l.subPath, "")
        XCTAssertEqual(l.noun, "files")

        l.toggleMode()
        l.cwd = "docs/api"
        XCTAssertEqual(l.subPath, "/docs/api")
        XCTAssertEqual(l.noun, "folders")

        l.toggleMode()
        XCTAssertEqual(l.subPath, "/docs/api", "the narrowed file list says where it is too")
        XCTAssertEqual(l.noun, "files")
    }

    // MARK: - Degenerate projects

    /// A flat project has nothing to browse. Switching still has to be safe — and
    /// reversible — rather than trapping the user in an empty list.
    func testAFlatProjectBrowsesToNothingAndBack() {
        let flat = ["a.md", "b.md"]
        var l = list(flat)
        XCTAssertTrue(l.hasNoFolders)
        l.toggleMode()
        XCTAssertEqual(labels(l, flat), [])
        l.toggleMode()
        XCTAssertEqual(labels(l, flat), flat)
    }

    /// The rows are rebuilt from a list that a rescan can shorten under us — the
    /// watcher fires between the tree being built and the rows being asked for — so
    /// an index that no longer exists must be dropped, not read past the end.
    func testRowsSurviveAShrunkenFileList() {
        var l = list()
        l.scope = "docs/api"
        XCTAssertEqual(l.rows(labels: ["README.md"], details: []).count, 0)
    }

    /// The detail column is a second array that can run short of the first; a row
    /// then has no mtime rather than crashing the picker.
    func testAShortDetailListLeavesTheColumnBlank() {
        let rows = list().rows(labels: paths, details: ["1d"])
        XCTAssertEqual(rows.count, paths.count)
        XCTAssertEqual(rows.map(\.detail), ["1d", "", "", "", ""])
    }
}
