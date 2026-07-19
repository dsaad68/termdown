import XCTest
@testable import termdownCore

/// Golden / snapshot tests for the renderer: each fixture `.md` is rendered to
/// ANSI and compared byte-for-byte against a committed `.ansi` golden file, so
/// any change in rendered output is caught. Regenerate goldens after an
/// intentional output change with:
///
///     TD_UPDATE_SNAPSHOTS=1 swift test
final class SnapshotTests: XCTestCase {

    /// `Tests/Fixtures`, resolved relative to this source file so the tests are
    /// independent of the working directory and need no bundled resources.
    private var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // termdownCoreTests/
            .deletingLastPathComponent()   // Tests/
            .appendingPathComponent("Fixtures")
    }

    private func assertSnapshot(_ name: String,
                                width: Int = 80,
                                file: StaticString = #filePath,
                                line: UInt = #line) throws {
        let mdURL = fixturesDir.appendingPathComponent("\(name).md")
        let goldenURL = fixturesDir.appendingPathComponent("\(name).ansi")
        let source = try String(contentsOf: mdURL, encoding: .utf8)

        // Snapshots capture the full styled output, so force colors on
        // regardless of the host environment, then restore.
        let previousColor = Ansi.colorEnabled
        Ansi.colorEnabled = true
        defer { Ansi.colorEnabled = previousColor }

        let rendered = AnsiRenderer(width: width, theme: .dark).render(source)
            .lines.joined(separator: "\n") + "\n"

        if ProcessInfo.processInfo.environment["TD_UPDATE_SNAPSHOTS"] == "1" {
            try rendered.write(to: goldenURL, atomically: true, encoding: .utf8)
            return
        }

        guard let expected = try? String(contentsOf: goldenURL, encoding: .utf8) else {
            XCTFail("Missing golden for \(name). Run TD_UPDATE_SNAPSHOTS=1 swift test to create it.",
                    file: file, line: line)
            return
        }
        XCTAssertEqual(rendered, expected,
                       "Snapshot mismatch for \(name). If this change is intended, regenerate with "
                       + "TD_UPDATE_SNAPSHOTS=1 swift test.",
                       file: file, line: line)
    }

    func testIndexSnapshot() throws { try assertSnapshot("index") }
    func testShowcaseSnapshot() throws { try assertSnapshot("showcase") }
    func testStressSnapshot() throws { try assertSnapshot("stress") }
    func testNestedListsSnapshot() throws { try assertSnapshot("nested-lists") }
    func testTablesCJKSnapshot() throws { try assertSnapshot("tables-cjk") }
    func testMathSnapshot() throws { try assertSnapshot("math") }
    func testMalformedSnapshot() throws { try assertSnapshot("malformed") }
    func testMermaidSnapshot() throws { try assertSnapshot("mermaid") }
    func testEmojiSnapshot() throws { try assertSnapshot("emoji") }
}
