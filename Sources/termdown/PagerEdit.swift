import Foundation
import termdownCore

extension Pager {

    // MARK: - Inline block editing
    //
    // `e` opens the block under the line cursor as an editable raw-markdown field
    // spliced into the rendered document; the rest stays rendered. Enter writes the
    // change back to the file (the existing live-reload re-renders); Esc cancels.

    /// Enter edit mode on the block under the cursor.
    mutating func beginEdit() {
        guard currentURL != nil else { flash("editing needs a file"); return }
        guard cursorLine < dispSourceSpans.count, let span = dispSourceSpans[cursorLine] else {
            flash("nothing to edit here"); return
        }
        let srcLines = rawSource.components(separatedBy: "\n")
        let start = span.start - 1
        let end = span.end - 1
        guard start >= 0, end < srcLines.count, start <= end else {
            flash("can't edit this line"); return
        }
        editFileSpan = span
        editBuffer = Array(srcLines[start...end])
        editCaretRow = 0
        editCaretCol = editBuffer.first?.count ?? 0
        let (ds, dc) = displayRange(forSpan: span)
        editDisplayStart = ds
        editDisplayCount = dc
        editMode = true
        cursorVisible = true   // stay in cursor mode at this block after the edit
        ensureSpanVisible(ds, dc)
        needsRedraw = true
    }

    /// Leave edit mode, discarding the buffer.
    mutating func cancelEdit() {
        editMode = false
        editFileSpan = nil
        editBuffer = []
        editCaretRow = 0; editCaretCol = 0
        editDisplayStart = 0; editDisplayCount = 0
        needsRedraw = true
    }

    /// Commit the edit into the in-memory source and mark the document dirty. The
    /// change is NOT written to disk here — that happens on Ctrl-S (see saveToDisk).
    mutating func saveEdit() {
        guard let span = editFileSpan else { cancelEdit(); return }
        rawSource = Pager.applyEdit(source: rawSource, span: span, newLines: editBuffer)
        isDirty = true
        pendingCursorSource = span.start // re-anchor the cursor after the reflow
        cancelEdit()
        currentRenderWidth = -1          // re-render from the in-memory source next loop
    }

    // MARK: - Field input

    mutating func handleEditMode(_ key: Terminal.Key) {
        switch key {
        case .escape:
            cancelEdit()
        case .enter:
            saveEdit()
        case .backspace:
            editBackspace()
        case .left:
            moveCaret(-1)
        case .right:
            moveCaret(1)
        case .up:
            if editCaretRow > 0 { editCaretRow -= 1; clampCaretCol() }
        case .down:
            if editCaretRow < editBuffer.count - 1 { editCaretRow += 1; clampCaretCol() }
        case .home:
            editCaretCol = 0
        case .end:
            editCaretCol = editBuffer[editCaretRow].count
        case .char(let c):
            insertChar(c)
        default:
            break
        }
        needsRedraw = true
    }

    private mutating func clampCaretCol() {
        editCaretCol = max(0, min(editCaretCol, editBuffer[editCaretRow].count))
    }

    private mutating func insertChar(_ c: Character) {
        guard c != "\n", c != "\r" else { return }   // adding hard line breaks is out of v1 scope
        var chars = Array(editBuffer[editCaretRow])
        let i = max(0, min(editCaretCol, chars.count))
        chars.insert(c, at: i)
        editBuffer[editCaretRow] = String(chars)
        editCaretCol = i + 1
    }

    private mutating func editBackspace() {
        if editCaretCol > 0 {
            var chars = Array(editBuffer[editCaretRow])
            chars.remove(at: editCaretCol - 1)
            editBuffer[editCaretRow] = String(chars)
            editCaretCol -= 1
        } else if editCaretRow > 0 {
            let prev = editBuffer[editCaretRow - 1]
            editCaretCol = prev.count
            editBuffer[editCaretRow - 1] = prev + editBuffer[editCaretRow]
            editBuffer.remove(at: editCaretRow)
            editCaretRow -= 1
        }
    }

    private mutating func moveCaret(_ delta: Int) {
        if delta < 0 {
            if editCaretCol > 0 { editCaretCol -= 1 }
            else if editCaretRow > 0 { editCaretRow -= 1; editCaretCol = editBuffer[editCaretRow].count }
        } else {
            if editCaretCol < editBuffer[editCaretRow].count { editCaretCol += 1 }
            else if editCaretRow < editBuffer.count - 1 { editCaretRow += 1; editCaretCol = 0 }
        }
    }

    // MARK: - Helpers

    /// Replace the file lines covered by `span` with `newLines`.
    static func applyEdit(source: String, span: SourceSpan, newLines: [String]) -> String {
        var lines = source.components(separatedBy: "\n")
        let start = span.start - 1
        guard start >= 0, start < lines.count else { return source }
        let end = min(span.end - 1, lines.count - 1)
        guard end >= start else { return source }
        lines.replaceSubrange(start...end, with: newLines)
        return lines.joined(separator: "\n")
    }

    /// The contiguous run of display rows around the cursor that share `span`.
    func displayRange(forSpan span: SourceSpan) -> (start: Int, count: Int) {
        var lo = cursorLine
        while lo > 0, dispSourceSpans[lo - 1] == span { lo -= 1 }
        var hi = cursorLine
        while hi + 1 < dispSourceSpans.count, dispSourceSpans[hi + 1] == span { hi += 1 }
        return (lo, hi - lo + 1)
    }

    /// Scroll so the display rows `[start, start+count)` are visible.
    mutating func ensureSpanVisible(_ start: Int, _ count: Int) {
        let viewport = max(1, contentRows)
        let maxTopLocal = max(0, lines.count - viewport)
        if start < top { top = max(0, min(start, maxTopLocal)) }
        let last = start + count - 1
        if last > top + viewport - 1 { top = max(0, min(last - viewport + 1, maxTopLocal)) }
    }

    /// After a save-triggered reflow, move the cursor back onto the edited block.
    mutating func applyPendingCursor() {
        guard let srcLine = pendingCursorSource else { return }
        pendingCursorSource = nil
        if let d = dispSourceSpans.firstIndex(where: { span in
            guard let s = span else { return false }
            return s.start <= srcLine && srcLine <= s.end
        }) {
            setCursor(d)
        }
    }

    /// Show a transient status hint (reuses the copy-toast slot).
    mutating func flash(_ msg: String) {
        copyFlashMsg = msg
        copyFlashUntil = Date().addingTimeInterval(1.5)
        needsRedraw = true
    }

    // MARK: - Edit-field rendering

    /// The display lines to render while editing: the document with the edited
    /// block's rows replaced by the editable raw-markdown field.
    func editFrameLines() -> [String] {
        let ds = max(0, min(editDisplayStart, lines.count))
        let de = max(ds, min(editDisplayStart + editDisplayCount, lines.count))
        let field = editBuffer.enumerated().map { editLineDisplay($1, isCaretRow: $0 == editCaretRow) }
        return Array(lines[0..<ds]) + field + Array(lines[de...])
    }

    /// Style one raw editor line, drawing a reverse-video block caret on the
    /// active row.
    private func editLineDisplay(_ raw: String, isCaretRow: Bool) -> String {
        let P = Ansi.Pastel.self
        guard isCaretRow else { return Ansi.color(raw.isEmpty ? " " : raw, P.headerFg) }
        let chars = Array(raw)
        let i = max(0, min(editCaretCol, chars.count))
        let before = String(chars[0..<i])
        let caret = i < chars.count ? String(chars[i]) : " "
        let after = i < chars.count ? String(chars[(i + 1)...]) : ""
        return Ansi.color(before, P.headerFg) + Ansi.wrap(caret, [7]) + Ansi.color(after, P.headerFg)
    }
}
