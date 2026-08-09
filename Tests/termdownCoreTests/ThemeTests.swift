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
        XCTAssertGreaterThanOrEqual(Theme.all.count, 29)
        for (name, theme) in Theme.all {
            XCTAssertEqual(theme.heading.count, 6, "\(name) must define 6 heading levels")
        }
    }

    func testCustomPastelFamiliesResolve() {
        for name in ["matte-rose", "matte-slate", "matte-moss",
                     "frost", "mint", "dusk", "glacier",
                     "blossom", "sand", "coral", "ember", "terracotta"] {
            XCTAssertNotNil(Theme.named(name), name)
        }
    }

    func testPortedPalettesResolve() {
        for name in ["catppuccin", "rose-pine", "nord", "tokyo-night", "gruvbox", "dracula",
                     "solarized-dark", "solarized-light", "everforest", "kanagawa",
                     "one-dark", "monokai", "ayu-mirage", "night-owl"] {
            XCTAssertNotNil(Theme.named(name), name)
        }
    }

    /// The config template enumerates theme names by hand, so a name that drifts
    /// out of it is undiscoverable for anyone reading their own config file.
    /// (The `--help` list is covered in `CommandLineOptionsTests`, where the
    /// executable module — and so the text itself — is importable.)
    func testEveryRegisteredNameIsInTheConfigTemplate() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/termdownCore/ConfigLoader.swift"),
            encoding: .utf8)
        // The template is a private literal, so match against the file text.
        for (name, _) in Theme.all {
            XCTAssertTrue(source.contains(name), "\(name) missing from the config template")
        }
    }

    /// Bold is SGR 1, which is invisible wherever the font ships no bold face, so
    /// every theme has to back it with a foreground that differs from the ones
    /// ordinary prose already uses. A theme whose `strong` matched its body-ish
    /// tones would put us straight back to bold reading as plain text.
    func testEveryThemeGivesStrongItsOwnForeground() {
        for (name, theme) in Theme.all {
            XCTAssertNotEqual(theme.strong, theme.inlineCode, "\(name): strong must not read as code")
            XCTAssertNotEqual(theme.strong, theme.comment, "\(name): strong must not read as a comment")
        }
    }

    /// `alertAbstract` is the one callout color with no counterpart among the
    /// GitHub five, and it carries a shared default rather than a per-theme
    /// value. A theme whose note or tip color happens to land on that default
    /// would render `[!ABSTRACT]` indistinguishable from `[!NOTE]`.
    func testEveryThemeKeepsAbstractApartFromNoteAndTip() {
        for (name, theme) in Theme.all where name != "mono" {
            XCTAssertNotEqual(theme.alertAbstract, theme.alertNote, "\(name): abstract reads as a note")
            XCTAssertNotEqual(theme.alertAbstract, theme.alertTip, "\(name): abstract reads as a tip")
        }
    }

    func testThemeNamesAreUnique() {
        let names = Theme.all.map { $0.name }
        XCTAssertEqual(names.count, Set(names).count, "duplicate theme name")
    }
}
