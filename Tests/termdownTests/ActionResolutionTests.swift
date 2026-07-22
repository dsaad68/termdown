import XCTest
@testable import termdown

/// What termdown decides to do, given a command line, a config and a
/// filesystem. This decision used to be spread across four places in
/// `main.swift`'s top-level code — a promotion block, an auto-detect, and two
/// error guards — and was therefore untestable. It is one pure function now.
final class ActionResolutionTests: XCTestCase {

    private func resolve(_ requested: RequestedAction,
                         bareRender: Bool = false,
                         stdinIsTTY: Bool = true,
                         cwd: String = "/cwd",
                         kinds: [String: PathKind] = [:]) -> ActionResolver.Outcome {
        ActionResolver.resolve(requested, bareRender: bareRender, stdinIsTTY: stdinIsTTY,
                               cwd: cwd, kind: { kinds[$0] ?? .missing })
    }

    private let tree: [String: PathKind] = ["/notes.md": .file, "/docs": .directory]

    // MARK: - No path given

    func testNoArgumentsOpensThePickerOverTheCurrentDirectory() {
        XCTAssertEqual(resolve(.bare(nil)), .action(.picker(root: "/cwd")))
    }

    /// A document piped in with no path is read from stdin.
    func testNoArgumentsWithAPipeReadsStdin() {
        XCTAssertEqual(resolve(.bare(nil), stdinIsTTY: false), .action(.stdin))
    }

    /// …but a path on the command line beats the pipe.
    func testAPathBeatsThePipe() {
        XCTAssertEqual(resolve(.bare("/docs"), stdinIsTTY: false, kinds: tree),
                       .action(.picker(root: "/docs")))
    }

    // MARK: - A bare path

    func testBareDirectoryOpensThePicker() {
        for bareRender in [false, true] {
            XCTAssertEqual(resolve(.bare("/docs"), bareRender: bareRender, kinds: tree),
                           .action(.picker(root: "/docs")),
                           "bareRender: \(bareRender)")
        }
    }

    /// `bare-render` changes what a bare *file* means, and nothing else.
    func testBareFileFollowsTheConfig() {
        XCTAssertEqual(resolve(.bare("/notes.md"), bareRender: true, kinds: tree),
                       .action(.render(file: "/notes.md")))
    }

    /// A missing path is a typo, under either setting — never a document to read
    /// and never a directory to browse.
    func testMissingPathAlwaysFails() {
        for bareRender in [false, true] {
            guard case .failure(let message, let code) =
                resolve(.bare("/nope.md"), bareRender: bareRender, kinds: tree) else {
                return XCTFail("expected a failure, bareRender: \(bareRender)")
            }
            XCTAssertEqual(message, "termdown: '/nope.md': no such file or directory")
            XCTAssertEqual(code, 1)
        }
    }

    // MARK: - Actions named outright

    func testExplicitRenderIsNeverReinterpreted() {
        for bareRender in [false, true] {
            XCTAssertEqual(resolve(.render("/notes.md"), bareRender: bareRender, kinds: tree),
                           .action(.render(file: "/notes.md")),
                           "bareRender: \(bareRender)")
        }
    }

    /// Existence is deliberately not checked here — the reader reports `cannot
    /// read`, which also covers a file that exists but will not open.
    func testExplicitRenderDoesNotStatThePath() {
        XCTAssertEqual(resolve(.render("/nope.md")), .action(.render(file: "/nope.md")))
    }

    func testStdinIsNeverReinterpreted() {
        for bareRender in [false, true] {
            XCTAssertEqual(resolve(.stdin, bareRender: bareRender), .action(.stdin))
        }
    }

    /// An explicit render is not hijacked by a pipe on stdin.
    func testExplicitRenderSurvivesAPipe() {
        XCTAssertEqual(resolve(.render("/notes.md"), stdinIsTTY: false, kinds: tree),
                       .action(.render(file: "/notes.md")))
    }
}
