import XCTest
@testable import termdown

/// Regression tests for `Terminal.frameSequence` — the escape stream `render`
/// writes. With autowrap disabled the cursor parks on the last column after a
/// full-width row, so the clears must be placed so they never erase a frame cell.
/// Getting this wrong dropped the right border under tmux (the search box lost its
/// `│`, the box lost its bottom-right corner) while iTerm2 stayed forgiving.
final class FrameSequenceTests: XCTestCase {

    private let bsu = "\u{1B}[?2026h"
    private let esu = "\u{1B}[?2026l"

    /// The frame body, with the synchronized-update wrapper peeled off, so the
    /// clear-placement assertions below read against the drawing bytes alone.
    private func body(_ seq: String) -> String {
        XCTAssertTrue(seq.hasPrefix(bsu), seq)
        XCTAssertTrue(seq.hasSuffix(esu), seq)
        return String(seq.dropFirst(bsu.count).dropLast(esu.count))
    }

    /// A frame that fills the screen must not emit `\e[J`: the cursor would be on
    /// the bottom-right cell and erase-below would wipe it (the border corner).
    /// Lines are cleared with `\e[2K` *before* their content, never `\e[K` after.
    func testFullHeightFrameKeepsLastCell() {
        let seq = body(Terminal.frameSequence(["AAA", "BBB", "CCC"], screenRows: 3))
        XCTAssertFalse(seq.contains("\u{1B}[J"), seq)            // no clear-below
        XCTAssertFalse(seq.contains("\u{1B}[K"), seq)            // no erase-to-EOL after content
        XCTAssertTrue(seq.hasSuffix("CCC"), seq)                 // last cell is the very tail
        XCTAssertEqual(seq.components(separatedBy: "\u{1B}[2K").count - 1, 3) // one per row
    }

    /// A frame shorter than the screen steps onto the first blank line, then erases
    /// downward — so stale rows from a taller previous frame are cleared without
    /// touching the frame itself.
    func testShorterFrameClearsBelow() {
        let seq = body(Terminal.frameSequence(["AAA", "BBB"], screenRows: 10))
        XCTAssertTrue(seq.hasSuffix("\r\n\u{1B}[J"), seq)
    }

    /// Cursor is homed and the first line cleared before any content is drawn.
    func testHomesAndClearsFirstLine() {
        let seq = body(Terminal.frameSequence(["X"], screenRows: 1))
        XCTAssertTrue(seq.hasPrefix("\u{1B}[H\u{1B}[2K"), seq)
        XCTAssertFalse(seq.contains("\u{1B}[J"), seq)
    }

    /// Every frame is presented atomically. A frame is ~12 KB at a typical
    /// terminal size, so without the wrapper the terminal paints the part it has
    /// read — the `\e[2K` before each row shows as a blank while the content is
    /// still arriving, which is the flicker, and a fast scroll made it flashing.
    func testFrameIsWrappedInSynchronizedUpdate() {
        let seq = Terminal.frameSequence(["AAA", "BBB"], screenRows: 10)
        XCTAssertTrue(seq.hasPrefix(bsu), "frame must open a synchronized update")
        XCTAssertTrue(seq.hasSuffix(esu), "frame must close it, or the display stays frozen")
        // Exactly one begin and one end — a nested or repeated pair would leave
        // the terminal's update depth unbalanced.
        XCTAssertEqual(seq.components(separatedBy: bsu).count - 1, 1)
        XCTAssertEqual(seq.components(separatedBy: esu).count - 1, 1)
        // The home must sit *inside* the update, or the cursor jump is visible.
        XCTAssertTrue(seq.hasPrefix(bsu + "\u{1B}[H"), seq)
    }
}
