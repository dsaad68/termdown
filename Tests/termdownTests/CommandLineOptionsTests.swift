import XCTest
@testable import termdown
@testable import termdownCore

/// Argument parsing was inline top-level code in `main.swift` and therefore
/// unreachable from tests; these cover it now that it is a function.
final class CommandLineOptionsTests: XCTestCase {

    private func parse(_ args: [String]) -> Config? {
        if case .success(let config) = Config.parse(args) { return config }
        return nil
    }

    private func failure(_ args: [String]) -> String? {
        if case .failure(let message, _) = Config.parse(args) { return message }
        return nil
    }

    func testEmptyArgumentsLeaveEverythingUnset() throws {
        let config = try XCTUnwrap(parse([]))
        XCTAssertEqual(config.action, .bare(nil))
        XCTAssertNil(config.mouse)         // nil, not false — config file must show through
        XCTAssertNil(config.mouseSelect)
    }

    func testFlagsWithValues() throws {
        let config = try XCTUnwrap(parse(["--width", "72", "--theme", "nord"]))
        XCTAssertEqual(config.width, 72)
        XCTAssertEqual(config.themeName, "nord")
    }

    func testMouseFlagsAreThreeState() throws {
        XCTAssertEqual(parse(["--mouse"])?.mouse, true)
        XCTAssertEqual(parse(["--no-mouse"])?.mouse, false)
        XCTAssertEqual(parse(["--mouse-select"])?.mouseSelect, true)
        XCTAssertEqual(parse(["--no-mouse-select"])?.mouseSelect, false)
        // Each is independent of the other.
        XCTAssertNil(parse(["--mouse"])?.mouseSelect)
        XCTAssertNil(parse(["--mouse-select"])?.mouse)
    }

    /// The three spellings are one code path, so they cannot drift apart.
    func testRenderHasThreeEquivalentSpellings() {
        for spelling in ["render", "-r", "--render"] {
            XCTAssertEqual(parse([spelling, "notes.md"])?.action, .render("notes.md"), spelling)
        }
    }

    func testOpenFlag() {
        for spelling in ["-o", "--open"] {
            XCTAssertEqual(parse([spelling, "notes.md"])?.action, .open("notes.md"), spelling)
        }
    }

    func testFlagsSurviveAroundAnAction() throws {
        let config = try XCTUnwrap(parse(["--width", "72", "-o", "a.md"]))
        XCTAssertEqual(config.action, .open("a.md"))
        XCTAssertEqual(config.width, 72)

        let other = try XCTUnwrap(parse(["-r", "a.md", "--theme", "nord"]))
        XCTAssertEqual(other.action, .render("a.md"))
        XCTAssertEqual(other.themeName, "nord")
    }

    func testBareArgumentBecomesThePositional() {
        // The parser cannot know whether this opens or renders — that depends on
        // `bare-render`, which is not loaded yet. `ActionResolver` decides.
        XCTAssertEqual(parse(["notes.md"])?.action, .bare("notes.md"))
        XCTAssertEqual(parse(["~/docs"])?.action, .bare("~/docs"))
    }

    func testLastPositionalWins() {
        XCTAssertEqual(parse(["a", "b"])?.action, .bare("b"))
    }

    func testStdinPseudoSubcommand() {
        XCTAssertEqual(parse(["-"])?.action, .stdin)
    }

    func testMappingPathAppliesToWhicheverPathIsCarried() {
        XCTAssertEqual(RequestedAction.bare("a").mappingPath { "/abs/" + $0 }, .bare("/abs/a"))
        XCTAssertEqual(RequestedAction.render("a").mappingPath { "/abs/" + $0 }, .render("/abs/a"))
        XCTAssertEqual(RequestedAction.open("a").mappingPath { "/abs/" + $0 }, .open("/abs/a"))
        XCTAssertEqual(RequestedAction.bare(nil).mappingPath { "/abs/" + $0 }, .bare(nil))
        XCTAssertEqual(RequestedAction.stdin.mappingPath { "/abs/" + $0 }, .stdin)
    }

    func testHelpAndVersion() {
        XCTAssertEqual(parse(["--help"])?.showHelp, true)
        XCTAssertEqual(parse(["-h"])?.showHelp, true)
        XCTAssertEqual(parse(["--version"])?.showVersion, true)
        XCTAssertEqual(parse(["-V"])?.showVersion, true)
    }

    // MARK: - Failures

    func testUnknownOptionFails() {
        XCTAssertEqual(failure(["--nope"]), "termdown: unknown option --nope")
        XCTAssertEqual(failure(["-x"]), "termdown: unknown option -x")
    }

    func testValueFlagsRequireAValue() {
        XCTAssertEqual(failure(["--width"]), "termdown: --width requires a number")
        XCTAssertEqual(failure(["--width", "wide"]), "termdown: --width requires a number")
        XCTAssertEqual(failure(["--theme"]), "termdown: --theme requires a name")
        XCTAssertEqual(failure(["render"]), "termdown: render requires a file path")
        XCTAssertEqual(failure(["-r"]), "termdown: -r requires a file path")
        XCTAssertEqual(failure(["-o"]), "termdown: -o requires a file or directory path")
    }

    /// `render` used to take the next token unconditionally, so
    /// `termdown render --theme nord` went looking for a file named `--theme`.
    func testActionFlagsRejectAFlagAsTheirPath() {
        XCTAssertEqual(failure(["render", "--theme", "nord"]), "termdown: render requires a file path")
        XCTAssertEqual(failure(["-r", "--theme"]), "termdown: -r requires a file path")
        XCTAssertEqual(failure(["-o", "--theme"]), "termdown: -o requires a file or directory path")
    }

    /// Two actions on one command line is a mistake, not a preference. It used
    /// to silently keep one and drop the other.
    func testConflictingActionsFail() {
        XCTAssertEqual(failure(["-o", "a.md", "-r", "b.md"]),
                       "termdown: -r cannot be combined with -o")
        XCTAssertEqual(failure(["render", "a.md", "-o", "b.md"]),
                       "termdown: -o cannot be combined with render")
        XCTAssertEqual(failure(["-r", "a.md", "-r", "b.md"]),
                       "termdown: -r may only be given once")
    }

    /// `termdown render a.md b.md` used to drop `b.md` without a word.
    func testAPositionalAfterAnActionFails() {
        XCTAssertEqual(failure(["render", "a.md", "b.md"]),
                       "termdown: unexpected argument 'b.md' after render")
        XCTAssertEqual(failure(["-", "a.md"]), "termdown: unexpected argument 'a.md' after -")
    }

    /// The usage text is the only place several flags are documented, so it
    /// must at least mention every one the parser accepts.
    func testUsageMentionsEveryFlag() {
        for flag in ["--width", "--theme", "--no-color", "--mouse", "--no-mouse",
                     "--mouse-select", "--no-mouse-select", "--version", "--help",
                     "render", "bare-render", "-o", "--open", "-r", "--render"] {
            XCTAssertTrue(Config.usage.contains(flag), "\(flag) missing from --help")
        }
    }

    /// `--theme` accepts any registered name, but the list is written out by
    /// hand — a theme missing here is one nobody can discover.
    func testUsageListsEveryRegisteredTheme() {
        for (name, _) in Theme.all {
            XCTAssertTrue(Config.usage.contains(name), "\(name) missing from the --help theme list")
        }
    }
}
