import XCTest
@testable import termdown

/// Regression tests for `Terminal.frameSequence` — the escape stream `render`
/// writes. With autowrap disabled the cursor parks on the last column after a
/// full-width row, so the clears must be placed so they never erase a frame cell.
/// Getting this wrong dropped the right border under tmux (the search box lost its
/// `│`, the box lost its bottom-right corner) while iTerm2 stayed forgiving.
final class FrameSequenceTests: XCTestCase {

    /// A frame that fills the screen must not emit `\e[J`: the cursor would be on
    /// the bottom-right cell and erase-below would wipe it (the border corner).
    /// Lines are cleared with `\e[2K` *before* their content, never `\e[K` after.
    func testFullHeightFrameKeepsLastCell() {
        let seq = Terminal.frameSequence(["AAA", "BBB", "CCC"], screenRows: 3)
        XCTAssertFalse(seq.contains("\u{1B}[J"), seq)            // no clear-below
        XCTAssertFalse(seq.contains("\u{1B}[K"), seq)            // no erase-to-EOL after content
        XCTAssertTrue(seq.hasSuffix("CCC"), seq)                 // last cell is the very tail
        XCTAssertEqual(seq.components(separatedBy: "\u{1B}[2K").count - 1, 3) // one per row
    }

    /// A frame shorter than the screen steps onto the first blank line, then erases
    /// downward — so stale rows from a taller previous frame are cleared without
    /// touching the frame itself.
    func testShorterFrameClearsBelow() {
        let seq = Terminal.frameSequence(["AAA", "BBB"], screenRows: 10)
        XCTAssertTrue(seq.hasSuffix("\r\n\u{1B}[J"), seq)
    }

    /// Cursor is homed and the first line cleared before any content is drawn.
    func testHomesAndClearsFirstLine() {
        let seq = Terminal.frameSequence(["X"], screenRows: 1)
        XCTAssertTrue(seq.hasPrefix("\u{1B}[H\u{1B}[2K"), seq)
        XCTAssertFalse(seq.contains("\u{1B}[J"), seq)
    }
}
