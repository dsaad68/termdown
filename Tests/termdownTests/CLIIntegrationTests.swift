import Foundation
import XCTest
@testable import termdown

/// End-to-end tests that run the built `termdown` binary.
///
/// `ActionResolverTests` proves the decision and `CommandLineOptionsTests`
/// proves the parse; this proves the two are actually wired together in
/// `main.swift` — including the parts that call `exit()` and so cannot be
/// reached in-process: `renderToStdout`, the stdin path, and the exit codes.
///
/// Every run gets an empty working directory so the repository's own
/// `.termdown.yaml` cannot change the output.
final class CLIIntegrationTests: XCTestCase {

    /// Somewhere for the draining thread to put what it read.
    private final class DataBox {
        var value = Data()
    }

    private struct Run {
        let out: String
        let err: String
        let code: Int32
    }

    /// The executable sits in the same build directory as the test bundle — but
    /// where that is relative to the bundle differs between platforms (a
    /// `.xctest` directory on macOS, a plain executable on Linux), so try the
    /// candidates rather than assuming one layout. A miss skips the suite instead
    /// of failing it.
    private static let binary: URL? = {
        let bundle = Bundle(for: CLIIntegrationTests.self).bundleURL
        let runner = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            .deletingLastPathComponent()
        let candidates = [bundle.deletingLastPathComponent(), bundle, runner,
                          runner.deletingLastPathComponent()]
        return candidates.lazy
            .map { $0.appendingPathComponent("termdown") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }()

    private var workDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(CLIIntegrationTests.binary == nil,
                      "termdown executable not found next to the test bundle")
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("td-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let workDir { try? FileManager.default.removeItem(at: workDir) }
        super.tearDown()
    }

    /// Run the binary with `args`, optionally feeding `stdin`. Both pipes make
    /// stdout a non-terminal, which is what keeps every case here
    /// non-interactive.
    private func run(_ args: [String], stdin: String? = nil) throws -> Run {
        let process = Process()
        process.executableURL = try XCTUnwrap(CLIIntegrationTests.binary)
        process.arguments = args
        process.currentDirectoryURL = workDir
        let out = Pipe(), err = Pipe(), input = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = input
        try process.run()

        // Close this process's own copies of the child's ends. Darwin's `Process`
        // does it for you; swift-corelibs-foundation does not, and a reader that
        // holds the write end open can never see EOF — so `readDataToEndOfFile`
        // below waited forever on Linux, after the child had already exited. Under
        // `swift test --parallel` that stalled the whole run at 0% CPU, which reads
        // as "Linux is slow" rather than as the deadlock it is.
        try? out.fileHandleForWriting.close()
        try? err.fileHandleForWriting.close()
        try? input.fileHandleForReading.close()

        input.fileHandleForWriting.write(Data((stdin ?? "").utf8))
        try? input.fileHandleForWriting.close()

        // Drain both pipes at once. Reading one to EOF and then the other deadlocks
        // just as surely once a child writes more than a pipe buffer holds to the
        // stream nobody is reading yet.
        let stderrData = DataBox()
        let drained = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            stderrData.value = err.fileHandleForReading.readDataToEndOfFile()
            drained.signal()
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        drained.wait()
        process.waitUntilExit()
        return Run(out: String(bytes: outData, encoding: .utf8) ?? "",
                   err: String(bytes: stderrData.value, encoding: .utf8) ?? "",
                   code: process.terminationStatus)
    }

    private func file(_ name: String, _ contents: String) throws -> String {
        let url = workDir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    // MARK: - Rendering to stdout

    func testRenderFlagPrintsTheDocumentAndExitsZero() throws {
        let path = try file("doc.md", "# Title\n\nbody text\n")
        let result = try run(["-r", path, "--no-color", "--width", "40"])
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.contains("Title"), result.out)
        XCTAssertTrue(result.out.contains("body text"), result.out)
        XCTAssertEqual(result.err, "")
    }

    /// A render is text, never a pager — no alternate-screen or raw-mode chrome
    /// may reach a redirected stdout.
    func testRenderEmitsNoScreenControlSequences() throws {
        let path = try file("doc.md", "# Title\n")
        let result = try run(["-r", path, "--width", "40"])
        for escape in ["\u{1B}[?1049h", "\u{1B}[?1049l", "\u{1B}[?1000h"] {
            XCTAssertFalse(result.out.contains(escape), "found terminal setup in rendered output")
        }
    }

    func testRenderHasThreeEquivalentSpellings() throws {
        let path = try file("doc.md", "# Title\n\nbody\n")
        let base = try run(["-r", path, "--no-color", "--width", "40"]).out
        XCTAssertFalse(base.isEmpty)
        for spelling in [["--render", path], ["render", path]] {
            let result = try run(spelling + ["--no-color", "--width", "40"])
            XCTAssertEqual(result.code, 0, result.err)
            XCTAssertEqual(result.out, base, "\(spelling) should match -r")
        }
    }

    func testRenderRespectsTheWidthFlag() throws {
        let long = String(repeating: "word ", count: 60)
        let path = try file("doc.md", long + "\n")
        let result = try run(["-r", path, "--no-color", "--width", "30"])
        XCTAssertEqual(result.code, 0, result.err)
        for line in result.out.split(separator: "\n") {
            XCTAssertLessThanOrEqual(line.count, 30, "line wider than --width: \(line)")
        }
        XCTAssertGreaterThan(result.out.split(separator: "\n").count, 1, "expected wrapping")
    }

    func testRenderAppliesTheThemeFlag() throws {
        let path = try file("doc.md", "# Title\n")
        let dark = try run(["-r", path, "--theme", "dark", "--width", "40"]).out
        let nord = try run(["-r", path, "--theme", "nord", "--width", "40"]).out
        XCTAssertNotEqual(dark, nord, "--theme should change the colors in the output")
    }

    // MARK: - stdin

    func testStdinRendersToStdout() throws {
        let result = try run(["-", "--no-color", "--width", "40"], stdin: "# Piped\n\nfrom a pipe\n")
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.contains("Piped"), result.out)
        XCTAssertTrue(result.out.contains("from a pipe"), result.out)
    }

    /// No path and no terminal on stdin means a document was piped in, which is
    /// what makes `cat notes.md | termdown` work without the `-`.
    func testNoArgumentsWithAPipeReadsStdin() throws {
        let result = try run(["--no-color", "--width", "40"], stdin: "# Implicit\n")
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.contains("Implicit"), result.out)
    }

    func testEmptyStdinIsNotAnError() throws {
        let result = try run(["-", "--no-color"], stdin: "")
        XCTAssertEqual(result.code, 0, result.err)
    }

    // MARK: - Failures

    func testMissingBarePathFails() throws {
        let result = try run(["nope.md"])
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.contains("no such file or directory"), result.err)
        XCTAssertEqual(result.out, "")
    }

    func testMissingOpenPathFails() throws {
        let result = try run(["-o", "nope.md"])
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.contains("no such file or directory"), result.err)
    }

    /// A render doesn't stat the path up front — the reader reports it, which
    /// also covers a file that exists but cannot be opened.
    func testUnreadableRenderPathReportsCannotRead() throws {
        let result = try run(["-r", "nope.md"])
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.contains("cannot read"), result.err)
    }

    func testTwoActionsFail() throws {
        let a = try file("a.md", "# A\n")
        let b = try file("b.md", "# B\n")
        let result = try run(["-o", a, "-r", b])
        XCTAssertEqual(result.code, 1)
        XCTAssertFalse(result.err.isEmpty, "a dropped action must be reported")
        XCTAssertEqual(result.out, "", "nothing should be rendered")
    }

    func testUnknownOptionFails() throws {
        let result = try run(["--nope"])
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.contains("unknown option"), result.err)
    }

    func testActionFlagRejectsAFlagAsItsPath() throws {
        let result = try run(["-r", "--theme", "nord"])
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.contains("requires a file path"), result.err)
    }

    // MARK: - Help and version

    // MARK: - The file list without a terminal

    /// A directory argument opens the keyboard-driven file list, which needs a
    /// terminal on both ends. Run with pipes — as this suite runs everything, and as
    /// `termdown notes/ | cat` does — it used to paint a frame into the pipe and then
    /// block forever on a key that could never arrive. It lists what it found now.
    func testADirectoryWithoutATerminalListsInsteadOfHanging() throws {
        _ = try file("one.md", "# One\n")
        _ = try file("two.md", "# Two\n")
        let result = try run(["."])
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.contains("one.md"), result.out)
        XCTAssertTrue(result.out.contains("two.md"), result.out)
        // A listing, not a drawn frame: no alternate screen, no raw-mode chrome.
        for escape in ["\u{1B}[?1049h", "\u{1B}[?1000h"] {
            XCTAssertFalse(result.out.contains(escape), "the picker was drawn into a pipe")
        }
    }

    /// An empty directory still says so and exits 0 — the case that always worked,
    /// asserted so the new guard cannot swallow it.
    func testAnEmptyDirectorySaysSo() throws {
        let result = try run(["."])
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.contains("No markdown files found"), result.out)
    }

    func testVersionMatchesTheSource() throws {
        let result = try run(["--version"])
        XCTAssertEqual(result.code, 0, result.err)
        XCTAssertTrue(result.out.contains(appVersion), "expected \(appVersion) in: \(result.out)")
    }

    func testHelpDocumentsTheActionFlags() throws {
        let result = try run(["--help"])
        XCTAssertEqual(result.code, 0, result.err)
        for expected in ["-o, --open", "-r, --render", "termdown FILE.md", "termdown -"] {
            XCTAssertTrue(result.out.contains(expected), "help is missing \(expected)")
        }
    }
}
