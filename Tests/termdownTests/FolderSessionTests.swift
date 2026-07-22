import XCTest
@testable import termdown
@testable import termdownCore

/// `[[wikilink]]` resolution. This lived as a closure over `main.swift`'s
/// top-level state, so it had never been reachable from a test — extracting it
/// as a static pure function is what makes these possible.
final class FolderSessionTests: XCTestCase {
    private func entries(_ paths: [String]) -> [FileScanner.Entry] {
        paths.map { FileScanner.Entry(url: URL(fileURLWithPath: "/root/\($0)"), relativePath: $0) }
    }

    private func resolve(_ name: String, _ paths: [String]) -> String? {
        FolderSession.resolveWikilink(name, in: entries(paths))?.lastPathComponent
    }

    func testMatchesByFilename() {
        XCTAssertEqual(resolve("notes.md", ["notes.md", "other.md"]), "notes.md")
    }

    /// The common form: `[[notes]]` with no extension written.
    func testMatchesByStemWithoutExtension() {
        XCTAssertEqual(resolve("notes", ["notes.md", "other.md"]), "notes.md")
    }

    func testMatchesByRelativePath() {
        XCTAssertEqual(resolve("docs/guide.md", ["readme.md", "docs/guide.md"]), "guide.md")
    }

    func testMatchesByRelativePathWithoutExtension() {
        XCTAssertEqual(resolve("docs/guide", ["readme.md", "docs/guide.md"]), "guide.md")
    }

    /// Wikilinks are written by hand, so casing is not to be trusted.
    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(resolve("NOTES", ["notes.md"]), "notes.md")
        XCTAssertEqual(resolve("notes", ["NOTES.md"]), "NOTES.md")
    }

    func testUnresolvableNameReturnsNil() {
        XCTAssertNil(resolve("missing", ["notes.md", "other.md"]))
    }

    func testEmptyCorpusReturnsNil() {
        XCTAssertNil(resolve("notes", []))
    }

    /// First match wins, and scan order is sorted by relative path — so the
    /// result is at least stable rather than arbitrary.
    func testAmbiguousNameResolvesToTheFirstEntry() {
        XCTAssertEqual(resolve("guide", ["a/guide.md", "b/guide.md"]), "guide.md")
        XCTAssertEqual(
            FolderSession.resolveWikilink("guide", in: entries(["a/guide.md", "b/guide.md"]))?.path,
            "/root/a/guide.md")
    }
}
