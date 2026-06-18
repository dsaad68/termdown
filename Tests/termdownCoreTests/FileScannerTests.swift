import XCTest
@testable import termdownCore

final class FileScannerTests: XCTestCase {

    var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("termdown_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testScanMarkdownFiles() throws {
        // Create test markdown files
        let file1 = tempDirectory.appendingPathComponent("test1.md")
        let file2 = tempDirectory.appendingPathComponent("test2.markdown")
        let file3 = tempDirectory.appendingPathComponent("other.txt")

        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(to: file2, atomically: true, encoding: .utf8)
        try "Not markdown".write(to: file3, atomically: true, encoding: .utf8)

        let entries = FileScanner.scan(root: tempDirectory)

        XCTAssertEqual(entries.count, 2)
        let paths = entries.map { $0.relativePath }.sorted()
        XCTAssertTrue(paths.contains("test1.md"))
        XCTAssertTrue(paths.contains("test2.markdown"))
        XCTAssertFalse(paths.contains("other.txt"))
    }

    func testScanNestedDirectories() throws {
        // Create nested structure
        let subdir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let file1 = tempDirectory.appendingPathComponent("root.md")
        let file2 = subdir.appendingPathComponent("nested.md")

        try "Root content".write(to: file1, atomically: true, encoding: .utf8)
        try "Nested content".write(to: file2, atomically: true, encoding: .utf8)

        let entries = FileScanner.scan(root: tempDirectory)

        XCTAssertEqual(entries.count, 2)
        let paths = entries.map { $0.relativePath }.sorted()
        XCTAssertTrue(paths.contains("root.md"))
        XCTAssertTrue(paths.contains("subdir/nested.md"))
    }

    func testScanHiddenFiles() throws {
        // Create hidden file
        let hiddenFile = tempDirectory.appendingPathComponent(".hidden.md")
        let visibleFile = tempDirectory.appendingPathComponent("visible.md")

        try "Hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        try "Visible".write(to: visibleFile, atomically: true, encoding: .utf8)

        let entries = FileScanner.scan(root: tempDirectory)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.relativePath, "visible.md")
    }

    func testScanHiddenDirectories() throws {
        // Create hidden directory with markdown file
        let hiddenDir = tempDirectory.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)

        let hiddenFile = hiddenDir.appendingPathComponent("readme.md")
        let visibleFile = tempDirectory.appendingPathComponent("readme.md")

        try "Hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        try "Visible".write(to: visibleFile, atomically: true, encoding: .utf8)

        let entries = FileScanner.scan(root: tempDirectory)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.relativePath, "readme.md")
    }

    func testScanIgnoredDirectories() throws {
        // Create directories that should be ignored
        let nodeModules = tempDirectory.appendingPathComponent("node_modules")
        let buildDir = tempDirectory.appendingPathComponent("build")

        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

        let ignoredFile1 = nodeModules.appendingPathComponent("package.md")
        let ignoredFile2 = buildDir.appendingPathComponent("build.md")
        let visibleFile = tempDirectory.appendingPathComponent("visible.md")

        try "Ignored".write(to: ignoredFile1, atomically: true, encoding: .utf8)
        try "Ignored".write(to: ignoredFile2, atomically: true, encoding: .utf8)
        try "Visible".write(to: visibleFile, atomically: true, encoding: .utf8)

        let entries = FileScanner.scan(root: tempDirectory)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.relativePath, "visible.md")
    }

    func testScanEmptyDirectory() {
        let entries = FileScanner.scan(root: tempDirectory)
        XCTAssertEqual(entries.count, 0)
    }

    func testMarkdownExtensions() {
        XCTAssertTrue(FileScanner.markdownExtensions.contains("md"))
        XCTAssertTrue(FileScanner.markdownExtensions.contains("markdown"))
        XCTAssertTrue(FileScanner.markdownExtensions.contains("mdx"))
    }
}
