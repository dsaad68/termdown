import Foundation
import termdownCore

extension Pager {

    // MARK: - Task list checkboxes
    //
    // `Space` in cursor mode flips the `- [ ]` under the cursor. It rides the
    // same buffer→dirty→Ctrl-S path as the inline editor (`e`): the toggle
    // rewrites `rawSource` in memory, marks the document unsaved (●), and leaves
    // the write to disk to Ctrl-S. Outside cursor mode, and on any line that
    // isn't a task item, Space keeps its page-down meaning.

    /// The 1-indexed source line of the task item under the cursor, if there is
    /// one.
    ///
    /// A rendered row carries the span of the *block* that produced it, so a
    /// wrapped task item's continuation rows share the first row's span and
    /// resolve to the same checkbox — the cursor doesn't have to sit on the
    /// marker row. A nested child item carries its own span, so it toggles
    /// itself rather than its parent.
    func taskSourceLine() -> Int? {
        guard cursorLine < dispSourceSpans.count, let span = dispSourceSpans[cursorLine] else { return nil }
        let srcLines = rawSource.components(separatedBy: "\n")
        let start = span.start - 1
        let end = min(span.end - 1, srcLines.count - 1)
        guard start >= 0, start <= end else { return nil }
        // Scan the span rather than assuming its first line: a loose list item
        // extends its range over the blank line that follows it.
        for i in start...end where TaskMarker.state(of: srcLines[i]) != nil {
            return i + 1
        }
        return nil
    }

    /// Flip the checkbox under the cursor, marking the document unsaved.
    ///
    /// Returns false when there's no task item under the cursor, which lets the
    /// caller fall back to Space's normal page-down.
    @discardableResult
    mutating func toggleTaskUnderCursor() -> Bool {
        guard currentURL != nil else { return false }
        guard let srcLine = taskSourceLine() else { return false }
        var srcLines = rawSource.components(separatedBy: "\n")
        guard let flipped = TaskMarker.toggle(srcLines[srcLine - 1]) else { return false }
        srcLines[srcLine - 1] = flipped
        rawSource = srcLines.joined(separator: "\n")
        isDirty = true
        pendingCursorSource = srcLine    // re-anchor the cursor after the reflow
        currentRenderWidth = -1          // re-render from the in-memory source next loop
        flash(TaskMarker.state(of: flipped) == .checked ? "done" : "todo")
        return true
    }
}
