import Foundation
import XCTest
@testable import termdownCore

/// The folder hierarchy the picker browses. Built from the scan's relative paths,
/// so these tests need no folder on disk.
final class FolderTreeTests: XCTestCase {

    private func tree(_ paths: [String]) -> FolderTree {
        FolderTree(entries: paths.map {
            FileScanner.Entry(url: URL(fileURLWithPath: "/tmp/" + $0), relativePath: $0)
        })
    }

    private let sample = [
        "README.md",
        "docs/index.md",
        "docs/api/v1.md",
        "docs/api/v2.md",
        "docs/guides/start.md",
        "notes/today.md",
    ]

    // MARK: - Children

    func testRootListsTopLevelFoldersOnly() {
        XCTAssertEqual(tree(sample).children(of: "").map(\.name), ["docs", "notes"])
    }

    func testChildrenAreTheNextLevelDown() {
        let docs = tree(sample).children(of: "docs")
        XCTAssertEqual(docs.map(\.name), ["api", "guides"])
        XCTAssertEqual(docs.map(\.path), ["docs/api", "docs/guides"])
    }

    /// A folder exists here only because a markdown file sits somewhere beneath it
    /// — the tree is built from the scan's paths, so a folder holding nothing but
    /// images is never mentioned by any of them and can't be browsed into.
    func testOnlyFoldersLeadingToMarkdownExist() {
        let t = tree(["docs/deep/nested/x.md"])
        XCTAssertEqual(t.children(of: "").map(\.name), ["docs"])
        XCTAssertEqual(t.children(of: "docs").map(\.name), ["deep"])
        XCTAssertEqual(t.children(of: "assets"), [], "no entry names it, so it isn't there")
    }

    /// The count is what the row shows, and it counts the whole subtree — a folder
    /// holding nothing but subfolders would otherwise read as empty.
    func testFileCountCoversTheWholeSubtree() {
        let t = tree(sample)
        XCTAssertEqual(t.children(of: "").first { $0.name == "docs" }?.fileCount, 4)
        XCTAssertEqual(t.children(of: "docs").first { $0.name == "api" }?.fileCount, 2)
    }

    /// A leaf is where Enter hands over the files instead of an empty list, so the
    /// flag has to be right for both shapes.
    func testHasSubfoldersMarksTheLeaves() {
        let t = tree(sample)
        XCTAssertEqual(t.children(of: "").first { $0.name == "docs" }?.hasSubfolders, true)
        XCTAssertEqual(t.children(of: "").first { $0.name == "notes" }?.hasSubfolders, false)
    }

    func testNamesSortTheWayTheFileListSorts() {
        let t = tree(["b10/x.md", "b9/x.md", "B2/x.md"])
        XCTAssertEqual(t.children(of: "").map(\.name), ["B2", "b9", "b10"])
    }

    // MARK: - Files under a folder

    /// Narrowing the file list to a folder means everything beneath it, not just
    /// the files sitting directly in it.
    func testFileIndicesAreRecursiveAndInScanOrder() {
        let t = tree(sample)
        XCTAssertEqual(t.fileIndices(under: "docs"), [1, 2, 3, 4])
        XCTAssertEqual(t.fileIndices(under: "docs/api"), [2, 3])
    }

    /// The empty path is "no narrowing at all", which is what lets the file list
    /// use one code path whether or not a folder is chosen.
    func testEmptyPathIsEveryFile() {
        XCTAssertEqual(tree(sample).fileIndices(under: ""), Array(0..<sample.count))
    }

    func testAnUnknownFolderHasNoFiles() {
        XCTAssertEqual(tree(sample).fileIndices(under: "nope"), [])
    }

    // MARK: - Parent

    func testParentWalksUpOneLevelAndStopsAtTheRoot() {
        XCTAssertEqual(FolderTree.parent(of: "docs/api/v1"), "docs/api")
        XCTAssertEqual(FolderTree.parent(of: "docs"), "")
        XCTAssertNil(FolderTree.parent(of: ""))
    }

    // MARK: - Empty

    /// A flat project has nothing to browse, and the picker says so rather than
    /// showing an empty list that looks like a filter miss.
    func testAFlatProjectHasNoFolders() {
        XCTAssertTrue(tree(["a.md", "b.md"]).isEmpty)
        XCTAssertFalse(tree(sample).isEmpty)
    }

    func testNoEntriesAtAll() {
        let t = tree([])
        XCTAssertTrue(t.isEmpty)
        XCTAssertEqual(t.children(of: ""), [])
        XCTAssertEqual(t.fileIndices(under: ""), [])
    }
}
