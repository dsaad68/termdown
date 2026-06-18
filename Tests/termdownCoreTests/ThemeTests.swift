import XCTest
@testable import termdownCore

final class ThemeTests: XCTestCase {

    func testBuiltInThemesHaveSixHeadingLevels() {
        XCTAssertEqual(Theme.dark.heading.count, 6)
        XCTAssertEqual(Theme.light.heading.count, 6)
        XCTAssertEqual(Theme.mono.heading.count, 6)
    }

    func testMonoIsUniformGray() {
        // mono renders everything in color 7 (no hierarchy / accents).
        XCTAssertTrue(Theme.mono.heading.allSatisfy { $0 == 7 })
        XCTAssertEqual(Theme.mono.link, 7)
        XCTAssertEqual(Theme.mono.codeBar, 7)
        XCTAssertEqual(Theme.mono.math, 7)
    }

    func testWithColorsEnabled() {
        // Disabling colors falls back to the mono theme.
        let off = Theme.dark.withColorsEnabled(false)
        XCTAssertEqual(off.heading, Theme.mono.heading)
        XCTAssertEqual(off.link, Theme.mono.link)
        // Enabled returns the theme unchanged.
        let on = Theme.dark.withColorsEnabled(true)
        XCTAssertEqual(on.heading, Theme.dark.heading)
    }

    func testDistinctThemesDiffer() {
        XCTAssertNotEqual(Theme.dark.heading, Theme.light.heading)
    }

    func testRegistryResolvesByName() {
        XCTAssertNotNil(Theme.named("dracula"))
        XCTAssertNotNil(Theme.named("rose-pine"))
        XCTAssertNotNil(Theme.named("CATPPUCCIN"))   // case-insensitive
        XCTAssertNil(Theme.named("bogus"))
    }

    func testAllThemesAreCompleteAndRegistered() {
        XCTAssertTrue(Theme.all.contains { $0.name == "dark" })
        XCTAssertGreaterThanOrEqual(Theme.all.count, 17)
        for (name, theme) in Theme.all {
            XCTAssertEqual(theme.heading.count, 6, "\(name) must define 6 heading levels")
        }
    }

    func testCustomPastelFamiliesResolve() {
        for name in ["matte-rose", "matte-slate", "frost", "mint", "dusk", "blossom", "sand", "coral"] {
            XCTAssertNotNil(Theme.named(name), name)
        }
    }

    func testThemeNamesAreUnique() {
        let names = Theme.all.map { $0.name }
        XCTAssertEqual(names.count, Set(names).count, "duplicate theme name")
    }
}
