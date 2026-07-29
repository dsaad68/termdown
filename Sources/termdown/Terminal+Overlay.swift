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
            // `- 5`, not `- 4`: the box is `innerW + 4` wide and each row also
            // draws a drop-shadow column, so a `cols - 4` cap made every row
            // `cols + 1` and clipped the right border off the screen.
            // `hint + 6` budgets the scroll counter appended at paint time —
            // without it the counter is dropped at *every* width.
            let innerW = max(1, min(max(widest, Ansi.width(title) + 2, Ansi.width(hint) + 6),
                                    size.cols - 5))
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
    /// Where a centred list box lands on screen. Returned rather than recomputed
    /// so drawing and hit-testing cannot drift apart — the geometry used to be
    /// locals inside `paintList`, which left a click handler no way to ask where
    /// a row actually is.
    struct ListBoxGeometry {
        var listH: Int
        var innerW: Int
        var boxW: Int
        var boxH: Int
        var startRow: Int
        var startCol: Int
        var scroll: Int

        /// Index of the item at 1-based screen row `y`, or nil if the point is
        /// on the border, the hint line, or past the last item.
        func itemIndex(atRow y: Int, count: Int) -> Int? {
            let offset = y - (startRow + 1)      // +1 skips the top border
            guard offset >= 0, offset < listH else { return nil }
            let idx = scroll + offset
            return idx < count ? idx : nil
        }

        /// Whether a 1-based screen point is inside the box at all — a click
        /// outside dismisses.
        func contains(x: Int, y: Int) -> Bool {
            x >= startCol && x < startCol + boxW && y >= startRow && y < startRow + boxH
        }
    }

    static func listBoxGeometry(title: String, items: [String], selected: Int,
                                hint: String, size: Size = Terminal.size()) -> ListBoxGeometry {
        let hintLines = hint.isEmpty ? 0 : 1
        let maxBoxH = max(5, size.rows - 4)
        let listH = max(1, min(items.count, maxBoxH - 2 - hintLines))
        let boxH = listH + 2 + hintLines
        let widest = items.map { Ansi.width($0) }.max() ?? 0
        // See `showOverlay`: `- 5` leaves room for the drop shadow, `+ 6` for
        // the scroll counter.
        let innerW = max(1, min(max(widest, Ansi.width(title) + 2, Ansi.width(hint) + 6),
                                size.cols - 5))
        let boxW = innerW + 4
        var scroll = 0
        if selected >= listH { scroll = min(selected - listH + 1, max(0, items.count - listH)) }
        return ListBoxGeometry(listH: listH, innerW: innerW, boxW: boxW, boxH: boxH,
                               startRow: max(1, (size.rows - boxH) / 2 + 1),
                               startCol: max(1, (size.cols - boxW) / 2 + 1),
                               scroll: scroll)
    }

    static func paintList(title: String, items: [String], selected: Int, hint: String) {
        let g = listBoxGeometry(title: title, items: items, selected: selected, hint: hint)
        paintBox(title: title, items: items, selectable: true, hint: hint,
                 selected: selected, scroll: g.scroll, listH: g.listH, innerW: g.innerW,
                 startRow: g.startRow, startCol: g.startCol, boxW: g.boxW, boxH: g.boxH)
    }

    /// Fit an overlay hint to `width`, dropping whole segments rather than
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
            // `- 5` leaves room for the drop-shadow column each row draws.
            let innerW = max(1, min(max(max(widest, tabsW), Ansi.width(hint) + 6), size.cols - 5))
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
}
