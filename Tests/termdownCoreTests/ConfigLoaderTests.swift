import XCTest
@testable import termdownCore

final class ConfigLoaderTests: XCTestCase {

    private func parse(_ yaml: String) -> AppConfig? {
        AppConfig.parseYAML(Data(yaml.utf8))
    }

    func testParsesBasicKeys() {
        let cfg = parse("theme: light\nwidth: 100\nmouse: true")
        XCTAssertEqual(cfg?.theme, "light")
        XCTAssertEqual(cfg?.width, 100)
        XCTAssertEqual(cfg?.mouse, true)
        XCTAssertNil(cfg?.noColor)   // unset keys stay nil
    }

    func testIgnoresCommentsAndBlankLines() {
        let cfg = parse("# a comment\n\n  \ntheme: dark\n")
        XCTAssertEqual(cfg?.theme, "dark")
        XCTAssertNil(cfg?.width)
    }

    func testStripsQuotesAndInlineComments() {
        XCTAssertEqual(parse("theme: \"mono\"")?.theme, "mono")
        XCTAssertEqual(parse("theme: 'mono'")?.theme, "mono")
        XCTAssertEqual(parse("width: 80   # columns")?.width, 80)
    }

    func testBooleanForms() {
        XCTAssertEqual(parse("mouse: yes")?.mouse, true)
        XCTAssertEqual(parse("mouse: on")?.mouse, true)
        XCTAssertEqual(parse("mouse: 1")?.mouse, true)
        XCTAssertEqual(parse("mouse: false")?.mouse, false)
        XCTAssertEqual(parse("mouse: nope")?.mouse, false)
    }

    func testKeyAliases() {
        XCTAssertEqual(parse("no-color: true")?.noColor, true)
        XCTAssertEqual(parse("no_color: true")?.noColor, true)
        XCTAssertEqual(parse("nocolor: true")?.noColor, true)
    }

    func testIgnorePatternsList() {
        XCTAssertEqual(parse("ignore-patterns: [build, dist, .cache]")?.ignorePatterns,
                       ["build", "dist", ".cache"])
        XCTAssertEqual(parse("ignore-patterns: a, b")?.ignorePatterns, ["a", "b"])
    }

    func testMalformedLinesAreIgnored() {
        let cfg = parse("this has no colon\ntheme: dark\n!!garbage")
        XCTAssertEqual(cfg?.theme, "dark")
        XCTAssertNil(cfg?.width)
        XCTAssertNil(cfg?.mouse)
    }

    func testMergeProjectWinsKeyByKey() {
        var base = AppConfig()
        base.theme = "dark"; base.width = 80; base.mouse = false
        var override = AppConfig()
        override.theme = "light"; override.mouse = true   // width left unset
        base.merge(override)
        XCTAssertEqual(base.theme, "light")   // overridden
        XCTAssertEqual(base.mouse, true)      // overridden
        XCTAssertEqual(base.width, 80)        // preserved (override didn't set it)
    }
}
