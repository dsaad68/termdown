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
}
