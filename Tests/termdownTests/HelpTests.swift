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

    /// `d` is the only way to find the folder browser — nothing on the launch
    /// screen spells it out beyond a four-word hint — so the help pane is the
    /// documentation, and every key it needs has to be in it.
    func testMenuHelpDocumentsTheFolderKeys() {
        let folders = Terminal.menuHelpGroups.first { $0.name == "Folders" }
        let items = folders?.items ?? []
        XCTAssertFalse(items.isEmpty, "no Folders pane in the file-list help")
        XCTAssertTrue(items.contains { $0.hasPrefix("d ") }, items.description)
        XCTAssertTrue(items.contains { $0.hasPrefix("Enter") }, items.description)
        XCTAssertTrue(items.contains { $0.hasPrefix("Backspace") && $0.contains("Up one level") },
                      items.description)
        XCTAssertTrue(items.contains { $0.hasPrefix("Esc") }, items.description)
    }

    /// Every pane is drawn in one box sized to its widest line, and the help lines
    /// hand-align their description column. A line that outgrew the others would
    /// widen the box for all of them and get elided first on a narrow terminal.
    func testHelpLinesShareTheirColumnAndLength() {
        for (name, items) in Terminal.menuHelpGroups {
            for item in items {
                XCTAssertLessThanOrEqual(item.count, 62, "\(name): too wide for the box — \(item)")
                // Two runs of text separated by the aligned gap, not a ragged one.
                XCTAssertTrue(item.contains("  "), "\(name): no key column — \(item)")
            }
        }
    }
}
