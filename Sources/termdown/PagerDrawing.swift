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
                var display = view[lineIdx]
                if !editMode, !searchQuery.isEmpty {
                    display = highlightLine(display, lineIndex: lineIdx, matches: searchMatches, currentMatchIndex: currentMatchIndex)
                } else if !editMode, wrapOn, let lf = linkFocus, lf < links.count,
                          links[lf].lineIndex == lineIdx, links[lf].length > 0 {
                    display = highlightColumns(display, start: links[lf].column, length: links[lf].length)
                }
                cell = wrapOn ? Ansi.truncate(display, to: available)
                              : Ansi.horizontalSlice(display, start: hscroll, width: available)
                // Current-line cursor / selection / edit field: a full-width matte
                // highlight across the content column (degrades to the gutter
                // marker under --no-color).
                if inField { cell = Ansi.bgRow(cell, bg: P.outlineSelBg, cols: available) }
                else if isCursor || inSelection { cell = Ansi.bgRow(cell, bg: P.selectBg, cols: available) }
                // Character-precise mouse selection, applied last: `truncate`
                // above strips styling when it truncates, and `bgRow` would
                // otherwise overwrite a sub-range tint. Columns are stored in
                // content coordinates, so shift them into the clipped view.
                if let sel = textSelection,
                   let r = sel.columnRange(forLine: lineIdx, width: available + hscroll) {
                    let lo = max(0, r.lowerBound - hscroll)
                    let hi = min(available, r.upperBound - hscroll)
                    if lo < hi {
                        cell = Ansi.bgRange(Ansi.pad(cell, to: available), from: lo, to: hi, bg: P.selectBg)
                    }
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

    /// Re-render a line as plain text with search matches highlighted.
    private func highlightLine(_ line: String, lineIndex: Int,
                               matches: [(lineIndex: Int, range: Range<Int>)],
                               currentMatchIndex: Int) -> String {
        let onThisLine = matches.enumerated().filter { $0.element.lineIndex == lineIndex }
        if onThisLine.isEmpty { return line }
        let plain = Array(Ansi.strip(line))
        let sorted = onThisLine.sorted { $0.element.range.lowerBound < $1.element.range.lowerBound }
        var result = ""
        var idx = 0
        for (globalIdx, m) in sorted {
            let lo = max(idx, m.range.lowerBound)
            let hi = min(m.range.upperBound, plain.count)
            if lo > idx { result += String(plain[idx..<lo]) }
            if lo < hi {
                let seg = String(plain[lo..<hi])
                let codes = globalIdx == currentMatchIndex ? [7, 1] : [7]
                result += Ansi.wrap(seg, codes)
            }
            idx = max(idx, hi)
        }
        if idx < plain.count { result += String(plain[idx...]) }
        return result
    }

    /// Highlight a visible column range on a line (used for the focused link).
    private func highlightColumns(_ line: String, start: Int, length: Int) -> String {
        let plain = Array(Ansi.strip(line))
        let lo = max(0, start)
        let hi = min(plain.count, start + length)
        guard lo < hi else { return line }
        var out = ""
        if lo > 0 { out += String(plain[0..<lo]) }
        out += Ansi.wrap(String(plain[lo..<hi]), [7, 1])
        if hi < plain.count { out += String(plain[hi...]) }
        return out
    }
}
