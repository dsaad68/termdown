import termdownCore

/// Drawing for the picker's individual rows — a file, a folder, and the breadcrumb
/// that says which folder the list is standing in. Pure layout, split from
/// `TerminalMenu+Draw.swift`, which holds the frame chrome and sits on the
/// 400-line lint ceiling.
extension TerminalMenu {

    /// Width of the leading marker column (accent bar / blank).
    private static let markerWidth = 2

    /// The row that opens the list: `❯ docs › api`, relative to the folder termdown
    /// was opened on. Ancestors are dimmed and the folder you are standing in is
    /// picked out, so the row reads as one place rather than a list of names.
    ///
    /// It sits directly above the rows it describes — `../` included, since that row
    /// is the way back out of the folder this one names. The chevron takes the marker
    /// column the rows below use for their selection bar, which lines the crumbs up
    /// with the names underneath instead of floating two columns to their left.
    ///
    /// Elided from the *left* (`… › v1`) when it doesn't fit: the deepest component
    /// is where you are, and cutting the tail would remove exactly the answer the
    /// row exists to give.
    static func breadcrumbRow(_ parts: [String], width: Int, cols: Int) -> String {
        let P = Ansi.Pastel.self
        let chevron = Ansi.wrap("\u{276F} ", [1] + Ansi.fg(P.accent))   // ❯
        let sep = Ansi.color(" \u{203A} ", P.borderDim)   // ›
        let sepW = 3
        let ellipsis = Ansi.color("\u{2026}", P.borderDim)

        /// Components from the right that fit in `budget`, and whether any were left
        /// behind.
        func fitting(_ budget: Int) -> [String] {
            var kept: [String] = []
            var used = 0
            for part in parts.reversed() {
                let cost = Ansi.width(part) + (kept.isEmpty ? 0 : sepW)
                if used + cost > budget { break }
                kept.insert(part, at: 0)
                used += cost
            }
            return kept
        }

        // Budgeted twice, because the `… › ` marker costs four columns of the row it
        // is announcing. Spending them only when eliding — and *before* choosing how
        // many components to keep — is what stops the last one, the folder you are
        // actually in, from being the part that overflows and gets cut.
        var kept = fitting(width)
        if kept.count < parts.count { kept = fitting(max(0, width - 1 - sepW)) }
        // Not even the last component fits: show its tail rather than an empty row.
        if kept.isEmpty, let last = parts.last {
            return band(chevron + Ansi.color(Ansi.clip(last, to: max(0, width)), P.tealAccent),
                        cols: cols)
        }

        let styled = kept.enumerated().map { index, part in
            index == kept.count - 1
                ? Ansi.wrap(part, [1] + Ansi.fg(P.tealAccent))   // where you are
                : Ansi.color(part, P.textDim)                    // how you got here
        }.joined(separator: sep)
        return band(chevron + (kept.count < parts.count ? ellipsis + sep + styled : styled), cols: cols)
    }

    /// Lay the breadcrumb on its own surface across the full row. A shade *below*
    /// the selection surface, so the brightest band in the list is still the row
    /// under the cursor — the two are a column apart and must not compete.
    private static func band(_ text: String, cols: Int) -> String {
        Ansi.bgRow(Ansi.fit(text, to: cols), bg: Ansi.Pastel.panelBg, cols: cols)
    }

    /// Render a single file row with a matte selection surface + mauve accent bar.
    /// A folder row is the same shape with its name in the teal accent and a dimmed
    /// trailing slash, so the two lists are never mistaken for each other.
    func renderRow(path: String, detail: String, indices: [Int],
                   selected: Bool, cols: Int, secW: Int, isFolder: Bool = false) -> String {
        let P = Ansi.Pastel.self
        let marker = selected ? Ansi.bar(P.selectBar) + " " : "  "  // ▌ + space, or blank
        let matched = Set(indices)
        let avail = max(1, cols - Self.markerWidth - secW - 2)

        let chars = Array(path)
        var keep = chars
        var truncated = false
        if Ansi.width(path) > avail {
            var w = 0
            var kept: [Character] = []
            for ch in chars {
                let cw = Ansi.charWidth(ch)
                if w + cw > avail - 1 { break }
                kept.append(ch)
                w += cw
            }
            keep = kept
            truncated = true
        }

        let lastSlash = keep.lastIndex(of: "/")
        var body = ""
        for (j, ch) in keep.enumerated() {
            let isMatch = matched.contains(j)
            // In a file row the leading directories are the dim part and the
            // filename the bright one. A folder row is all name, so the trailing
            // slash is what dims instead — the same rule, read the other way.
            let isDir = isFolder ? ch == "/" : (lastSlash != nil && j <= lastSlash!)
            body += styledChar(ch, isMatch: isMatch, isDir: isDir, selected: selected,
                              isFolder: isFolder)
        }
        if truncated { body += Ansi.color("\u{2026}", selected ? P.selectFg : P.textDim) }

        let left = marker + body
        let leftW = Ansi.width(left)
        let detailW = Ansi.width(detail)
        let gap = max(1, cols - leftW - detailW - 1)
        let detailStyled = Ansi.color(detail, selected ? P.accentDim : P.borderDim)
        // The detail column ("2h ago") is dropped rather than cut once the row
        // is too narrow to hold both — a filename is what the row is for.
        // `bgRow`/`pad` only grow, so neither would have reined this in.
        let fitsDetail = leftW + detailW + 2 <= cols
        let line = fitsDetail
            ? left + String(repeating: " ", count: gap) + detailStyled + " "
            : left
        let row = Ansi.fit(line, to: cols)

        if selected {
            return Ansi.bgRow(row, bg: P.selectBg, cols: cols)
        }
        return row
    }

    private func styledChar(_ ch: Character, isMatch: Bool, isDir: Bool, selected: Bool,
                            isFolder: Bool = false) -> String {
        let s = String(ch)
        guard Ansi.colorEnabled else { return s }
        let P = Ansi.Pastel.self
        if isMatch { return Ansi.wrap(s, [1] + Ansi.fg(P.matchFg)) }  // match always pops
        if selected {
            return isDir ? Ansi.color(s, P.accentDim) : Ansi.wrap(s, [1] + Ansi.fg(P.selectFg))
        }
        if isDir { return Ansi.color(s, P.textDim) }
        // Teal names mark the folder list out from the file list at a glance, which
        // matters when the same key flips between the two.
        if isFolder { return Ansi.color(s, P.tealAccent) }
        return s
    }
}
