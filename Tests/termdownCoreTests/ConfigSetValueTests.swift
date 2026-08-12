import Foundation
import XCTest
@testable import termdownCore

/// Writing a single setting to a config file — the path the settings view (`,`) and
/// the theme picker both take. Split from `ConfigWriteTests`, which covers migration
/// and sits on the 400-line lint ceiling.
final class ConfigSetValueTests: XCTestCase {

    private func tempConfig() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("termdown-set-\(UUID().uuidString).yaml")
    }

    private func parse(_ url: URL) throws -> AppConfig? {
        AppConfig.parseYAML(try Data(contentsOf: url))
    }

    private var mouseSetting: ConfigSetting { ConfigSettings.named("mouse")! }

    /// A file that sets the key twice is honoured last-line-wins by the parser, so
    /// the *last* line is the one to rewrite. Rewriting the first left the stale
    /// duplicate in charge, and the view showed the old value straight back.
    func testWritingRewritesTheLineTheParserHonours() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "mouse: true\nmermaid: true\nmouse: false\n"
            .write(to: url, atomically: true, encoding: .utf8)

        AppConfig.writeValue("true", for: mouseSetting, to: url)

        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(try parse(url)?.mouse, true, written)
        XCTAssertEqual(written.components(separatedBy: "mouse:").count - 1, 2,
                       "a line was added rather than rewritten:\n\(written)")
        XCTAssertTrue(written.contains("mermaid: true"), "an unrelated key was touched:\n\(written)")
    }

    /// The key's other spellings count as the same key. Appending `mouse-select:` to
    /// a file that says `mouse_select:` would leave both, and the appended one would
    /// win by accident rather than intent.
    func testWritingFindsTheKeyUnderAnySpelling() throws {
        for spelling in ["mouse-select", "mouse_select", "mouseselect"] {
            let url = tempConfig()
            defer { try? FileManager.default.removeItem(at: url) }
            try "\(spelling): true\n".write(to: url, atomically: true, encoding: .utf8)

            AppConfig.writeValue("false", for: ConfigSettings.named("mouse-select")!, to: url)

            let written = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(try parse(url)?.mouseSelect, false, written)
            XCTAssertEqual(written.components(separatedBy: ": ").count - 1, 1,
                           "\(spelling) got a duplicate:\n\(written)")
        }
    }

    /// The note beside a setting is the user's, about their own choice. Rewriting the
    /// value keeps it.
    func testWritingKeepsAnInlineComment() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "mouse: true   # trackpad is fine\n".write(to: url, atomically: true, encoding: .utf8)

        AppConfig.writeValue("false", for: mouseSetting, to: url)

        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(written.contains("mouse: false"), written)
        XCTAssertTrue(written.contains("# trackpad is fine"), "the comment was dropped:\n\(written)")
    }

    /// A key the file has never set is appended, after a blank line so it does not
    /// land against whatever the file ended with — and commented-out documentation
    /// for the key is left as documentation.
    func testWritingAppendsAKeyTheFileNeverSet() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        try "# mouse: what the mouse does\ntheme: nord\n"
            .write(to: url, atomically: true, encoding: .utf8)

        AppConfig.writeValue("false", for: mouseSetting, to: url)

        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(try parse(url)?.mouse, false, written)
        XCTAssertTrue(written.contains("# mouse: what the mouse does"),
                      "a commented line was treated as the setting:\n\(written)")
        XCTAssertEqual(try parse(url)?.theme, "nord", written)
    }

    /// Writing into a file that does not exist yet creates it, so the view works on
    /// a machine whose config has been deleted.
    func testWritingCreatesAMissingFile() throws {
        let url = tempConfig()
        defer { try? FileManager.default.removeItem(at: url) }
        AppConfig.writeValue("folders", for: ConfigSettings.named("file-list-view")!, to: url)
        XCTAssertEqual(try parse(url)?.fileListView, "folders")
    }
}
