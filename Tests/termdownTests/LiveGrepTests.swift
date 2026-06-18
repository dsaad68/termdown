import XCTest
@testable import termdown

/// Tests for LiveGrep's matching logic via the `matches(_:)` entry point, using
/// real temp files (the same fixture pattern as FileScannerTests).
final class LiveGrepTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("livegrep-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func write(_ name: String, _ content: String) -> (url: URL, relativePath: String) {
        let url = tempDir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return (url, name)
    }

    func testFindsMatchesWithLineNumbers() {
        let a = write("a.md", "alpha\nbeta needle here\ngamma")
        let b = write("b.md", "nothing\nanother needle\n")
        let grep = LiveGrep(entries: [a, b])

        let hits = grep.matches("needle")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits[0].relativePath, "a.md")
        XCTAssertEqual(hits[0].lineNo, 2)                 // 1-based
        XCTAssertEqual(hits[0].preview, "beta needle here")
        XCTAssertEqual(hits[1].relativePath, "b.md")
        XCTAssertEqual(hits[1].lineNo, 2)
    }

    func testCaseInsensitive() {
        let a = write("a.md", "The Needle Moves")
        let grep = LiveGrep(entries: [a])
        XCTAssertEqual(grep.matches("needle").count, 1)
        XCTAssertEqual(grep.matches("NEEDLE").count, 1)
    }

    func testPreviewIsTrimmed() {
        let a = write("a.md", "    indented match line    ")
        let grep = LiveGrep(entries: [a])
        let hits = grep.matches("match")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].preview, "indented match line")
    }

    func testEmptyQueryReturnsNothing() {
        let a = write("a.md", "content")
        let grep = LiveGrep(entries: [a])
        XCTAssertTrue(grep.matches("").isEmpty)
    }

    func testNoMatchReturnsEmpty() {
        let a = write("a.md", "only this text")
        let grep = LiveGrep(entries: [a])
        XCTAssertTrue(grep.matches("absent").isEmpty)
    }

    func testMultipleMatchesPerFilePreserveOrder() {
        let a = write("a.md", "hit one\nmiss\nhit two\nhit three")
        let grep = LiveGrep(entries: [a])
        let hits = grep.matches("hit")
        XCTAssertEqual(hits.map { $0.lineNo }, [1, 3, 4])
    }
}
