import Foundation
import MermaidRenderer
import XCTest
@testable import termdown
@testable import termdownCore

/// What the settings view *does* when a value changes: writes it to the file it
/// named, keeps its own row in step, and applies the change to the running session
/// for the keys that can take one. `run()` needs a TTY; this is the path it drives.
final class ConfigMenuTests: XCTestCase {

    private var path = FileManager.default.temporaryDirectory
    private var applied: [(key: String, value: String)] = []
    private var invalidations = 0

    override func setUp() {
        super.setUp()
        path = FileManager.default.temporaryDirectory
            .appendingPathComponent("termdown-menu-\(UUID().uuidString).yaml")
        applied = []
        invalidations = 0
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: path)
        super.tearDown()
    }

    private func menu(_ yaml: String = "", local: String? = nil) -> ConfigMenu {
        ConfigMenu(hooks: ConfigMenu.Hooks(
            applyRenderSetting: { setting, value in self.applied.append((setting.key, value)) },
            invalidateRender: { self.invalidations += 1 }),
            path: path,
            local: local.flatMap { AppConfig.parseYAML(Data($0.utf8)) },
            global: AppConfig.parseYAML(Data(yaml.utf8)) ?? AppConfig())
    }

    private func setting(_ key: String) -> ConfigSetting { ConfigSettings.named(key)! }

    private func onDisk() -> AppConfig? {
        (try? Data(contentsOf: path)).flatMap(AppConfig.parseYAML)
    }

    // MARK: - Writing

    /// A change goes to the file the header names — not the real config, which is
    /// what makes the view testable at all.
    func testAChangeIsWrittenToTheViewsOwnFile() {
        var m = menu("mouse: true\n")
        m.set("false", for: setting("mouse"))
        XCTAssertEqual(onDisk()?.mouse, false)
        XCTAssertEqual(m.value(of: setting("mouse")), "false", "the row still shows the old value")
    }

    /// Setting a value it already has writes nothing: the view repaints on every key,
    /// and rewriting the file for a no-op change would rewrite it on every keypress.
    func testSettingTheSameValueWritesNothing() {
        var m = menu("mouse: true\n")
        m.set("true", for: setting("mouse"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path),
                       "the file was written for a value that did not change")
        XCTAssertEqual(invalidations, 0)
    }

    /// Several changes accumulate in one file rather than each replacing the last.
    func testChangesAccumulate() {
        var m = menu()
        m.set("nord", for: setting("theme"))
        m.set("folders", for: setting("file-list-view"))
        m.set("96", for: setting("width"))
        XCTAssertEqual(onDisk()?.theme, "nord")
        XCTAssertEqual(onDisk()?.fileListView, "folders")
        XCTAssertEqual(onDisk()?.width, 96)
    }

    // MARK: - Applying

    /// The keys the render context owns are handed to it, and the render it already
    /// drew is dropped — otherwise the change would not show until something else
    /// forced a reflow.
    func testRenderSettingsAreHandedToTheAppAndInvalidateTheRender() {
        var m = menu()
        m.set("nord", for: setting("theme"))
        m.set("ascii", for: setting("mermaid-charset"))
        m.set("false", for: setting("mermaid"))
        XCTAssertEqual(applied.map(\.key), ["theme", "mermaid-charset", "mermaid"])
        XCTAssertEqual(applied.map(\.value), ["nord", "ascii", "false"])
        XCTAssertEqual(invalidations, 3)
    }

    /// A key read once at startup is written and nothing else: no hook, no repaint,
    /// and the view tells the user it waits for the next launch.
    func testStartupOnlyKeysAreWrittenButNotApplied() {
        var m = menu()
        for key in ["width", "mouse", "mouse-select", "file-list-view", "bare-render"] {
            XCTAssertFalse(setting(key).appliesLive, key)
        }
        m.set("120", for: setting("width"))
        m.set("false", for: setting("mouse"))
        XCTAssertEqual(onDisk()?.width, 120)
        XCTAssertEqual(onDisk()?.mouse, false)
        XCTAssertTrue(applied.isEmpty, "a startup key was pushed into the session")
        XCTAssertEqual(invalidations, 0, "a startup key forced a needless re-render")
    }

    /// `no-color` is a global the view can flip itself, and it means the *opposite*
    /// of the flag it sets — `no-color: true` is colors off.
    func testNoColorFlipsTheGlobalTheRightWayRound() {
        let previous = Ansi.colorEnabled
        defer { Ansi.colorEnabled = previous }

        var m = menu()
        m.set("true", for: setting("no-color"))
        XCTAssertFalse(Ansi.colorEnabled)
        m.set("false", for: setting("no-color"))
        XCTAssertTrue(Ansi.colorEnabled)
        XCTAssertEqual(invalidations, 2)
    }

    /// Both measurement tables move together: a diagram measured one way inside a
    /// document measured the other has its borders off by a cell on every emoji row.
    func testWideEmojiMovesBothWidthTables() {
        let ansi = Ansi.emojiWidthMode
        let mermaid = DisplayWidth.emojiWidthMode
        defer {
            Ansi.emojiWidthMode = ansi
            DisplayWidth.emojiWidthMode = mermaid
        }

        var m = menu()
        m.set("scalar", for: setting("wide-emoji"))
        XCTAssertEqual(Ansi.emojiWidthMode, .scalar)
        XCTAssertEqual(DisplayWidth.emojiWidthMode, .scalar)
        m.set("cluster", for: setting("wide-emoji"))
        XCTAssertEqual(Ansi.emojiWidthMode, .cluster)
        XCTAssertEqual(DisplayWidth.emojiWidthMode, .cluster)
    }

    // MARK: - Reading

    /// The view opens on the values in the file, with the defaults filled in for the
    /// keys it does not set.
    func testValuesAreReadFromTheFileWithDefaultsForTheRest() {
        let m = menu("theme: gruvbox\nwidth: 72\n")
        XCTAssertEqual(m.value(of: setting("theme")), "gruvbox")
        XCTAssertEqual(m.value(of: setting("width")), "72")
        XCTAssertEqual(m.value(of: setting("mouse")), "true", "not the built-in default")
    }

    /// A project-local file wins over the global one, so those keys are marked — and
    /// only those.
    func testLocallyOverriddenKeysAreKnown() {
        let m = menu("mouse: true\n", local: "mouse: false\nwidth: 100\n")
        XCTAssertEqual(m.overriddenLocally, ["mouse", "width"])
        XCTAssertTrue(menu("mouse: true\n").overriddenLocally.isEmpty)
    }
}
