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

    func testRenderSubcommandTakesTheNextArgument() {
        XCTAssertEqual(parse(["render", "notes.md"])?.action, .render("notes.md"))
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

    /// An action named outright beats a bare positional, whichever order they
    /// arrive in.
    func testNamedActionWinsOverAPositional() {
        XCTAssertEqual(parse(["notes.md", "render", "other.md"])?.action, .render("other.md"))
        XCTAssertEqual(parse(["render", "other.md", "notes.md"])?.action, .render("other.md"))
    }

    func testStdinPseudoSubcommand() {
        XCTAssertEqual(parse(["-"])?.action, .stdin)
    }

    func testMappingPathAppliesToWhicheverPathIsCarried() {
        XCTAssertEqual(RequestedAction.bare("a").mappingPath { "/abs/" + $0 }, .bare("/abs/a"))
        XCTAssertEqual(RequestedAction.render("a").mappingPath { "/abs/" + $0 }, .render("/abs/a"))
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
    }

    /// Documents a known sharp edge rather than asserting it is desirable:
    /// `render` takes the next token unconditionally, flag or not.
    func testRenderSwallowsAFollowingFlag() {
        XCTAssertEqual(parse(["render", "--theme", "nord"])?.action, .render("--theme"))
    }

    /// The usage text is the only place several flags are documented, so it
    /// must at least mention every one the parser accepts.
    func testUsageMentionsEveryFlag() {
        for flag in ["--width", "--theme", "--no-color", "--mouse", "--no-mouse",
                     "--mouse-select", "--no-mouse-select", "--version", "--help",
                     "render", "bare-render"] {
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
