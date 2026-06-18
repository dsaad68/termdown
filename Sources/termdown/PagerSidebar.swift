import termdownCore

extension Pager {

    // MARK: - Outline sidebar

    /// A depth marker glyph + colour for an outline heading level.
    /// L1 ◆ (mauve), L2 ◇ (lavender), L3 • (dim), L4+ · (faint).
    private func outlineMarker(level: Int) -> (glyph: String, color: Ansi.Color) {
        let P = Ansi.Pastel.self
        switch level {
        case 0, 1: return ("\u{25C6}", P.accent)     // ◆
        case 2:    return ("\u{25C7}", P.accentDim)  // ◇
        case 3:    return ("\u{2022}", P.textDim)    // •
        default:   return ("\u{00B7}", P.borderDim)  // ·
        }
    }

    /// Build the outline sidebar cells (one per content row).
    ///
    /// Row 0 is an "OUTLINE" panel header; the remaining rows list the headings.
    /// Each heading shows a depth marker + indented title. Three visual states:
    ///   • cursor  (focused selection): dark-lavender surface + mauve bar + bright text
    ///   • current (reading position):  mauve bar + mauve text
    ///   • normal:                      level-coloured marker, dimmed title
    /// The column has no background fill — it shares the document's dark canvas, so
    /// focus reads from the header (accent bar + ↑↓) and the lavender selection
    /// rather than a grey wash. ⌃/⌄ chevrons mark where the outline scrolls offscreen.
    func sidebarColumn(top: Int, contentRows: Int,
                       sidebarFocus: Bool, sidebarCursor: Int) -> [String] {
        let P = Ansi.Pastel.self
        let w = Pager.sidebarWidth
        // Heading jumps land the target `scrolloff` lines below `top`, so the
        // active section is the last heading at or above that offset line —
        // otherwise the indicator lands one heading too high.
        let current = headings.lastIndex { $0.lineIndex <= top + Pager.scrolloff }

        // Row 0 is the panel header; the outline list fills the rows beneath it.
        let listRows = max(0, contentRows - 1)
        let maxScroll = max(0, headings.count - listRows)
        // When focused, keep the cursor row centred; otherwise follow the reading position.
        let anchor = sidebarFocus ? sidebarCursor : (current ?? 0)
        let scroll = max(0, min(anchor - listRows / 2, maxScroll))

        var cells: [String] = [sidebarHeader(focus: sidebarFocus, width: w)]
        for vi in 0..<listRows {
            let idx = scroll + vi
            guard idx < headings.count else { cells.append(Ansi.pad("", to: w)); continue }
            let h = headings[idx]
            let indent = String(repeating: " ", count: min(max(0, h.level - 2), 3))
            let (mk, mkColor) = outlineMarker(level: h.level)
            let avail = max(1, w - 4 - indent.count)   // bar+sp + marker+sp
            let text = Ansi.truncate(h.text, to: avail)

            // While focused, the cursor is the only highlight; the reading-
            // position indicator returns once focus is released.
            let isCursor  = sidebarFocus && idx == sidebarCursor
            let isCurrent = !sidebarFocus && idx == current

            // Scroll affordance: replace the marker on the edge rows with a chevron.
            let topMore = vi == 0 && scroll > 0
            let botMore = vi == listRows - 1 && idx < headings.count - 1

            if isCursor {
                let glyph = topMore ? "\u{2303}" : (botMore ? "\u{2304}" : mk)
                let line = Ansi.bar(P.selectBar) + " " + indent
                         + Ansi.color(glyph, P.selectFg) + " "
                         + Ansi.wrap(text, [1] + Ansi.fg(P.selectFg))
                cells.append(Ansi.bgRow(line, bg: P.outlineSelBg, cols: w))
            } else if isCurrent {
                let glyph = topMore ? "\u{2303}" : (botMore ? "\u{2304}" : mk)
                let line = Ansi.bar(P.accent) + " " + indent
                         + Ansi.color(glyph, P.accent) + " "
                         + Ansi.color(text, P.accent)
                cells.append(Ansi.pad(line, to: w))
            } else {
                let glyph = topMore ? Ansi.color("\u{2303}", P.accentDim)
                          : (botMore ? Ansi.color("\u{2304}", P.accentDim)
                                     : Ansi.color(mk, mkColor))
                let title = h.level <= 1
                    ? Ansi.wrap(text, [1] + Ansi.fg(P.statusFg))
                    : Ansi.color(text, P.textDim)
                let line = "  " + indent + glyph + " " + title
                cells.append(Ansi.pad(line, to: w))
            }
        }

        // Affordance: when the outline is visible but not yet focused, label the
        // last (blank) list row with a hint to press `s` to navigate it. If the
        // outline is long enough to fill the column, the footer carries the hint.
        if !sidebarFocus, listRows > 0, scroll + listRows - 1 >= headings.count {
            cells[contentRows - 1] = Ansi.pad(
                Ansi.color("  s ", P.accent) + Ansi.color("to focus", P.textDim), to: w)
        }
        return cells
    }

    /// The outline panel's header row. Idle: a dim "OUTLINE" label. Focused: a
    /// mauve accent bar, a bright label, and an ↑↓ affordance — so the panel reads
    /// as active without needing a background wash.
    private func sidebarHeader(focus: Bool, width w: Int) -> String {
        let P = Ansi.Pastel.self
        let label: String
        if focus {
            label = Ansi.bar(P.accent) + Ansi.wrap(" OUTLINE", [1] + Ansi.fg(P.headerFg))
                  + " " + Ansi.color("\u{2191}\u{2193}", P.accent)
        } else {
            label = "  " + Ansi.color("OUTLINE", P.textDim)
        }
        return Ansi.pad(label, to: w)
    }
}
