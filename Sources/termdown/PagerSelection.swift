import Foundation
import termdownCore

/// A point in the rendered document: a display-row index plus a display column
/// in *content* coordinates (horizontal scroll already folded in, matching what
/// `handleClick` computes).
struct TextPoint: Equatable {
    var line: Int
    var col: Int
}

/// A character-precise selection running from `anchor` (where the drag started)
/// to `head` (where the pointer is now). Kept separate from the keyboard's
/// line-granular `selectionAnchor` so the two never interfere.
struct TextSelection: Equatable {
    var anchor: TextPoint
    var head: TextPoint

    /// Ordered (start, end) regardless of which way the drag went.
    var ordered: (start: TextPoint, end: TextPoint) {
        if anchor.line != head.line {
            return anchor.line < head.line ? (anchor, head) : (head, anchor)
        }
        return anchor.col <= head.col ? (anchor, head) : (head, anchor)
    }

    /// True when the drag never covered a cell (press and release in one spot).
    var isEmpty: Bool { anchor == head }

    /// The content-column range to tint on `line`, or nil when the line falls
    /// outside the selection. Text-flow shaped: the first row runs to the right
    /// edge, interior rows are full width, the last row stops at the head column.
    func columnRange(forLine line: Int, width: Int) -> Range<Int>? {
        let (start, end) = ordered
        guard line >= start.line, line <= end.line else { return nil }
        let lo = line == start.line ? start.col : 0
        let hi = line == end.line ? end.col : width
        guard lo < hi else { return nil }
        return lo..<hi
    }
}

extension Pager {

    // MARK: - Screen ↔ document mapping

    /// Map 1-based screen coordinates to a document point, clamping into the
    /// content area. Returns nil for rows outside the viewport (status bar).
    func selectionPoint(x: Int, y: Int) -> TextPoint? {
        let row = y - 1
        guard row >= 0, row < contentRows else { return nil }
        let chromeLeft = sidebarActive ? (Pager.sidebarWidth + 2) : Pager.leftMargin
        let col = max(0, (x - 1) - chromeLeft + hscroll)
        return TextPoint(line: top + row, col: col)
    }

    // MARK: - Input dispatch

    /// Route a left-button event. With `mouse-select` off this is exactly the
    /// old behavior — a press follows the link under it and the rest is ignored.
    mutating func handleMouseButton(_ key: Terminal.Key) {
        switch key {
        case .mouseClick(let x, let y):
            // With drag-select on a press only anchors; the link under it opens
            // on release, and only if the pointer never moved.
            if mouseSelectEnabled { beginDrag(x: x, y: y) } else { handleClick(x: x, y: y) }
        case .mouseDrag(let x, let y):
            if mouseSelectEnabled { extendDrag(x: x, y: y) }
        case .mouseRelease(let x, let y):
            if mouseSelectEnabled { endDrag(x: x, y: y) }
        default:
            break
        }
    }

    /// A real keypress drops a character selection — except `y`/`Y`, which
    /// re-copy it, and the mouse events that maintain it. Scrolling keeps it too:
    /// the selection is anchored to display rows, so it moves with the content.
    mutating func dropTextSelection(unless key: Terminal.Key) {
        switch key {
        case .mouseScroll, .mouseClick, .mouseDrag, .mouseRelease, .char("y"), .char("Y"):
            break
        default:
            clearTextSelection()
        }
    }

    // MARK: - Drag state machine

    /// Left-button press: anchor a selection. The link under the pointer is *not*
    /// opened here — that waits for a release without motion, so a drag that
    /// happens to start on a link selects text instead of navigating away.
    mutating func beginDrag(x: Int, y: Int) {
        guard let p = selectionPoint(x: x, y: y) else { return }
        dragAnchor = p
        dragMoved = false
        textSelection = nil
        // The keyboard's full-row matte and a character tint on the same rows
        // read as one confused highlight — only one selection is live at a time.
        cursorVisible = false
        clearSelection()
    }

    /// Motion with the button held: extend the selection, auto-scrolling when the
    /// pointer leaves the viewport so a drag can run past the visible region.
    mutating func extendDrag(x: Int, y: Int) {
        guard let anchor = dragAnchor else { return }
        if y - 1 < 0 { top = max(0, top - 1) }
        else if y - 1 >= contentRows { top = min(maxTop, top + 1) }
        let clampedY = min(max(y, 1), contentRows)
        guard let p = selectionPoint(x: x, y: clampedY) else { return }
        dragMoved = true
        textSelection = TextSelection(anchor: anchor, head: p)
    }

    /// Left-button release: a drag copies its text, a stationary click falls back
    /// to the existing click behavior (follow a link).
    mutating func endDrag(x: Int, y: Int) {
        defer { dragAnchor = nil }
        guard dragMoved, let sel = textSelection, !sel.isEmpty else {
            textSelection = nil
            handleClick(x: x, y: y)
            return
        }
        copyTextSelection(sel)
    }

    /// Drop a character selection (any keypress clears it).
    mutating func clearTextSelection() {
        guard textSelection != nil || dragAnchor != nil else { return }
        textSelection = nil
        dragAnchor = nil
        dragMoved = false
        needsRedraw = true
    }

    // MARK: - Copy

    /// The selected text, sliced out of the ANSI-stripped `plainLines` by display
    /// column. `horizontalSlice` on plain text is exactly a column slice, so no
    /// separate column→index helper is needed.
    func selectedText(_ sel: TextSelection) -> String {
        let (start, end) = sel.ordered
        guard start.line < plainLines.count else { return "" }
        let last = min(end.line, plainLines.count - 1)
        guard start.line <= last else { return "" }
        return (start.line...last).map { line -> String in
            let text = plainLines[line]
            guard let r = sel.columnRange(forLine: line, width: Ansi.width(text)) else { return "" }
            let slice = Ansi.horizontalSlice(text, start: r.lowerBound, width: r.count)
            return String(slice.reversed().drop(while: { $0 == " " }).reversed())
        }.joined(separator: "\n")
    }

    /// Copy a character selection and confirm it in the status bar. The highlight
    /// stays lit afterwards as visual confirmation of what was taken.
    mutating func copyTextSelection(_ sel: TextSelection) {
        let text = selectedText(sel)
        guard !text.isEmpty else { flash("nothing to copy"); return }
        Terminal.copyToClipboard(text)
        let n = text.count
        flash("copied \(n) char\(n == 1 ? "" : "s")")
    }
}
