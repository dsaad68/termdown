import Foundation
import termdownCore

// Painting for the modal overlays declared in `Terminal+Overlay.swift`: the
// bordered list box and its tabbed variant.
//
// Split out of that file, which sits on the 400-line lint ceiling — the same
// reason `Ansi+Palette.swift` and `ConfigLoader+Write.swift` exist.

extension Terminal {

    /// cutting one: `Esc clo…` is noise, one hint fewer is not. The position
    /// counter goes first — it is the only part that is not a key binding — and
    /// hints are dropped from the right, so the least useful goes next.
    ///
    /// `scrollNote` is appended to the hint but is not counted when `innerW` is
    /// computed, so it could push the row past the border at any width.
    private static func fittedOverlayHint(_ hint: String, scrollNote: String, width: Int) -> String {
        if Ansi.width(hint + scrollNote) <= width { return hint + scrollNote }
        return Ansi.fittedHint(hint.components(separatedBy: " \u{00B7} "),
                               separator: " \u{00B7} ", width: width)
    }

    static func paintBox(title: String, items: [String], selectable: Bool, hint: String,
                         selected: Int, scroll: Int, listH: Int, innerW: Int,
                         startRow: Int, startCol: Int, boxW: Int, boxH: Int) {
        let P = Ansi.Pastel.self
        let border = P.borderDim
        let v = Ansi.color("│", border)
        let shadowChar = Ansi.wrap(" ", Ansi.bg(P.shadow))
        var buf = ""
        func put(_ row: Int, _ col: Int, _ s: String) { buf += "\u{1B}[\(row);\(col)H" + s }

        // ── Top border with pastel title bar ──
        // Only the dashes used to be clamped, so a title wider than the box
        // pushed the closing corner off the screen — and `innerW` is capped at
        // `cols - 4`, which actively creates that case on a narrow terminal.
        let titleText = Ansi.width(" \(title) ") <= max(0, boxW - 3)
            ? " \(title) "
            : Ansi.fit(" \(title) ", to: max(0, boxW - 3))
        let titleW = Ansi.width(titleText)
        let dashes = max(0, boxW - 2 - titleW)
        let leftDash = 1
        let rightDash = max(0, dashes - leftDash)
        let titleBar = Ansi.color("╭" + String(repeating: "─", count: leftDash), border)
                     + Ansi.fgBg(titleText, fg: P.headerFg, bg: P.headerBg)
                     + Ansi.color(String(repeating: "─", count: rightDash) + "╮", border)
        put(startRow, startCol, titleBar)

        // ── Item rows ──
        for i in 0..<listH {
            let idx = scroll + i
            let row = startRow + 1 + i
            if idx < items.count {
                let text = Ansi.pad(Ansi.truncate(items[idx], to: innerW), to: innerW)
                let inner = " " + text + " "
                let body: String
                if selectable && idx == selected {
                    body = Ansi.fgBg(inner, fg: P.selectFg, bg: P.selectBg)
                } else {
                    body = inner
                }
                put(row, startCol, v + body + v + shadowChar)
            } else {
                put(row, startCol, v + String(repeating: " ", count: innerW + 2) + v + shadowChar)
            }
        }

        // ── Hint row ──
        if !hint.isEmpty {
            let scrollNote = items.count > listH ? "  \(selected + 1)/\(items.count)" : ""
            // `scrollNote` is not counted when `innerW` is computed, so this
            // overflowed even at wide widths whenever the hint was the widest
            // element. The position counter is the first thing to give.
            let hintText = Ansi.pad(fittedOverlayHint(hint, scrollNote: scrollNote, width: innerW),
                                    to: innerW)
            let hintRow = startRow + 1 + listH
            put(hintRow, startCol, v + " " + Ansi.dim(hintText) + " " + v + shadowChar)
        }

        // ── Bottom border ──
        put(startRow + boxH - 1, startCol,
            Ansi.color("╰" + String(repeating: "─", count: boxW - 2) + "╯", border) + shadowChar)

        // ── Bottom shadow line ──
        let shadowRow = startRow + boxH
        put(shadowRow, startCol + 1, String(repeating: shadowChar, count: boxW))

        write(buf)
    }

    /// Show grouped help in a read-only tabbed overlay: panes switch with
    /// Tab/→/t (Shift-Tab/← back), ↑↓ scroll a long pane, Esc/q/Enter close.

    static func paintTabbedBox(panes: [(name: String, items: [String])], activePane: Int,
                               hint: String, selected: Int, scroll: Int, listH: Int,
                               innerW: Int, startRow: Int, startCol: Int, boxW: Int, boxH: Int,
                               selectable: Bool = true) {
        let P = Ansi.Pastel.self
        let border = P.borderDim
        let v = Ansi.color("│", border)
        let shadowChar = Ansi.wrap(" ", Ansi.bg(P.shadow))
        let items = panes[activePane].items
        var buf = ""
        func put(_ row: Int, _ col: Int, _ s: String) { buf += "\u{1B}[\(row);\(col)H" + s }

        // ── Top border with the panes drawn as tabs ──
        // `chipsW` was accumulated but only ever used to clamp the *dashes* —
        // the chips themselves were emitted whole, so a wide tab strip ran past
        // the closing corner.
        //
        // Whole tabs are dropped rather than cut (a half-drawn tab name reads as
        // corruption), and the survivors are a *contiguous window* around the
        // active pane. Two earlier attempts were worse than the overflow: taking
        // panes in order and skipping the ones that did not fit produced a strip
        // with holes in it, so a pane you could still Tab to had no chip at all;
        // and clamping the assembled strip afterwards cut from the right, which
        // deleted the active tab whenever it was not near the front.
        let chipRoom = max(0, boxW - 3)
        let labels = panes.map { " \($0.name) " }
        var first = activePane
        var last = activePane
        var used = Ansi.width(labels[activePane])
        // Grow outwards from the active pane, preferring the pane on the left so
        // the strip reads in order.
        while true {
            var grew = false
            if first > 0, used + 1 + Ansi.width(labels[first - 1]) <= chipRoom {
                used += 1 + Ansi.width(labels[first - 1]); first -= 1; grew = true
            }
            if last < panes.count - 1, used + 1 + Ansi.width(labels[last + 1]) <= chipRoom {
                used += 1 + Ansi.width(labels[last + 1]); last += 1; grew = true
            }
            if !grew { break }
        }
        // Mark panes that exist but are off the strip, so their absence reads as
        // "there is more" rather than "there is nothing".
        let more = Ansi.color("\u{2026}", border)
        var chips = first > 0 ? more : ""
        var chipsW = first > 0 ? 1 : 0
        for i in first...last {
            if i > first { chips += Ansi.color("\u{00B7}", border); chipsW += 1 }
            chipsW += Ansi.width(labels[i])
            if i == activePane {
                chips += Ansi.wrap(labels[i], [1] + Ansi.fg(P.headerFg) + Ansi.bg(P.headerBg))
            } else {
                chips += Ansi.color(labels[i], P.textDim)
            }
        }
        if last < panes.count - 1 { chips += more; chipsW += 1 }
        // The active tab alone can still exceed the room on an absurdly narrow
        // terminal; cut *that* rather than let the corner escape.
        if chipsW > chipRoom {
            chips = Ansi.fit(chips, to: chipRoom)
            chipsW = chipRoom
        }
        let dashes = max(0, boxW - 2 - chipsW)
        let rightDash = max(0, dashes - 1)
        let titleBar = Ansi.color("╭─", border) + chips
                     + Ansi.color(String(repeating: "─", count: rightDash) + "╮", border)
        put(startRow, startCol, titleBar)

        // ── Item rows (active pane) ──
        for i in 0..<listH {
            let idx = scroll + i
            let row = startRow + 1 + i
            if idx < items.count {
                let text = Ansi.pad(Ansi.truncate(items[idx], to: innerW), to: innerW)
                let inner = " " + text + " "
                let body = (selectable && idx == selected) ? Ansi.fgBg(inner, fg: P.selectFg, bg: P.selectBg) : inner
                put(row, startCol, v + body + v + shadowChar)
            } else if items.isEmpty && i == 0 {
                let text = Ansi.pad(Ansi.truncate("  (nothing here)", to: innerW), to: innerW)
                put(row, startCol, v + " " + Ansi.dim(text) + " " + v + shadowChar)
            } else {
                put(row, startCol, v + String(repeating: " ", count: innerW + 2) + v + shadowChar)
            }
        }

        // ── Hint row ──
        if !hint.isEmpty {
            let scrollNote = items.count > listH ? "  \(selected + 1)/\(items.count)" : ""
            // `scrollNote` is not counted when `innerW` is computed, so this
            // overflowed even at wide widths whenever the hint was the widest
            // element. The position counter is the first thing to give.
            let hintText = Ansi.pad(fittedOverlayHint(hint, scrollNote: scrollNote, width: innerW),
                                    to: innerW)
            let hintRow = startRow + 1 + listH
            put(hintRow, startCol, v + " " + Ansi.dim(hintText) + " " + v + shadowChar)
        }

        // ── Bottom border + shadow ──
        put(startRow + boxH - 1, startCol,
            Ansi.color("╰" + String(repeating: "─", count: boxW - 2) + "╯", border) + shadowChar)
        put(startRow + boxH, startCol + 1, String(repeating: shadowChar, count: boxW))
        write(buf)
    }
}
