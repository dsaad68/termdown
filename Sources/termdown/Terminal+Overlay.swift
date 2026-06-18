import termdownCore

extension Terminal {

    // MARK: - Modal overlays

    /// Draw a centered, bordered modal box over the current screen contents.
    ///
    /// When `selectable` is true the user can move a highlighted selection and
    /// press Enter to choose an item (returns its index); Esc/q returns nil.
    /// When false it is an informational box dismissed by any key (returns nil).
    /// The caller is responsible for repainting the underlying screen afterward.
    @discardableResult
    static func showOverlay(title: String, items: [String], selectable: Bool, hint: String) -> Int? {
        var selected = 0
        var scroll = 0
        // Seed with the current size so the box is drawn *over* the existing
        // screen on first paint; only an actual resize forces a wipe.
        let initial = Terminal.size()
        var lastRows = initial.rows
        var lastCols = initial.cols
        var needsRedraw = true

        while true {
            let size = Terminal.size()
            if size.rows != lastRows || size.cols != lastCols {
                // Geometry changed: wipe so a smaller box leaves no stragglers.
                clearScreen()
                lastRows = size.rows
                lastCols = size.cols
                Terminal.didResize = false
                needsRedraw = true
            }

            let hintLines = hint.isEmpty ? 0 : 1
            let maxBoxH = max(5, size.rows - 4)
            let listH = max(1, min(items.count, maxBoxH - 2 - hintLines))
            let boxH = listH + 2 + hintLines
            let widest = items.map { Ansi.width($0) }.max() ?? 0
            let innerW = max(1, min(max(widest, Ansi.width(title) + 2, Ansi.width(hint)), size.cols - 4))
            let boxW = innerW + 4
            let startRow = max(1, (size.rows - boxH) / 2 + 1)
            let startCol = max(1, (size.cols - boxW) / 2 + 1)

            if selected < scroll { scroll = selected }
            if selected >= scroll + listH { scroll = selected - listH + 1 }
            scroll = max(0, min(scroll, max(0, items.count - listH)))

            if needsRedraw {
                paintBox(title: title, items: items, selectable: selectable, hint: hint,
                         selected: selected, scroll: scroll, listH: listH, innerW: innerW,
                         startRow: startRow, startCol: startCol, boxW: boxW, boxH: boxH)
                needsRedraw = false
            }

            guard let key = readKey(timeoutMs: 200) else { continue }
            needsRedraw = true // a handled key may move the selection
            switch key {
            case .up, .char("k"):
                if selectable { selected = max(0, selected - 1) }
            case .down, .char("j"):
                if selectable { selected = min(items.count - 1, selected + 1) }
            case .pageUp:
                if selectable { selected = max(0, selected - listH) }
            case .pageDown:
                if selectable { selected = min(items.count - 1, selected + listH) }
            case .home, .char("g"):
                if selectable { selected = 0 }
            case .end, .char("G"):
                if selectable { selected = items.count - 1 }
            case .enter:
                return selectable ? selected : nil
            case .escape, .char("q"):
                return nil
            default:
                if !selectable { return nil } // any key dismisses an info box
            }
        }
    }

    /// Draw a selectable list box centered over the current screen, without
    /// running an input loop — the caller manages the background and keys. Used
    /// for live-preview pickers (e.g. the theme selector) that repaint their own
    /// content behind the box on every selection change.
    static func paintList(title: String, items: [String], selected: Int, hint: String) {
        let size = Terminal.size()
        let hintLines = hint.isEmpty ? 0 : 1
        let maxBoxH = max(5, size.rows - 4)
        let listH = max(1, min(items.count, maxBoxH - 2 - hintLines))
        let boxH = listH + 2 + hintLines
        let widest = items.map { Ansi.width($0) }.max() ?? 0
        let innerW = max(1, min(max(widest, Ansi.width(title) + 2, Ansi.width(hint)), size.cols - 4))
        let boxW = innerW + 4
        let startRow = max(1, (size.rows - boxH) / 2 + 1)
        let startCol = max(1, (size.cols - boxW) / 2 + 1)
        var scroll = 0
        if selected >= listH { scroll = min(selected - listH + 1, max(0, items.count - listH)) }
        paintBox(title: title, items: items, selectable: true, hint: hint,
                 selected: selected, scroll: scroll, listH: listH, innerW: innerW,
                 startRow: startRow, startCol: startCol, boxW: boxW, boxH: boxH)
    }

    private static func paintBox(title: String, items: [String], selectable: Bool, hint: String,
                                 selected: Int, scroll: Int, listH: Int, innerW: Int,
                                 startRow: Int, startCol: Int, boxW: Int, boxH: Int) {
        let P = Ansi.Pastel.self
        let border = P.borderDim
        let v = Ansi.color("│", border)
        let shadowChar = Ansi.wrap(" ", Ansi.bg(P.shadow))
        var buf = ""
        func put(_ row: Int, _ col: Int, _ s: String) { buf += "\u{1B}[\(row);\(col)H" + s }

        // ── Top border with pastel title bar ──
        let titleText = " \(title) "
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
            let hintText = Ansi.pad(hint + scrollNote, to: innerW)
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
    static func showHelp(_ groups: [(name: String, items: [String])]) {
        _ = showTabbedOverlay(panes: groups, active: 0,
                              hint: "Tab/\u{2192} switch · \u{2191}\u{2193} scroll · Esc close",
                              selectable: false)
    }

    /// A box overlay whose title bar holds several selectable panes shown as
    /// tabs. `t` / Tab / →  cycle forward, Shift-Tab / ←  back; ↑↓ move, Enter
    /// selects, Esc/q cancels. Returns the chosen (pane, item), or nil. Opens on
    /// `active`, falling through to the first non-empty pane if that one is empty.
    static func showTabbedOverlay(panes: [(name: String, items: [String])],
                                  active: Int = 0, hint: String,
                                  selectable: Bool = true) -> (pane: Int, item: Int)? {
        guard !panes.isEmpty else { return nil }
        var activePane = max(0, min(active, panes.count - 1))
        if panes[activePane].items.isEmpty,
           let firstNonEmpty = panes.firstIndex(where: { !$0.items.isEmpty }) {
            activePane = firstNonEmpty
        }
        var selectedByPane = [Int](repeating: 0, count: panes.count)
        var scroll = 0
        let initial = Terminal.size()
        var lastRows = initial.rows
        var lastCols = initial.cols
        var needsRedraw = true

        while true {
            let size = Terminal.size()
            if size.rows != lastRows || size.cols != lastCols {
                clearScreen(); lastRows = size.rows; lastCols = size.cols
                Terminal.didResize = false; needsRedraw = true
            }

            let items = panes[activePane].items
            selectedByPane[activePane] = max(0, min(selectedByPane[activePane], max(0, items.count - 1)))
            let selected = selectedByPane[activePane]

            // Size the box for the *tallest/widest* pane so its footprint stays
            // constant as panes are cycled — a shrinking box would otherwise leave
            // straggler border rows (the overlay can't repaint the doc behind it).
            let hintLines = hint.isEmpty ? 0 : 1
            let maxBoxH = max(5, size.rows - 4)
            let maxItems = panes.map { $0.items.count }.max() ?? 0
            let listH = max(1, min(max(1, maxItems), maxBoxH - 2 - hintLines))
            let boxH = listH + 2 + hintLines
            let tabsW = panes.reduce(0) { $0 + Ansi.width($1.name) + 2 } + max(0, panes.count - 1)
            let widest = panes.flatMap { $0.items }.map { Ansi.width($0) }.max() ?? 0
            let innerW = max(1, min(max(max(widest, tabsW), Ansi.width(hint) + 6), size.cols - 4))
            let boxW = innerW + 4
            let startRow = max(1, (size.rows - boxH) / 2 + 1)
            let startCol = max(1, (size.cols - boxW) / 2 + 1)

            if selected < scroll { scroll = selected }
            if selected >= scroll + listH { scroll = selected - listH + 1 }
            scroll = max(0, min(scroll, max(0, items.count - listH)))

            if needsRedraw {
                paintTabbedBox(panes: panes, activePane: activePane, hint: hint,
                               selected: selected, scroll: scroll, listH: listH, innerW: innerW,
                               startRow: startRow, startCol: startCol, boxW: boxW, boxH: boxH,
                               selectable: selectable)
                needsRedraw = false
            }

            guard let key = readKey(timeoutMs: 200) else { continue }
            needsRedraw = true
            switch key {
            case .up, .char("k"):
                if !items.isEmpty { selectedByPane[activePane] = max(0, selected - 1) }
            case .down, .char("j"):
                if !items.isEmpty { selectedByPane[activePane] = min(items.count - 1, selected + 1) }
            case .pageUp:
                if !items.isEmpty { selectedByPane[activePane] = max(0, selected - listH) }
            case .pageDown:
                if !items.isEmpty { selectedByPane[activePane] = min(items.count - 1, selected + listH) }
            case .home, .char("g"):
                selectedByPane[activePane] = 0
            case .end, .char("G"):
                if !items.isEmpty { selectedByPane[activePane] = items.count - 1 }
            case .char("t"), .tab, .right, .char("l"):
                activePane = (activePane + 1) % panes.count; scroll = 0
            case .backTab, .left, .char("h"):
                activePane = (activePane - 1 + panes.count) % panes.count; scroll = 0
            case .enter:
                if selectable { if !items.isEmpty { return (activePane, selected) } }
                else { return nil }   // info mode: Enter just closes
            case .escape, .char("q"):
                return nil
            default:
                break
            }
        }
    }

    private static func paintTabbedBox(panes: [(name: String, items: [String])], activePane: Int,
                                       hint: String, selected: Int, scroll: Int, listH: Int, innerW: Int,
                                       startRow: Int, startCol: Int, boxW: Int, boxH: Int,
                                       selectable: Bool = true) {
        let P = Ansi.Pastel.self
        let border = P.borderDim
        let v = Ansi.color("│", border)
        let shadowChar = Ansi.wrap(" ", Ansi.bg(P.shadow))
        let items = panes[activePane].items
        var buf = ""
        func put(_ row: Int, _ col: Int, _ s: String) { buf += "\u{1B}[\(row);\(col)H" + s }

        // ── Top border with the panes drawn as tabs ──
        var chips = ""
        var chipsW = 0
        for (i, p) in panes.enumerated() {
            if i > 0 { chips += Ansi.color("·", border); chipsW += 1 }
            let label = " \(p.name) "
            chipsW += Ansi.width(label)
            if i == activePane {
                chips += Ansi.wrap(label, [1] + Ansi.fg(P.headerFg) + Ansi.bg(P.headerBg))
            } else {
                chips += Ansi.color(label, P.textDim)
            }
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
            let hintText = Ansi.pad(hint + scrollNote, to: innerW)
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
