import XCTest
@testable import termdown
@testable import termdownCore

/// Byte goldens for assembled pager frames.
///
/// The width sweep in `PagerDrawingTests` proves each row measures `cols`, but
/// it measures with `Ansi.width` and so cannot notice a frame that is correctly
/// sized and visually wrong. These pin the actual bytes for a few representative
/// states, catching unintended drift in chrome, gutters, tints and the scrollbar.
///
/// Regenerate after an intentional change:
///     TD_UPDATE_SNAPSHOTS=1 swift test
final class FrameGoldenTests: XCTestCase {

    private var goldenDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()        // termdownTests
            .deletingLastPathComponent()        // Tests
            .appendingPathComponent("Fixtures/frames")
    }

    private func assertFrame(_ name: String, _ rows: [String],
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let rendered = rows.joined(separator: "\n")
        let url = goldenDir.appendingPathComponent("\(name).frame")
        if ProcessInfo.processInfo.environment["TD_UPDATE_SNAPSHOTS"] == "1" {
            try FileManager.default.createDirectory(at: goldenDir, withIntermediateDirectories: true)
            try rendered.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
            return XCTFail("missing golden \(name).frame — regenerate with TD_UPDATE_SNAPSHOTS=1 swift test",
                           file: file, line: line)
        }
        XCTAssertEqual(rendered, expected,
                       "frame \(name) drifted — regenerate with TD_UPDATE_SNAPSHOTS=1 swift test if intended",
                       file: file, line: line)
    }

    /// Colors are forced on so goldens are stable regardless of the host TTY.
    private func withColor(_ body: () throws -> Void) rethrows {
        let color = Ansi.colorEnabled
        let truecolor = Ansi.truecolor
        Ansi.colorEnabled = true
        Ansi.truecolor = false
        defer { Ansi.colorEnabled = color; Ansi.truecolor = truecolor }
        try body()
    }

    private func pager(_ lines: [String], links: [LinkInfo] = [],
                       headings: [HeadingInfo] = []) -> Pager {
        var p = Pager(title: "doc.md", lines: lines, headings: headings, links: links)
        p.lines = lines
        p.plainLines = lines.map { Ansi.strip($0) }
        p.headings = headings
        p.mouseSelectEnabled = true
        return p
    }

    private func frame(_ p: inout Pager, searchQuery: String = "",
                       matches: [(lineIndex: Int, range: Range<Int>)] = [],
                       linkFocus: Int? = nil, sidebar: Bool = false) -> [String] {
        p.buildFrame(top: 0, contentRows: 8, cols: 72, maxTop: 12,
                     available: sidebar ? 44 : 68,
                     sidebarActive: sidebar, sidebarFocus: false, sidebarCursor: 0,
                     wrapOn: true, hscroll: 0, followMode: false,
                     reloadFlashActive: false, title: "doc.md",
                     searchQuery: searchQuery, searchMatches: matches, currentMatchIndex: 0,
                     searchMode: false, gotoMode: false, gotoInput: "",
                     linkFocus: linkFocus, copyFlash: nil)
    }

    private let body = [
        "# Heading",
        "",
        "The quick brown fox jumps over the lazy dog.",
        "Second line of prose for the frame.",
        "日本語 と emoji ✅ ❤️ 👍🏽 mixed in.",
        "Fourth line.",
        "Fifth line.",
        "Sixth line.",
    ]

    func testPlainFrame() throws {
        try withColor {
            var p = pager(body)
            try assertFrame("plain", frame(&p))
        }
    }

    func testCursorAndLineSelectionFrame() throws {
        try withColor {
            var p = pager(body)
            p.cursorVisible = true
            p.cursorLine = 3
            p.selectionAnchor = 2
            try assertFrame("line-selection", frame(&p))
        }
    }

    func testTextSelectionFrame() throws {
        try withColor {
            var p = pager(body)
            p.textSelection = TextSelection(anchor: TextPoint(line: 2, col: 4),
                                            head: TextPoint(line: 4, col: 7))
            try assertFrame("text-selection", frame(&p))
        }
    }

    func testSearchAndLinkFocusFrame() throws {
        try withColor {
            var p = pager(body, links: [LinkInfo(lineIndex: 3, url: "x.md", text: "line",
                                                 column: 7, length: 4)])
            try assertFrame("search-and-link",
                            frame(&p, searchQuery: "line", matches: [(3, 7..<11), (6, 6..<10)],
                                  linkFocus: 0))
        }
    }

    func testSidebarFrame() throws {
        try withColor {
            var p = pager(body, headings: [HeadingInfo(lineIndex: 0, level: 1, text: "Heading")])
            try assertFrame("sidebar", frame(&p, sidebar: true))
        }
    }
}
