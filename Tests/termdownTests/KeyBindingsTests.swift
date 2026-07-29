import XCTest
@testable import termdown
@testable import termdownCore

/// Tests for configurable viewer keybindings (Phase 7).
final class KeyBindingsTests: XCTestCase {

    func testNoOverridesIsEmpty() {
        XCTAssertTrue(KeyBindings.translation(from: nil).isEmpty)
        XCTAssertTrue(KeyBindings.translation(from: [:]).isEmpty)
    }

    func testOverrideMapsUserKeyToCanonical() {
        let t = KeyBindings.translation(from: ["scroll-down": "e", "theme": "_"])
        XCTAssertEqual(t["e"], "j")   // scroll-down canonical
        XCTAssertEqual(t["_"], "p")   // theme canonical
    }

    func testIgnoresUnknownActionsAndBadKeys() {
        let t = KeyBindings.translation(from: [
            "not-an-action": "x",   // unknown action
            "scroll-up": "kk",      // not a single char
            "top": "g",             // binds to its own default → no-op
        ])
        XCTAssertNil(t["x"])
        XCTAssertNil(t["g"])
        XCTAssertTrue(t.isEmpty)
    }

    func testConfigParsesKeyBindings() {
        let yaml = """
        theme: nord
        key-scroll-down: e
        key-theme: _
        """
        let cfg = AppConfig.parseYAML(Data(yaml.utf8))
        XCTAssertEqual(cfg?.theme, "nord")
        XCTAssertEqual(cfg?.keyBindings?["scroll-down"], "e")
        XCTAssertEqual(cfg?.keyBindings?["theme"], "_")
    }

    /// `toggle-task` is rebindable like any other action; its canonical key is
    /// Space, which the input switch resolves by context.
    func testToggleTaskIsRebindable() {
        XCTAssertEqual(KeyBindings.defaults["toggle-task"], " ")
        XCTAssertEqual(KeyBindings.translation(from: ["toggle-task": "x"])["x"], " ")
    }

    /// The shipped config file lists the rebindable actions in a comment, and a
    /// list that drifts from the code is worse than no list — `edit` and `cursor`
    /// were both missing from it before this test existed.
    func testShippedConfigDocumentsEveryRebindableAction() throws {
        let template = AppConfig.defaultConfigContent
        let start = try XCTUnwrap(template.range(of: "Actions: "), "no action list in the template")
        let tail = template[start.upperBound...]
        let end = try XCTUnwrap(tail.range(of: ".\n"), "action list is not terminated")
        let listed = Set(tail[..<end.lowerBound]
            .replacingOccurrences(of: "#", with: " ")
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
        XCTAssertEqual(listed, Set(KeyBindings.defaults.keys),
                       "config template's action list disagrees with KeyBindings.defaults")
    }

    func testRemappedKeyDispatchesToCanonicalAction() {
        // '_' bound to scroll-down should scroll like 'j' (cursor hidden by default).
        var p = Pager(title: "t", lines: Array(repeating: "x", count: 100))
        p.lines = Array(repeating: "x", count: 100)
        p.contentRows = 10
        p.maxTop = 90
        p.keyTranslation = KeyBindings.translation(from: ["scroll-down": "_"])
        XCTAssertEqual(p.top, 0)
        _ = p.handleKey(.char("_"))
        XCTAssertEqual(p.top, 1)   // scrolled down one line, as 'j' would
    }
}
