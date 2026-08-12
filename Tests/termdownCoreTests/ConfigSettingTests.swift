import Foundation
import XCTest
@testable import termdownCore

/// The table the settings view is built from: the values each key accepts, how
/// they cycle, and — the invariant that matters most — that a value written under
/// a setting's own key is a value the parser reads back.
final class ConfigSettingTests: XCTestCase {

    private func tempConfig() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("termdown-setting-\(UUID().uuidString).yaml")
    }

    private func parse(_ url: URL) throws -> AppConfig? {
        AppConfig.parseYAML(try Data(contentsOf: url))
    }

    // MARK: - The round trip

    /// Every row has to survive a write and a read: the writer spells the key from
    /// `ConfigSetting.key`, and the parser has its own `switch`. A key in one and not
    /// the other is a row that silently does nothing, which is the whole failure mode
    /// this view could have.
    func testEverySettingSurvivesAWriteAndAReadBack() throws {
        for setting in ConfigSettings.editable {
            let url = tempConfig()
            defer { try? FileManager.default.removeItem(at: url) }

            // A value that differs from the default, so a dropped write cannot pass
            // by looking like the fallback.
            let written: String
            switch setting.kind {
            case .toggle: written = setting.fallback == "true" ? "false" : "true"
            case .choice(let options): written = options.last ?? setting.fallback
            case .number: written = "97"
            }

            AppConfig.writeValue(written, for: setting, to: url)
            let config = try parse(url)
            let onDisk = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(config?.value(for: setting), written,
                           "\(setting.key) did not read back:\n\(onDisk)")
        }
    }

    /// The view reads values through `value(for:)`, so a setting the loader parses
    /// into a field nothing maps back would show its default forever.
    func testEverySettingIsReadableFromAParsedFile() {
        let yaml = """
        theme: nord
        no-color: true
        width: 72
        mouse: false
        mouse-select: false
        mermaid: false
        mermaid-charset: ascii
        wide-emoji: scalar
        file-list-view: folders
        bare-render: true
        """
        let config = AppConfig.parseYAML(Data(yaml.utf8))
        for setting in ConfigSettings.editable {
            XCTAssertNotNil(config?.value(for: setting), "\(setting.key) is not readable")
            XCTAssertNotEqual(config?.effectiveValue(for: setting), setting.fallback,
                              "\(setting.key) fell back to its default")
        }
    }

    /// A key the file does not set shows its built-in default, and that default has
    /// to be one of the values the row can cycle to — otherwise the first Space
    /// press would jump somewhere unrelated.
    func testDefaultsAreValuesTheRowCanReach() {
        let empty = AppConfig()
        for setting in ConfigSettings.editable {
            XCTAssertEqual(empty.effectiveValue(for: setting), setting.fallback, setting.key)
            switch setting.kind {
            case .toggle:
                XCTAssertTrue(["true", "false"].contains(setting.fallback), setting.key)
            case .choice(let options):
                XCTAssertTrue(options.contains(setting.fallback), setting.key)
            case .number:
                XCTAssertNotNil(Int(setting.fallback), setting.key)
            }
        }
    }

    // MARK: - Moving between values

    func testToggleFlipsBothWays() {
        let mouse = ConfigSettings.named("mouse")!
        XCTAssertEqual(mouse.next(after: "true"), "false")
        XCTAssertEqual(mouse.next(after: "false"), "true")
        XCTAssertEqual(mouse.previous(before: "true"), "false")
    }

    func testChoiceCyclesRoundInBothDirections() {
        let charset = ConfigSettings.named("mermaid-charset")!
        XCTAssertEqual(charset.next(after: "unicode"), "ascii")
        XCTAssertEqual(charset.next(after: "ascii"), "unicode", "the list has to wrap")
        XCTAssertEqual(charset.previous(before: "unicode"), "ascii")
    }

    /// A value the list has never heard of — a typo in the file — must land on a
    /// real option rather than sticking, or the row could not be fixed from here.
    func testAnUnknownValueCyclesBackIntoTheList() {
        let view = ConfigSettings.named("file-list-view")!
        XCTAssertEqual(view.next(after: "banana"), "files")
        XCTAssertEqual(view.previous(before: "banana"), "folders")
    }

    /// Cycling a number would be nonsense — it is typed — so the row reports the
    /// value it already has.
    func testANumberDoesNotCycle() {
        let width = ConfigSettings.named("width")!
        XCTAssertEqual(width.next(after: "80"), "80")
        XCTAssertEqual(width.previous(before: "80"), "80")
    }

    /// 0 is how the file spells "follow the terminal", and the row says so.
    func testZeroWidthReadsAsAuto() {
        let width = ConfigSettings.named("width")!
        XCTAssertEqual(width.display("0"), "auto")
        XCTAssertEqual(width.display(""), "auto")
        XCTAssertEqual(width.display("80"), "80")
    }

    // MARK: - Lookup

    func testLookupAcceptsEverySpellingTheParserDoes() {
        for setting in ConfigSettings.editable {
            for spelling in [setting.key] + setting.aliases {
                XCTAssertEqual(ConfigSettings.named(spelling)?.key, setting.key, spelling)
                XCTAssertEqual(ConfigSettings.named(spelling.uppercased())?.key, setting.key, spelling)
            }
        }
        XCTAssertNil(ConfigSettings.named("ignore-patterns"), "a list is not editable as a row")
        XCTAssertNil(ConfigSettings.named("key-scroll-down"))
    }

    /// The theme row offers the themes that exist, so it can never show a name
    /// `Theme.named` would fall back to `dark` for.
    func testTheThemeRowOffersEveryTheme() {
        guard case .choice(let options) = ConfigSettings.named("theme")!.kind else {
            return XCTFail("the theme row is not a choice")
        }
        XCTAssertEqual(options, Theme.all.map(\.name))
        XCTAssertTrue(options.allSatisfy { Theme.named($0) != nil })
    }

    /// Rows are labelled and explained; a blank one would draw an empty line in the
    /// view and say nothing in its footer.
    func testEveryRowIsLabelledAndExplained() {
        for setting in ConfigSettings.editable {
            XCTAssertFalse(setting.label.isEmpty, setting.key)
            XCTAssertFalse(setting.blurb.isEmpty, setting.key)
            XCTAssertLessThanOrEqual(setting.label.count, 20, "\(setting.key): label too wide for the column")
        }
    }
}
