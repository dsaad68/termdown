import XCTest
@testable import termdownCore

/// Tests for flipping GFM task-list checkboxes on a raw source line.
final class TaskMarkerTests: XCTestCase {

    // MARK: - Toggling

    func testTogglesUncheckedToChecked() {
        XCTAssertEqual(TaskMarker.toggle("- [ ] buy milk"), "- [x] buy milk")
    }

    func testTogglesCheckedToUnchecked() {
        XCTAssertEqual(TaskMarker.toggle("- [x] buy milk"), "- [ ] buy milk")
    }

    func testAcceptsUppercaseMarkButNormalizesToLowercase() {
        XCTAssertEqual(TaskMarker.toggle("- [X] buy milk"), "- [ ] buy milk")
        XCTAssertEqual(TaskMarker.toggle("- [ ] buy milk"), "- [x] buy milk")
    }

    func testPreservesIndentation() {
        XCTAssertEqual(TaskMarker.toggle("    - [ ] nested"), "    - [x] nested")
        XCTAssertEqual(TaskMarker.toggle("\t- [ ] tabbed"), "\t- [x] tabbed")
    }

    func testPreservesBulletStyle() {
        XCTAssertEqual(TaskMarker.toggle("* [ ] star"), "* [x] star")
        XCTAssertEqual(TaskMarker.toggle("+ [ ] plus"), "+ [x] plus")
    }

    func testPreservesOrderedMarkers() {
        XCTAssertEqual(TaskMarker.toggle("1. [ ] first"), "1. [x] first")
        XCTAssertEqual(TaskMarker.toggle("12) [ ] twelfth"), "12) [x] twelfth")
    }

    func testPreservesExtraSpacingAroundTheMarker() {
        XCTAssertEqual(TaskMarker.toggle("-   [ ]   spaced"), "-   [x]   spaced")
    }

    func testPreservesTrailingContentVerbatim() {
        let line = "- [ ] ship **it** `now` <!-- keep -->"
        XCTAssertEqual(TaskMarker.toggle(line), "- [x] ship **it** `now` <!-- keep -->")
    }

    func testTogglesBareCheckboxWithNoContent() {
        XCTAssertEqual(TaskMarker.toggle("- [ ]"), "- [x]")
    }

    // MARK: - Non-tasks are left alone

    func testPlainListItemIsNotATask() {
        XCTAssertNil(TaskMarker.toggle("- just a bullet"))
    }

    func testLinkAtStartOfItemIsNotATask() {
        XCTAssertNil(TaskMarker.toggle("- [label](http://example.com)"))
        XCTAssertNil(TaskMarker.toggle("- [x](http://example.com)"))
    }

    func testWikilinkAtStartOfItemIsNotATask() {
        XCTAssertNil(TaskMarker.toggle("- [[Page]]"))
    }

    func testCheckboxWithoutABulletIsNotATask() {
        XCTAssertNil(TaskMarker.toggle("[ ] no bullet"))
    }

    func testCheckboxNeedsSpaceAfterTheBullet() {
        XCTAssertNil(TaskMarker.toggle("-[ ] tight"))
    }

    func testNonCheckboxMarkIsNotATask() {
        XCTAssertNil(TaskMarker.toggle("- [?] unknown"))
        XCTAssertNil(TaskMarker.toggle("- [] empty"))
    }

    func testHeadingAndParagraphAreNotTasks() {
        XCTAssertNil(TaskMarker.toggle("# [ ] heading"))
        XCTAssertNil(TaskMarker.toggle("some prose"))
        XCTAssertNil(TaskMarker.toggle(""))
    }

    // MARK: - State

    func testStateReportsCheckedness() {
        XCTAssertEqual(TaskMarker.state(of: "- [ ] a"), .unchecked)
        XCTAssertEqual(TaskMarker.state(of: "- [x] a"), .checked)
        XCTAssertEqual(TaskMarker.state(of: "- [X] a"), .checked)
        XCTAssertNil(TaskMarker.state(of: "- a"))
    }

    func testToggleIsItsOwnInverse() {
        for line in ["- [ ] a", "  * [x] b", "3. [ ] c"] {
            let once = TaskMarker.toggle(line)
            XCTAssertNotNil(once)
            XCTAssertEqual(TaskMarker.toggle(once!), line)
        }
    }
}
