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

    /// Migration adds keys; it never edits a value the file already states.
    ///
    /// It used to rewrite any line still holding the superseded default, reading
    /// that as "never touched". Nothing in the file supports that inference — a
    /// deliberate `mouse: false` is byte-identical to an untouched one — so the
    /// rule silently overrode people who had turned the mouse off on purpose.
    func testMigrateNeverRewritesAValueTheFileAlreadySets() throws {
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
        XCTAssertEqual(cfg?.mouse, false, written)
        XCTAssertEqual(cfg?.mouseSelect, false, written)
        XCTAssertEqual(cfg?.noColor, false, written)
    }

    /// A new sub-setting must not switch itself on inside something the user has
    /// switched off: `mouse-select` reports pointer motion, so adding it as
    /// `true` to a config with `mouse: false` would take back the terminal's own
    /// click-drag selection from someone who explicitly asked to keep it.
    func testMigrateAddsASubordinateKeyOffWhenItsParentIsOff() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "mouse: false\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)

        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(try parse(url)?.mouseSelect, false, written)
    }

    /// `parseYAML` accepts `mouse_select` and `mouseselect` too. Matching only
    /// the canonical spelling appended a second `mouse-select:` line — and since
    /// parsing is last-line-wins, that duplicate silently overrode the user's.
    func testMigrateRecognizesAliasSpellings() throws {
        for alias in ["mouse_select", "mouseselect"] {
            let url = tempConfig()
            defer { try? FileManager.default.removeItem(at: url) }
            try "theme: nord\n\(alias): false\n".write(to: url, atomically: true, encoding: .utf8)

            AppConfig.migrate(url)

            let written = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(try parse(url)?.mouseSelect, false, written)
            XCTAssertFalse(written.contains("mouse-select:"),
                           "appended a duplicate alongside \(alias):\n\(written)")
        }
    }

    /// A symlinked config is the ordinary dotfiles arrangement. `atomically:
    /// true` renames a temp file over the destination, which replaces the link
    /// with a regular file and orphans the tracked original — so the repo the
    /// user edits stops driving their config, silently.
    func testMigrateWritesThroughASymlink() throws {
        let fm = FileManager.default
        let real = tempConfig()
        let link = tempConfig()
        defer {
            try? fm.removeItem(at: real)
            try? fm.removeItem(at: link)
        }
        try "mouse: false\n".write(to: real, atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: link, withDestinationURL: real)

        AppConfig.migrate(link)

        let type = try fm.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType
        XCTAssertEqual(type, .typeSymbolicLink, "the symlink was replaced by a regular file")

        let written = try String(contentsOf: real, encoding: .utf8)
        XCTAssertTrue(written.contains("config-version: 2"), "migration missed the real file:\n\(written)")
        XCTAssertTrue(written.contains("mouse: false"), written)
    }

    /// `writeTheme` writes the same file from the theme picker, so it has to
    /// follow a symlink for the same reason.
    func testWriteThemeWritesThroughASymlink() throws {
        let fm = FileManager.default
        let real = tempConfig()
        let link = tempConfig()
        defer {
            try? fm.removeItem(at: real)
            try? fm.removeItem(at: link)
        }
        try "theme: dark\n".write(to: real, atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: link, withDestinationURL: real)

        AppConfig.writeTheme("nord", to: link)

        let type = try fm.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType
        XCTAssertEqual(type, .typeSymbolicLink, "the symlink was replaced by a regular file")
        XCTAssertTrue(try String(contentsOf: real, encoding: .utf8).contains("theme: nord"))
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

    /// An inline trailing comment must not hide the key from the scan (or a
    /// duplicate gets appended), and the user's note has to survive — it is
    /// often the only record of *why* a setting was changed.
    func testMigrateKeepsALineAndItsInlineComment() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        let line = "mouse: false  # off on purpose, tmux copy breaks otherwise"
        try "\(line)\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.migrate(url)

        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(written.contains(line), "the line and its comment were rewritten:\n\(written)")
        XCTAssertEqual(try parse(url)?.mouse, false, written)
    }

    /// A missing file is not an error — `load()` creates one in that case.
    func testMigrateOnMissingFileIsInert() {
        let url = tempConfig()
        AppConfig.migrate(url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
