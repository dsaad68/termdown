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

    /// Screen columns occupied by chrome to the left of the document text.
    var chromeLeft: Int { sidebarActive ? (Pager.sidebarWidth + 2) : Pager.leftMargin }

    /// Map 1-based screen coordinates to a document point. Returns nil for
    /// anything that is not document text — rows outside the viewport (the
    /// status bar) and columns inside the left chrome (the outline sidebar or
    /// the margin), matching the guards `handleClick` already applies.
    func selectionPoint(x: Int, y: Int) -> TextPoint? {
        let row = y - 1
        guard row >= 0, row < contentRows else { return nil }
        let col = (x - 1) - chromeLeft + hscroll
        guard col >= 0 else { return nil }
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
            guard mouseSelectEnabled else { break }
            // Coalesce: `?1002h` emits an event per cell crossed and `readByte`
            // costs a poll+read syscall per byte, so a fast drag queues far more
            // motion than the eye needs — and every one repaints a full frame.
            // Keep only the newest, and hand back whatever ended the drain.
            var (lastX, lastY) = (x, y)
            while let next = Terminal.readKey(timeoutMs: 0) {
                if case .mouseDrag(let nx, let ny) = next {
                    (lastX, lastY) = (nx, ny)
                } else {
                    Terminal.pushBack(next)
                    break
                }
            }
            extendDrag(x: lastX, y: lastY)
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

    // MARK: - Multi-click word / line selection

    /// The display-column span of the word under `col` on `line`, or nil when
    /// that cell is whitespace or out of range.
    ///
    /// Walks characters accumulating `Ansi.charWidth`, so it stays in step with
    /// the tint and the copy, both of which address cells rather than indices.
    func wordRange(line: Int, col: Int) -> Range<Int>? {
        guard line >= 0, line < plainLines.count else { return nil }
        let text = plainLines[line]
        let isWord: (Character) -> Bool = { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        var spans: [(Range<Int>, Bool)] = []   // (columns, isWordChar)
        var c = 0
        for ch in text {
            let w = Ansi.charWidth(ch)
            spans.append((c..<(c + w), isWord(ch)))
            c += w
        }
        guard let hit = spans.firstIndex(where: { $0.0.contains(col) }), spans[hit].1 else { return nil }
        var lo = hit
        while lo > 0, spans[lo - 1].1 { lo -= 1 }
        var hi = hit
        while hi + 1 < spans.count, spans[hi + 1].1 { hi += 1 }
        return spans[lo].0.lowerBound..<spans[hi].0.upperBound
    }

    /// Register a press for click-counting. Returns how many clicks this is
    /// (1, 2 or 3) — a second or third press lands within `multiClickInterval`
    /// on the same cell, and the count wraps back to 1 after a triple.
    mutating func registerClick(at p: TextPoint, now: Date = Date()) -> Int {
        let withinTime = now.timeIntervalSince(lastClickAt) < Pager.multiClickInterval
        if withinTime, lastClickPoint == p, clickCount < 3 {
            clickCount += 1
        } else {
            clickCount = 1
        }
        lastClickAt = now
        lastClickPoint = p
        return clickCount
    }

    /// Select the word under the pointer (double click).
    mutating func selectWord(at p: TextPoint) {
        guard let r = wordRange(line: p.line, col: p.col) else { return }
        textSelection = TextSelection(anchor: TextPoint(line: p.line, col: r.lowerBound),
                                      head: TextPoint(line: p.line, col: r.upperBound))
    }

    /// Select the whole display line (triple click).
    mutating func selectLine(at p: TextPoint) {
        guard p.line >= 0, p.line < plainLines.count else { return }
        textSelection = TextSelection(anchor: TextPoint(line: p.line, col: 0),
                                      head: TextPoint(line: p.line, col: Ansi.width(plainLines[p.line])))
    }

    // MARK: - Autoscroll while the pointer is held past an edge

    /// Terminals only report motion when the pointer *moves*, so holding still
    /// past the viewport edge would stop scrolling. The event loop's idle tick
    /// keeps it going.
    mutating func tickAutoScroll() {
        guard let anchor = dragAnchor, autoScrollDir != 0, let head = lastDragPoint else { return }
        let before = top
        top = max(0, min(maxTop, top + autoScrollDir))
        guard top != before else { return }
        // The pointer is pinned to one screen row, so the document row under it
        // advances with `top`. Feed the new head back into `lastDragPoint`: the
        // row is derived from it, so leaving it at the last *reported* position
        // makes the row shrink by exactly what `top` gained and the selection
        // stops growing after a tick while the document keeps scrolling.
        let row = min(max(0, head.line - before), max(0, contentRows - 1))
        let moved = TextPoint(line: top + row, col: head.col)
        lastDragPoint = moved
        textSelection = TextSelection(anchor: anchor, head: moved)
        needsRedraw = true
    }

    // MARK: - Drag state machine

    /// Left-button press: anchor a selection. The link under the pointer is *not*
    /// opened here — that waits for a release without motion, so a drag that
    /// happens to start on a link selects text instead of navigating away.
    mutating func beginDrag(x: Int, y: Int) {
        guard let p = selectionPoint(x: x, y: y) else {
            // The press landed on the status bar or in the sidebar, so no drag
            // starts here. Drop any state a previous drag left behind, or the
            // release would still see `dragMoved`/`textSelection` set and copy
            // that stale selection over the clipboard a second time.
            clearTextSelection()
            return
        }
        dragAnchor = p
        dragMoved = false
        textSelection = nil
        autoScrollDir = 0
        lastDragPoint = p
        // A repeat press on the same cell escalates to word then line. The
        // selection is set now rather than on release so it is visible while the
        // button is still down, as in a GUI.
        switch registerClick(at: p) {
        case 2: selectWord(at: p); dragMoved = true; takeSelectionOwnership()
        case 3: selectLine(at: p); dragMoved = true; takeSelectionOwnership()
        default: break
        }
    }

    /// Hand the one live selection over to the mouse. The keyboard's full-row
    /// matte and a character tint on the same rows read as one confused
    /// highlight, so only one may be lit — but this waits until a character
    /// selection actually exists. Doing it on the bare press threw away a line
    /// selection the user had built with `v`/`Shift+J` on every stray click,
    /// including the clicks that only mean "follow this link".
    private mutating func takeSelectionOwnership() {
        guard cursorVisible || selectionAnchor != nil else { return }
        cursorVisible = false
        clearSelection()
    }

    /// Motion with the button held: extend the selection, auto-scrolling when the
    /// pointer leaves the viewport so a drag can run past the visible region.
    mutating func extendDrag(x: Int, y: Int) {
        guard let anchor = dragAnchor else { return }
        // Remember which edge the pointer is past so the idle tick can keep
        // scrolling while it is held still — no further motion will be reported.
        //
        // Terminals clamp the pointer to the window and report 1-based rows, so
        // dragging above the viewport arrives as row 0 and never as a negative
        // one: the topmost content row has to serve as the up-edge. Require the
        // drag to have come from below it, so selecting rightward along the
        // first visible row does not scroll the document out from under it.
        let row = y - 1
        if row <= 0, anchor.line > top {
            autoScrollDir = -1
            top = max(0, top - 1)
        } else if row >= contentRows {
            autoScrollDir = 1
            top = min(maxTop, top + 1)
        } else {
            autoScrollDir = 0
        }
        // Clamp back into the content area rather than letting `selectionPoint`
        // reject the point: a drag that wanders into the margin or past an edge
        // should keep extending from the nearest cell, not freeze.
        let clampedY = min(max(y, 1), contentRows)
        let clampedX = max(x, chromeLeft + 1)
        guard let p = selectionPoint(x: clampedX, y: clampedY) else { return }
        dragMoved = true
        lastDragPoint = p
        textSelection = TextSelection(anchor: anchor, head: p)
        takeSelectionOwnership()
    }

    /// Left-button release: a drag copies its text, a stationary click falls back
    /// to the existing click behavior (follow a link).
    mutating func endDrag(x: Int, y: Int) {
        // A release with no anchor never had a press inside the document — it
        // began on the status bar or in the sidebar. It is not this pager's
        // gesture, so it must neither open a link nor re-copy anything.
        guard dragAnchor != nil else { return }
        defer { dragAnchor = nil; dragMoved = false; autoScrollDir = 0 }
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
    /// column. `clusterSlice` rather than `horizontalSlice`: an edge landing
    /// inside a wide glyph should copy that glyph, not the space the drawing
    /// path substitutes to keep a row's column count exact.
    func selectedText(_ sel: TextSelection) -> String {
        let (start, end) = sel.ordered
        guard start.line < plainLines.count else { return "" }
        let last = min(end.line, plainLines.count - 1)
        guard start.line <= last else { return "" }
        return (start.line...last).map { line -> String in
            let text = plainLines[line]
            guard let r = sel.columnRange(forLine: line, width: Ansi.width(text)) else { return "" }
            let slice = Ansi.clusterSlice(text, start: r.lowerBound, width: r.count)
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
