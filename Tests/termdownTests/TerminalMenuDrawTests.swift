import XCTest
@testable import termdown
@testable import termdownCore

/// Tests for the file picker's chrome: the launch wordmark vs. the slim
/// contextual header used when the finder is opened for a new tab.
final class TerminalMenuDrawTests: XCTestCase {

    private func sampleMenu() -> TerminalMenu {
        var m = TerminalMenu(title: "termdown",
                             items: ["a.md", "docs/b.md"],
                             details: ["1d", "2h"])
        m.path = "~/notes"
        return m
    }

    private func filtered(_ items: [String]) -> [(item: String, indices: [Int])] {
        items.map { ($0, []) }
    }

    /// At launch the picker shows the "markdown viewer" tagline and no tab context.
    func testLaunchHeaderShowsTagline() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false, filteredItems: filtered(m.items),
                           detailFor: ["a.md": "1d", "docs/b.md": "2h"], context: nil)
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("markdown viewer"), plain)   // launch tagline
        XCTAssertTrue(plain.contains("v" + appVersion), plain)    // release version in the header
        XCTAssertFalse(plain.contains("New tab"), plain)
    }

    /// In "New tab" context the launch tagline is swapped for a slim picker header,
    /// while the top-border legend stays the app name (so the context isn't shown
    /// twice).
    func testContextHeaderReplacesLaunchChrome() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false, filteredItems: filtered(m.items),
                           detailFor: ["a.md": "1d", "docs/b.md": "2h"], context: "New tab")
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(plain.contains("New tab"), plain)           // slim contextual title
        XCTAssertTrue(plain.contains("pick a file"), plain)       // contextual hint
        XCTAssertFalse(plain.contains("markdown viewer"), plain)  // not the launch tagline
        XCTAssertTrue(plain.contains("termdown"), plain)          // legend stays the app name

        // The context label must appear exactly once (not duplicated in the legend).
        let occurrences = plain.lowercased().components(separatedBy: "new tab").count - 1
        XCTAssertEqual(occurrences, 1, plain)
    }

    /// The "termdown" legend above the new-tab finder uses the wordmark's
    /// per-letter gradient, not a single flat color.
    func testContextLegendIsGradient() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                           query: "", searching: false, filteredItems: filtered(m.items),
                           detailFor: [:], context: "New tab")
        let topBorder = frame[0]   // the legend lives on the top border row
        // The blue→mauve ramp's first and last stops must both appear (a gradient,
        // not a single flat color).
        XCTAssertTrue(topBorder.contains("38;5;75"), topBorder)   // 't' — blue stop
        XCTAssertTrue(topBorder.contains("38;5;183"), topBorder)  // 'n' — mauve stop
    }

    /// The launch view shows the app name once (the wordmark), with no duplicate
    /// legend tab on the top border. A narrow width forces the literal-text
    /// wordmark fallback so the name is countable in the stripped output.
    func testLaunchViewShowsNameOnce() {
        let m = sampleMenu()
        let frame = m.draw(selected: 0, top: 0, viewport: 3, rows: 16, cols: 30,
                           query: "", searching: false, filteredItems: filtered(m.items),
                           detailFor: [:], context: nil)
        let plain = frame.map { Ansi.strip($0) }.joined(separator: "\n")
        let occurrences = plain.lowercased().components(separatedBy: "termdown").count - 1
        XCTAssertEqual(occurrences, 1, plain)
    }

    /// The search box is modal: unfocused it prompts to press `/`; focused it
    /// shows the typing affordance. This guards the fix where letters like q / c
    /// used to be intercepted as commands instead of filtering.
    func testSearchBoxReflectsFocus() {
        let m = sampleMenu()
        let unfocused = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                               query: "", searching: false, filteredItems: filtered(m.items),
                               detailFor: [:], context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(unfocused.contains("/ search"), unfocused)
        XCTAssertFalse(unfocused.contains("Esc done"), unfocused)

        let focused = m.draw(selected: 0, top: 0, viewport: 5, rows: 20, cols: 80,
                             query: "cfg", searching: true, filteredItems: filtered(["config.md"]),
                             detailFor: [:], context: nil)
            .map { Ansi.strip($0) }.joined(separator: "\n")
        XCTAssertTrue(focused.contains("cfg"), focused)        // the typed query is shown
        XCTAssertTrue(focused.contains("Esc done"), focused)   // focused-mode hint
    }

    /// The frame fills the full terminal height (11 chrome rows + viewport), so a
    /// plain `render` overwrites every row and no screen-clear flash is needed.
    func testFrameFillsRows() {
        let m = sampleMenu()
        let rows = 24
        let frame = m.draw(selected: 0, top: 0, viewport: rows - 11, rows: rows, cols: 80,
                           query: "", searching: false, filteredItems: filtered(m.items),
                           detailFor: [:], context: nil)
        XCTAssertEqual(frame.count, rows)
    }
}
