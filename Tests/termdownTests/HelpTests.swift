import XCTest
@testable import termdown

/// Tests for the grouped, tabbed help content.
final class HelpTests: XCTestCase {

    func testPagerHelpIsGroupedAndComplete() {
        let groups = Terminal.pagerHelpGroups
        XCTAssertGreaterThanOrEqual(groups.count, 5)                 // several function panes
        XCTAssertTrue(groups.allSatisfy { !$0.items.isEmpty })       // no empty pane
        let names = groups.map { $0.name }
        for expected in ["Move", "Search", "Links", "Tabs", "View", "Folds", "Edit"] {
            XCTAssertTrue(names.contains(expected), names.description)
        }
        let all = groups.flatMap { $0.items }.joined(separator: "\n")
        XCTAssertTrue(all.contains("Theme selector"), all)
        XCTAssertTrue(all.contains("Heading banners"), all)
        XCTAssertTrue(all.contains("Wikilink"), all)
        XCTAssertTrue(all.contains("Edit the block under the cursor"), all)
        XCTAssertTrue(all.contains("Show/hide the line cursor"), all)
        XCTAssertTrue(all.contains("Toggle the task checkbox under the cursor"), all)
        XCTAssertTrue(all.contains("Save the file to disk"), all)
    }

    /// The editing keys belong together: the task toggle rides the same
    /// buffer → unsaved → Ctrl-S path as the inline editor, and the help should
    /// say so by grouping them.
    func testTaskToggleIsListedWithTheEditingKeys() {
        let edit = Terminal.pagerHelpGroups.first { $0.name == "Edit" }
        let items = try? XCTUnwrap(edit).items
        XCTAssertTrue(items?.contains { $0.hasPrefix("Space") } == true, (items ?? []).description)
    }

    /// `q` leaves termdown when a file was opened directly, so the help must not
    /// promise a file list that isn't there.
    func testQuitHelpDoesNotPromiseAFileList() {
        let all = Terminal.pagerHelpGroups.flatMap { $0.items }.joined(separator: "\n")
        let quit = all.split(separator: "\n").first { $0.hasPrefix("q / Esc") }
        XCTAssertNotNil(quit)
        XCTAssertFalse(quit?.contains("file list") == true, quit.map(String.init) ?? "")
    }

    func testMenuHelpIsGroupedAndComplete() {
        let groups = Terminal.menuHelpGroups
        XCTAssertGreaterThanOrEqual(groups.count, 2)
        XCTAssertTrue(groups.allSatisfy { !$0.items.isEmpty })
        let all = groups.flatMap { $0.items }.joined(separator: "\n")
        XCTAssertTrue(all.contains("fuzzy"), all)
        XCTAssertTrue(all.contains("Open selected file"), all)
    }
}
