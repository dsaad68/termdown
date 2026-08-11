import Foundation
import XCTest
@testable import termdown
@testable import termdownCore

/// Drawing tests for the settings view (`,`). It writes as it goes, so every one of
/// these points the view at a temp file — a test that touched
/// `~/.config/termdown/config.yaml` would edit the machine it runs on.
final class ConfigMenuDrawTests: XCTestCase {

    private func config(_ yaml: String) -> AppConfig? {
        AppConfig.parseYAML(Data(yaml.utf8))
    }

    private func menu(_ yaml: String = "", local: String? = nil) -> ConfigMenu {
        ConfigMenu(path: FileManager.default.temporaryDirectory
            .appendingPathComponent("termdown-view-\(UUID().uuidString).yaml"),
            local: local.flatMap(config), global: config(yaml) ?? AppConfig())
    }

    private func plain(_ m: ConfigMenu, selected: Int = 0, typing: String? = nil,
                       rows: Int = 24, cols: Int = 80) -> String {
        m.draw(selected: selected, typing: typing, rows: rows, cols: cols)
            .map { Ansi.strip($0) }.joined(separator: "\n")
    }

    // MARK: - What it shows

    /// The values on screen are the ones in the file, and the ones the file leaves
    /// out show their built-in defaults rather than blanks.
    func testValuesComeFromTheFileWithDefaultsFilledIn() {
        let text = plain(menu("theme: nord\nmouse: false\n"))
        XCTAssertTrue(text.contains("Theme"), text)
        XCTAssertTrue(text.contains("nord"), text)
        XCTAssertTrue(text.contains("false"), text)          // mouse, as set
        XCTAssertTrue(text.contains("unicode"), text)        // mermaid-charset, defaulted
        XCTAssertTrue(text.contains("auto"), text)           // width 0, spelled out
    }

    /// The header names the file being written, because that is the one thing a
    /// settings screen must not leave the user guessing about.
    func testTheHeaderNamesTheFile() {
        let text = plain(menu())
        XCTAssertTrue(text.contains("settings"), text)
        XCTAssertTrue(text.contains("config.yaml"), text)
    }

    /// Every key gets a row: a setting present in the table but missing from the
    /// panel would be unreachable.
    func testEverySettingHasARow() {
        let text = plain(menu(), rows: 30)
        for setting in ConfigSettings.editable {
            XCTAssertTrue(text.contains(setting.label), "\(setting.key) has no row:\n\(text)")
        }
    }

    /// The footer explains the row under the cursor — that is where the blurb lives,
    /// so it has to follow the selection.
    func testTheFooterFollowsTheCursor() {
        let m = menu()
        let first = ConfigSettings.editable[0]
        let third = ConfigSettings.editable[2]
        XCTAssertTrue(plain(m, selected: 0).contains(first.blurb))
        XCTAssertTrue(plain(m, selected: 2).contains(third.blurb))
    }

    /// A key that is only read at startup says so, or changing it looks ignored.
    func testKeysThatNeedARestartSayWhichTheyAre() {
        let m = menu()
        let live = ConfigSettings.editable.firstIndex { $0.appliesLive }!
        let notLive = ConfigSettings.editable.firstIndex { !$0.appliesLive }!
        XCTAssertFalse(plain(m, selected: live).contains("next launch"))
        XCTAssertTrue(plain(m, selected: notLive).contains("next launch"))
        // And the row itself carries a mark, so the panel can be scanned for them.
        XCTAssertTrue(plain(m).contains("\u{21BB}"))
    }

    /// A project-local file wins over the global one, so a key it sets is marked:
    /// writing here would otherwise look like it did nothing.
    func testAKeyOverriddenLocallyIsMarked() {
        let m = menu("mouse: true\n", local: "mouse: false\n")
        let mouse = ConfigSettings.editable.firstIndex { $0.key == "mouse" }!
        XCTAssertTrue(plain(m).contains("local"), plain(m))
        XCTAssertTrue(plain(m, selected: mouse).contains(".termdown.yaml wins here"),
                      plain(m, selected: mouse))

        // Without a local file, nothing is marked.
        XCTAssertFalse(plain(menu("mouse: true\n")).contains("local"))
    }

    /// Typing a width shows what has been typed, with a cursor, and an empty entry
    /// reads as `auto` — the value it will actually be written as.
    func testTypingAWidthShowsTheEntry() {
        let m = menu()
        let width = ConfigSettings.editable.firstIndex { $0.key == "width" }!
        let typed = plain(m, selected: width, typing: "12")
        XCTAssertTrue(typed.contains("12"), typed)
        XCTAssertTrue(typed.contains("\u{2588}"), "no cursor while typing: \(typed)")
        XCTAssertTrue(typed.contains("\u{21B5} set"), "the footer still offers the list keys")
        XCTAssertTrue(plain(m, selected: width, typing: "").contains("auto"))
    }

    /// A note too long for the width wraps rather than being cut mid-word — a line
    /// of explanation ending in `takes ef…` explains nothing.
    func testALongNoteWrapsInsteadOfBeingCut() {
        let bare = ConfigSettings.editable.firstIndex { $0.key == "bare-render" }!
        let setting = ConfigSettings.editable[bare]

        for cols in [40, 52, 60, 80] {
            let rows = plain(menu(), selected: bare, cols: cols)
                .split(separator: "\n").map(String.init)
            guard let start = rows.firstIndex(where: { $0.contains("A bare file") }) else {
                return XCTFail("the note vanished at \(cols):\n\(rows.joined(separator: "\n"))")
            }
            // The note occupies its row and possibly the next; wrapping breaks on
            // spaces, so joining the rows back reconstructs the text exactly.
            let note = rows[start ... min(start + 1, rows.count - 1)]
                .map { $0.replacingOccurrences(of: "│", with: "")
                    .trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
            XCTAssertFalse(note.contains("\u{2026}"), "the note was cut at \(cols): \(note)")
            XCTAssertTrue(note.contains(setting.blurb),
                          "the blurb is not whole at \(cols): \(note)")
        }
    }

    /// When even two lines cannot hold the caveat, the caveat goes — the row keeps
    /// its `↻`, so the fact is still on screen — rather than being sliced.
    func testTheCaveatIsDroppedBeforeItIsCut() {
        let bare = ConfigSettings.editable.firstIndex { $0.key == "bare-render" }!
        let narrow = plain(menu(), selected: bare, cols: 44)
        XCTAssertFalse(narrow.contains("takes ef\u{2026}"), narrow)
        XCTAssertTrue(narrow.contains("\u{21BB}"), "the marker went with it: \(narrow)")
    }

    // MARK: - Geometry

    /// Autowrap is off, so a row one column over the width clips and takes the frame
    /// with it. Same invariant as the picker and the pager.
    func testEveryRowIsExactlyColsWide() {
        let cases = [menu(), menu("theme: solarized-light\nwidth: 120\n", local: "mouse: false\n")]
        for m in cases {
            for cols in [4, 8, 12, 20, 24, 30, 40, 60, 80, 120] {
                for rows in [8, 12, 24, 40] {
                    for selected in [0, 3, ConfigSettings.editable.count - 1] {
                        for typing in [nil, "", "1024"] as [String?] {
                            let frame = m.draw(selected: selected, typing: typing,
                                               rows: rows, cols: cols)
                            XCTAssertEqual(frame.count, rows, "height at \(rows)x\(cols)")
                            for (i, row) in frame.enumerated() {
                                XCTAssertEqual(Ansi.width(row), cols,
                                               "row \(i) at \(rows)x\(cols): \(Ansi.strip(row))")
                            }
                        }
                    }
                }
            }
        }
    }

    /// More settings than rows: the list scrolls to keep the cursor visible instead
    /// of drawing past the footer.
    func testTheListScrollsToTheCursorOnAShortTerminal() {
        let m = menu()
        let last = ConfigSettings.editable.count - 1
        let short = plain(m, selected: last, rows: 12)
        XCTAssertTrue(short.contains(ConfigSettings.editable[last].label), short)
        XCTAssertFalse(short.contains(ConfigSettings.editable[0].label),
                       "the first row should have scrolled off: \(short)")
    }

    /// The view must not write anything just by being drawn — it writes on a change,
    /// and a test that drew its way into editing a file would be a nasty surprise.
    func testDrawingWritesNothing() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("termdown-untouched-\(UUID().uuidString).yaml")
        let m = ConfigMenu(path: path, local: nil, global: AppConfig())
        _ = m.draw(selected: 0, typing: nil, rows: 24, cols: 80)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
    }
}
