import Foundation
import termdownCore

extension Pager {

    // MARK: - Tab strip

    /// The inline tab strip carried on the status bar's left side when 2+ tabs are
    /// open (in place of the lone file name). The active tab is bold with an accent
    /// number; the rest are dim. Numbers match the 1–9 jump keys.
    func tabStrip(_ tabs: [TabState], active: Int) -> String {
        let P = Ansi.Pastel.self
        var segs: [String] = []
        for (i, t) in tabs.enumerated() {
            let name = t.title.isEmpty ? "untitled" : t.title
            if i == active {
                segs.append(Ansi.wrap("\(i + 1) ", [1] + Ansi.fg(P.accent))
                          + Ansi.wrap(name, [1] + Ansi.fg(P.headerFg)))
            } else {
                segs.append(Ansi.color("\(i + 1) ", P.accentDim) + Ansi.color(name, P.textDim))
            }
        }
        return segs.joined(separator: Ansi.color(" \u{00B7} ", P.borderDim))
    }

    // MARK: - Frame assembly

    func buildFrame(top: Int, contentRows: Int, cols: Int, maxTop: Int, available: Int,
                    sidebarActive: Bool, sidebarFocus: Bool, sidebarCursor: Int, wrapOn: Bool,
                    hscroll: Int, followMode: Bool, reloadFlashActive: Bool, title: String,
                    searchQuery: String, searchMatches: [(lineIndex: Int, range: Range<Int>)],
                    currentMatchIndex: Int, searchMode: Bool, gotoMode: Bool, gotoInput: String,
                    linkFocus: Int?, copyFlash: String?, tabStrip: String? = nil) -> [String] {
        // While editing, the block under the cursor is replaced by the editable
        // raw-markdown field; everything else stays rendered.
        let view = editMode ? editFrameLines() : lines
        let total = view.count
        let fieldStart = editDisplayStart
        let fieldEnd = editDisplayStart + editBuffer.count
        let scrollable = maxTop > 0

        var thumbStart = 0
        var thumbEnd = 0
        if scrollable {
            let trackH = contentRows
            let thumbH = max(1, min(trackH, Int((Double(contentRows) / Double(total)) * Double(trackH))))
            let pos = Int((Double(top) / Double(maxTop)) * Double(trackH - thumbH))
            thumbStart = pos
            thumbEnd = pos + thumbH
        }

        // Outline sidebar geometry.
        var sidebar: [String] = []
        if sidebarActive {
            sidebar = sidebarColumn(top: top, contentRows: contentRows,
                                    sidebarFocus: sidebarFocus, sidebarCursor: sidebarCursor)
        }

        let P = Ansi.Pastel.self
        let divider = Ansi.color("\u{2502}", P.borderDim)
        let selection = (!editMode && cursorVisible) ? selectionRange() : nil

        var rows: [String] = []

        for vi in 0..<contentRows {
            let lineIdx = top + vi
            let inField = editMode && lineIdx >= fieldStart && lineIdx < fieldEnd
            let isCursor = !editMode && cursorVisible && lineIdx == cursorLine && lineIdx < total
            let inSelection = selection?.contains(lineIdx) ?? false
            var cell = ""
            if lineIdx < total {
                let display = view[lineIdx]
                cell = wrapOn ? Ansi.truncate(display, to: available)
                              : Ansi.horizontalSlice(display, start: hscroll, width: available)
                // Current-line cursor / selection / edit field: a full-width matte
                // highlight across the content column (degrades to the gutter
                // marker under --no-color).
                if inField { cell = Ansi.bgRow(cell, bg: P.outlineSelBg, cols: available) }
                else if isCursor || inSelection { cell = Ansi.bgRow(cell, bg: P.selectBg, cols: available) }
                // Column-range overlays, all applied after the clip. `truncate`
                // above strips styling when it truncates and `bgRow` would
                // overwrite a sub-range tint, so tinting here is what keeps the
                // underlying syntax colours — the previous strip-and-reverse
                // helpers flattened the whole line. Painted weakest first, so a
                // stronger overlay wins the cells they share.
                if !editMode {
                    if let lf = linkFocus, lf < links.count,
                       links[lf].lineIndex == lineIdx, links[lf].length > 0 {
                        cell = tintColumns(cell, from: links[lf].column,
                                           to: links[lf].column + links[lf].length,
                                           bg: P.linkFocusBg, available: available, hscroll: hscroll)
                    }
                    if !searchQuery.isEmpty {
                        for (i, m) in searchMatches.enumerated() where m.lineIndex == lineIdx {
                            cell = tintColumns(cell, from: m.range.lowerBound, to: m.range.upperBound,
                                               bg: i == currentMatchIndex ? P.searchCurBg : P.searchBg,
                                               available: available, hscroll: hscroll)
                        }
                    }
                }
                if let sel = textSelection,
                   let r = sel.columnRange(forLine: lineIdx, width: available + hscroll) {
                    cell = tintColumns(Ansi.pad(cell, to: available),
                                       from: r.lowerBound, to: r.upperBound,
                                       bg: P.selectBg, available: available, hscroll: hscroll)
                }
            }

            var row: String
            if sidebarActive {
                row = sidebar[vi] + divider + " " + cell
            } else {
                let gutter = (isCursor || inField) ? Ansi.bar(P.accent) + " "
                                                   : String(repeating: " ", count: Pager.leftMargin)
                row = gutter + cell
            }
            row = Ansi.pad(row, to: max(0, cols - 1))
            if scrollable {
                let thumb = vi >= thumbStart && vi < thumbEnd
                row += thumb ? Ansi.color("\u{2503}", P.accent) : Ansi.color("\u{250A}", P.borderDim) // ┃ thumb, ┊ track
            } else {
                row += " "
            }
            rows.append(row)
        }

        // Status bar (two-tone) — carries the tab strip on its left when present.
        rows.append(statusBar(top: top, contentRows: contentRows, cols: cols, maxTop: maxTop,
                              wrapOn: wrapOn, followMode: followMode, reloadFlashActive: reloadFlashActive,
                              title: title, searchQuery: searchQuery, searchMatches: searchMatches,
                              currentMatchIndex: currentMatchIndex, searchMode: searchMode,
                              gotoMode: gotoMode, gotoInput: gotoInput,
                              sidebarFocus: sidebarFocus, sidebarCursor: sidebarCursor,
                              linkFocus: linkFocus,
                              sidebarShown: sidebarActive && !sidebarFocus, copyFlash: copyFlash,
                              tabStrip: tabStrip))
        return rows
    }

    // MARK: - Status bar

    func statusBar(top: Int, contentRows: Int, cols: Int, maxTop: Int, wrapOn: Bool,
                   followMode: Bool, reloadFlashActive: Bool, title: String, searchQuery: String,
                   searchMatches: [(lineIndex: Int, range: Range<Int>)], currentMatchIndex: Int,
                   searchMode: Bool, gotoMode: Bool, gotoInput: String,
                   sidebarFocus: Bool, sidebarCursor: Int, linkFocus: Int?,
                   sidebarShown: Bool = false, copyFlash: String? = nil,
                   tabStrip: String? = nil) -> String {
        let P = Ansi.Pastel.self
        let total = lines.count
        let bottom = min(top + contentRows, total)
        let percent = maxTop == 0 ? 100 : Int((Double(top) / Double(maxTop)) * 100.0)

        // Two-tone helper: darker left segment, lighter right segment. Both are
        // bg-filled with inner colours preserved (bgRow re-asserts the bg).
        func twoTone(left: String, right: String) -> String {
            var left = left
            var right = right
            var rw = Ansi.width(right)
            // The bar must never exceed `cols`. Autowrap is off, so an over-wide
            // status row is clipped at the margin and takes the frame's right
            // edge with it — the same failure the row padding guards against.
            // Flags like NOWRAP and "N selected" push past `cols` on a narrow
            // terminal, so elide the left (title + flags) before the right,
            // which carries position and key hints.
            if rw > cols {
                right = Ansi.truncate(right, to: cols)
                rw = Ansi.width(right)
            }
            var lw = Ansi.width(left)
            if lw + rw > cols {
                left = Ansi.truncate(left, to: max(0, cols - rw))
                lw = Ansi.width(left)
            }
            let gap = max(0, cols - lw - rw)
            let leftSeg  = Ansi.bgRow(left, bg: P.statusDimBg, cols: lw)
            let midSeg   = Ansi.wrap(String(repeating: " ", count: gap), Ansi.bg(P.statusBg))
            let rightSeg = Ansi.bgRow(right, bg: P.statusBg, cols: rw)
            return leftSeg + midSeg + rightSeg
        }
        let dot = Ansi.color("  \u{00B7}  ", P.borderDim)

        if savePromptMode {
            let left = Ansi.bar(P.peach) + Ansi.color(" UNSAVED CHANGES ", P.headerFg)
            let right = Ansi.color("[s]", P.green) + Ansi.color("ave", P.textDim) + dot
                + Ansi.color("[d]", P.peach) + Ansi.color("iscard", P.textDim) + dot
                + Ansi.color("[c]", P.blue) + Ansi.color("ancel ", P.textDim)
            return twoTone(left: left + " ", right: right)
        }
        if editMode {
            let lineLabel = editFileSpan.map { $0.start == $0.end ? "L\($0.start)" : "L\($0.start)-\($0.end)" } ?? ""
            let left = Ansi.bar(P.accent) + Ansi.color(" EDIT ", P.headerFg) + Ansi.color(lineLabel, P.accentDim)
            return twoTone(left: left + " ", right: Ansi.color("\u{21B5} save to buffer", P.textDim) + dot + Ansi.color("Esc cancel ", P.textDim))
        }
        if searchMode {
            let count = searchMatches.isEmpty
                ? Ansi.color("no matches", P.peach)
                : Ansi.color("\(currentMatchIndex + 1)/\(searchMatches.count)", P.green)
            let left = Ansi.bar(P.green) + Ansi.color(" /", P.textDim) + Ansi.color(searchQuery, P.headerFg) + Ansi.color("\u{2588}", P.green)
            return twoTone(left: left + " ", right: " " + count + dot + Ansi.color("\u{21B5} accept", P.textDim) + dot + Ansi.color("Esc cancel ", P.textDim))
        }
        if gotoMode {
            let left = Ansi.bar(P.blue) + Ansi.color(" :", P.textDim) + Ansi.color(gotoInput, P.headerFg) + Ansi.color("\u{2588}", P.blue)
            return twoTone(left: left + " ", right: Ansi.color("line number", P.textDim) + dot + Ansi.color("\u{21B5} jump", P.textDim) + dot + Ansi.color("Esc cancel ", P.textDim))
        }
        if sidebarFocus {
            let n = headings.count
            let left = Ansi.bar(P.accent) + Ansi.color(" OUTLINE ", P.headerFg) + Ansi.color("\(n == 0 ? 0 : sidebarCursor + 1)/\(n)", P.accentDim)
            return twoTone(left: left + " ", right: Ansi.color("\u{2191}\u{2193} move", P.textDim) + dot + Ansi.color("\u{21B5} jump", P.textDim) + dot + Ansi.color("s/Esc exit ", P.textDim))
        }

        // Normal status bar — accent "tab" on the left, position + help on the right.
        // With 2+ tabs the file name is replaced by the tab strip.
        var left = Ansi.bar(P.accent) + " " + (tabStrip ?? Ansi.color(title, P.headerFg))
        if isDirty    { left += Ansi.color("  \u{00B7} \u{25CF} unsaved", P.peach) }   // ●
        if !wrapOn    { left += Ansi.color("  \u{00B7} NOWRAP", P.peach) }
        if followMode { left += Ansi.color("  \u{00B7} FOLLOW", P.green) }
        // Cursor mode: selection size, else the current source line (`e`-editable).
        if cursorVisible {
            if let r = selectionRange(), r.count > 1 {
                left += Ansi.color("  \u{00B7} \(r.count) selected", P.accent)
            } else if cursorLine < dispSourceSpans.count, let s = dispSourceSpans[cursorLine] {
                left += Ansi.color("  \u{00B7} L\(s.start)", P.textDim)
            }
        }
        if let lf = linkFocus, lf < links.count {
            left += Ansi.color("  \u{00B7} link \(lf + 1)/\(links.count)", P.blue)
        }
        if sidebarShown {
            left += Ansi.color("  \u{00B7} ", P.borderDim) + Ansi.color("s", P.accent) + Ansi.color(" focus", P.textDim)
        }
        left += " "

        let pos = Ansi.color("\(top + 1)-\(bottom)/\(total)", P.statusFg) + Ansi.color("  \(percent)%", P.accentDim)
        let tail: String
        if let cf = copyFlash {
            tail = dot + Ansi.color("\u{2713} \(cf) ", P.green)   // ✓ copied …
        } else if !searchQuery.isEmpty {
            let matchNum = searchMatches.isEmpty ? 0 : currentMatchIndex + 1
            tail = dot + Ansi.color("/\(searchQuery) ", P.headerFg) + Ansi.color("\(matchNum)/\(searchMatches.count)", P.green)
                 + dot + Ansi.color("n/N", P.textDim) + Ansi.color(" \u{00B7} q ", P.borderDim)
        } else if reloadFlashActive {
            tail = dot + Ansi.color("\u{2605} reloaded ", P.green)
        } else {
            tail = dot + Ansi.color("? help", P.textDim) + Ansi.color(" \u{00B7} q ", P.borderDim)
        }
        return twoTone(left: left, right: pos + tail)
    }

    // MARK: - Highlighting

    /// Tint a content-column range on an already-clipped row.
    ///
    /// Columns arrive in content coordinates (what `LinkInfo` and `searchMatches`
    /// record), so they are shifted into the clipped view and clamped to it.
    /// `Ansi.bgRange` preserves the SGR underneath, which is the whole point:
    /// the helpers this replaced rebuilt the line from `Ansi.strip`, so any line
    /// carrying a search match lost its syntax colours and its OSC 8 links.
    private func tintColumns(_ cell: String, from: Int, to: Int, bg: Ansi.Color,
                             available: Int, hscroll: Int) -> String {
        let lo = max(0, from - hscroll)
        let hi = min(available, to - hscroll)
        guard lo < hi else { return cell }
        return Ansi.bgRange(cell, from: lo, to: hi, bg: bg)
    }
}
