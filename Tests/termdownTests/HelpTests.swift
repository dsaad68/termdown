import XCTest
@testable import termdown

/// Tests for the grouped, tabbed help content.
final class HelpTests: XCTestCase {

    func testPagerHelpIsGroupedAndComplete() {
        let groups = Terminal.pagerHelpGroups
        XCTAssertGreaterThanOrEqual(groups.count, 5)                 // several function panes
        XCTAssertTrue(groups.allSatisfy { !$0.items.isEmpty })       // no empty pane
        let names = groups.map { $0.name }
        for expected in ["Move", "Search", "Links", "Tabs", "View", "Folds"] {
            XCTAssertTrue(names.contains(expected), names.description)
        }
        let all = groups.flatMap { $0.items }.joined(separator: "\n")
        XCTAssertTrue(all.contains("Theme selector"), all)
        XCTAssertTrue(all.contains("Heading banners"), all)
        XCTAssertTrue(all.contains("Wikilink"), all)
        XCTAssertTrue(all.contains("Edit the block under the cursor"), all)
        XCTAssertTrue(all.contains("Show/hide the line cursor"), all)
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
