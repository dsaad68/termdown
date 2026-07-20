import XCTest
@testable import termdownCore

/// Tests for persisting the selected theme (Phase 4 theme selector).
final class ConfigWriteTests: XCTestCase {

    private func tempConfig() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("td-cfg-\(UUID().uuidString).yaml")
    }

    func testWriteThemeReplacesActiveLinePreservingComments() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try """
        # termdown configuration
        theme: dark
        mouse: true
        """.write(to: url, atomically: true, encoding: .utf8)

        AppConfig.writeTheme("dracula", to: url)

        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(written.contains("theme: dracula"), written)
        XCTAssertFalse(written.contains("theme: dark"), written)
        XCTAssertTrue(written.contains("# termdown configuration"), written)  // comment kept
        XCTAssertTrue(written.contains("mouse: true"), written)               // other key kept

        // Round-trips through the loader.
        let cfg = AppConfig.parseYAML(Data(written.utf8))
        XCTAssertEqual(cfg?.theme, "dracula")
    }

    func testWriteThemeAppendsWhenAbsent() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "mouse: false\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.writeTheme("nord", to: url)

        let cfg = AppConfig.parseYAML(Data(try String(contentsOf: url, encoding: .utf8).utf8))
        XCTAssertEqual(cfg?.theme, "nord")
        XCTAssertEqual(cfg?.mouse, false)
    }

    // MARK: - Migration to config-version 2 (mouse + mouse-select default on)

    private func parse(_ url: URL) throws -> AppConfig? {
        AppConfig.parseYAML(Data(try String(contentsOf: url, encoding: .utf8).utf8))
    }

    /// A config predating the `mouse-select` key: the key is appended, and the
    /// user's own explicit `mouse: true` is left exactly as it was.
    func testMigrateAppendsMissingKeyAndKeepsExplicitValues() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try """
        # termdown configuration
        theme: dracula
        mouse: true
        """.write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)

        let written = try String(contentsOf: url, encoding: .utf8)
        let cfg = try parse(url)
        XCTAssertEqual(cfg?.mouseSelect, true, written)       // appended
        XCTAssertEqual(cfg?.mouse, true, written)             // untouched
        XCTAssertEqual(cfg?.theme, "dracula", written)        // untouched
        XCTAssertEqual(cfg?.configVersion, 2, written)        // stamped
        XCTAssertTrue(written.contains("# termdown configuration"), written)
    }

    /// A v0.1.7 config: both keys are present holding the superseded default, so
    /// both get upgraded rather than left off forever.
    func testMigrateUpgradesStaleShippedDefaults() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try """
        mouse: false
        mouse-select: false
        no-color: false
        """.write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)

        let written = try String(contentsOf: url, encoding: .utf8)
        let cfg = try parse(url)
        XCTAssertEqual(cfg?.mouse, true, written)
        XCTAssertEqual(cfg?.mouseSelect, true, written)
        XCTAssertEqual(cfg?.noColor, false, written)  // an unrelated false stays false
    }

    /// Migration must not fight a user who has deliberately turned the new
    /// defaults back off — the stamp makes it a one-time upgrade.
    func testMigrateIsIdempotent() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "mouse: false\nmouse-select: false\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)
        // The user turns them back off.
        try "config-version: 2\nmouse: false\nmouse-select: false\n"
            .write(to: url, atomically: true, encoding: .utf8)
        AppConfig.migrate(url)

        let cfg = try parse(url)
        XCTAssertEqual(cfg?.mouse, false)
        XCTAssertEqual(cfg?.mouseSelect, false)
    }

    /// Running twice in a row must produce a byte-identical file.
    func testMigrateTwiceIsByteIdentical() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "theme: nord\nmouse: true\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)
        let first = try String(contentsOf: url, encoding: .utf8)
        AppConfig.migrate(url)
        let second = try String(contentsOf: url, encoding: .utf8)

        XCTAssertEqual(first, second)
    }

    /// A commented-out key is not an active setting, so it must be treated as
    /// absent rather than matched by the key scan.
    func testMigrateIgnoresCommentedKeys() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "# mouse: false\n# mouse-select: false\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)

        let written = try String(contentsOf: url, encoding: .utf8)
        let cfg = try parse(url)
        XCTAssertEqual(cfg?.mouse, true, written)
        XCTAssertEqual(cfg?.mouseSelect, true, written)
        XCTAssertTrue(written.contains("# mouse: false"), written)  // comment preserved
    }

    /// An inline trailing comment must not hide the value from the staleness check.
    func testMigrateSeesValueBehindInlineComment() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "mouse: false  # I turned this off\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)

        XCTAssertEqual(try parse(url)?.mouse, true)
    }

    /// A missing file is not an error — `load()` creates one in that case.
    func testMigrateOnMissingFileIsInert() {
        let url = tempConfig()
        AppConfig.migrate(url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
