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

    func testRemappedKeyDispatchesToCanonicalAction() {
        // 'e' bound to scroll-down should scroll like 'j'.
        var p = Pager(title: "t", lines: Array(repeating: "x", count: 100))
        p.contentRows = 10
        p.maxTop = 90
        p.keyTranslation = KeyBindings.translation(from: ["scroll-down": "e"])
        XCTAssertEqual(p.top, 0)
        _ = p.handleKey(.char("e"))
        XCTAssertEqual(p.top, 1)   // moved down one line, as 'j' would
    }
}
