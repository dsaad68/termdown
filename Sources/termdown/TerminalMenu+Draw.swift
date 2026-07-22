import termdownCore

/// Rendering for the file picker: the wordmark banner, the search box, and the
/// per-file rows. Pure layout — no input handling or state mutation.
extension TerminalMenu {

    /// Width of the leading marker column (accent bar / blank).
    private static let markerWidth = 2

    /// Thin-line wordmark glyphs (3 rows each) for t·e·r·m·d·o·w·n.
    private static let bannerGlyphs: [[String]] = [
        [" \u{2577} ", "\u{2576}\u{253C}\u{2574}", " \u{2570}\u{2574}"],  // t
        ["\u{256D}\u{2500}\u{256E}", "\u{251C}\u{2500}\u{2518}", "\u{2570}\u{2500}\u{2574}"],  // e
        ["\u{256D}\u{2574}", "\u{2502} ", "\u{2575} "],  // r
        ["\u{256D}\u{252C}\u{256E}", "\u{2502}\u{2502}\u{2502}", "\u{2575}\u{2575}\u{2575}"],  // m
        ["  \u{2577}", "\u{256D}\u{2500}\u{2524}", "\u{2570}\u{2500}\u{256F}"],  // d
        ["\u{256D}\u{2500}\u{256E}", "\u{2502} \u{2502}", "\u{2570}\u{2500}\u{256F}"],  // o
        ["\u{2577} \u{2577}", "\u{2502} \u{2502}", "\u{2570}\u{2534}\u{256F}"],  // w
        ["\u{256D}\u{2500}\u{256E}", "\u{2502} \u{2502}", "\u{2575} \u{2575}"],  // n
    ]
    /// Soft blue → mauve gradient applied across the wordmark letters.
    private static let bannerColors: [Ansi.Color] = [117, 111, 147, 141, 183, 177, 176, 176]

    /// Even blue→mauve ramp for the legend tab: only the red channel steps up
    /// (95→135→175→215), so it reads as one smooth gradient on a single line
    /// rather than the wordmark's wider, multi-hue art that looks choppy when small.
    private static let legendColors: [Ansi.Color] = [75, 75, 111, 111, 147, 147, 183, 183]

    /// "termdown" as a single line with a smooth blue→mauve gradient (bold). Used
    /// for the legend tab above the contextual ("New tab") finder.
    private static func gradientName() -> String {
        var s = ""
        for (i, ch) in "termdown".enumerated() {
            s += Ansi.wrap(String(ch), [1] + Ansi.fg(legendColors[i]))
        }
        return s
    }

    /// Build the 3 colored rows of the "termdown" wordmark.
    private static func bannerRows() -> [String] {
        var rows = ["", "", ""]
        for (i, g) in bannerGlyphs.enumerated() {
            for r in 0..<3 {
                rows[r] += Ansi.color(g[r], bannerColors[i])
                if i < bannerGlyphs.count - 1 { rows[r] += " " }
            }
        }
        return rows
    }

    /// Build the picker frame. When `context` is set (e.g. "New tab"), the launch
    /// wordmark + "markdown viewer" tagline are swapped for a slim contextual
    /// header so the finder doesn't read as the whole app relaunching. Returns the
    /// styled rows; the caller renders (or slides) them.
    func draw(selected: Int, top: Int, viewport: Int, rows: Int, cols: Int,
              query: String, searching: Bool, filteredItems: [(item: String, indices: [Int])],
              detailFor: [String: String], context: String? = nil) -> [String] {
        let P = Ansi.Pastel.self
        let bv = Ansi.color("\u{2502}", P.borderDim)
        // `max(0, …)`: a terminal narrower than the two border columns would
        // otherwise hand a negative count to `String(repeating:count:)`, which
        // traps rather than drawing something ugly.
        let inner = max(0, cols - 2)  // inside the box borders
        let total = items.count
        var out: [String] = []

        // ── Top border. On the launch screen the wordmark below already shows the
        // app name, so the border stays plain (no duplicate). In context mode the
        // body shows the context (e.g. "New tab"), so a small legend tab names the
        // app up top instead. ──
        if context != nil {
            // The legend is clamped too: below ~12 columns it is wider than the
            // rule it sits in, and the corner ends up pushed off the screen.
            let label = Ansi.width(" " + Self.gradientName() + " ") <= max(0, inner - 1)
                ? " " + Self.gradientName() + " "
                : ""
            let labelW = Ansi.width(label)
            let dashAfter = max(0, inner - 1 - labelW)
            out.append(Ansi.color("\u{256D}\u{2500}", P.borderDim) + label
                       + Ansi.color(String(repeating: "\u{2500}", count: dashAfter) + "\u{256E}", P.borderDim))
        } else {
            out.append(Ansi.color("\u{256D}" + String(repeating: "\u{2500}", count: inner) + "\u{256E}", P.borderDim))
        }

        // ── Header: gradient wordmark at launch, or a slim title in context mode ──
        let banner: [String]
        if let context = context {
            banner = ["", Ansi.wrap(context, [1] + Ansi.fg(P.accent)), ""]
        } else {
            banner = inner >= 40
                ? Self.bannerRows()
                : ["", Ansi.wrap("termdown", [1] + Ansi.fg(P.accent)), ""]
        }
        for br in banner {
            out.append(bv + Ansi.fit("   " + br, to: inner) + bv)
        }

        // ── Subtitle: folder path · file count  (left)   tagline/hint (right) ──
        let filtering = filteredItems.count != total
        let countText = filtering ? "\(filteredItems.count)/\(total) files" : "\(total) files"
        // The right side is a fixed ~26 columns and the path on the left is
        // unbounded, so this used to run past the border on anything under about
        // 52 columns — and on a deep folder path at any width. Drop the tagline
        // first, then the version, then elide the path: the file count is the
        // only part that is actually information.
        let taglineText = context == nil ? "markdown viewer" : "pick a file"
        let versionText = context == nil ? "v" + appVersion : ""
        let dot = Ansi.color("  \u{00B7}  ", P.borderDim)

        var subRight = ""
        for candidate in [[taglineText, versionText], [versionText], []] {
            let parts = candidate.filter { !$0.isEmpty }
            let plain = parts.joined(separator: "  \u{00B7}  ")
            // Room for the count, a gap of 2, and the trailing space.
            if parts.isEmpty || Ansi.width(plain) + Ansi.width(countText) + 6 <= inner {
                subRight = parts.enumerated().map { index, text in
                    (index == 0 ? "" : dot)
                        + Ansi.color(text, index == 0 && context != nil ? P.accentDim
                                     : (text == versionText ? P.textDim : P.accentDim))
                }.joined()
                break
            }
        }

        var sub = "   "
        if !path.isEmpty {
            // What is left for the path once the count, the right side and the
            // separators are paid for.
            let room = inner - Ansi.width(subRight) - Ansi.width(countText) - 3 - 5 - 3
            if room >= 4 {
                sub += Ansi.color(Ansi.truncate(path, to: room), P.textDim) + dot
            }
        }
        sub += Ansi.color(countText, P.tealAccent)

        let subGap = max(1, inner - Ansi.width(sub) - Ansi.width(subRight) - 1)
        out.append(bv
                   + Ansi.fit(sub + String(repeating: " ", count: subGap) + subRight + " ", to: inner)
                   + bv)

        // ── Breathing room ──
        out.append(bv + String(repeating: " ", count: inner) + bv)

        // ── Search field — its own rounded box with a "find" legend. The frame
        // brightens and a block cursor appears only while the box is focused
        // (after `/`); otherwise it shows the active filter, or a hint to press
        // `/` to start searching. ──
        // Never wider than the box it sits inside: `max(12, …)` alone exceeded
        // `inner` below 18 columns, so the search field overhung its own parent.
        let sboxW = min(inner, max(12, inner - 4))
        let bcol = searching ? P.accent : P.accentDim   // brighten the frame when focused
        let innerSearch = sboxW - 2

        let legend = Ansi.wrap(" find ", [1] + Ansi.fg(P.accent))
        let topDash = max(0, sboxW - 2 - Ansi.width(legend))  // clamped: sboxW can be tiny
        let sTop = Ansi.color("\u{256D}", bcol) + legend
                 + Ansi.color(String(repeating: "\u{2500}", count: topDash) + "\u{256E}", bcol)

        let caret  = Ansi.wrap("\u{276F} ", [1] + Ansi.fg(P.selectorFg))  // ❯
        let cursor = Ansi.color("\u{2588}", P.accent)
        let sep    = Ansi.color("  \u{00B7}  ", P.borderDim)
        let typed: String
        if searching {
            typed = query.isEmpty
                ? cursor + Ansi.color(" Type to filter\u{2026}", P.borderDim)
                : Ansi.color(query, P.headerFg) + cursor
        } else {
            typed = query.isEmpty
                ? Ansi.color("Press / to search files\u{2026}", P.borderDim)
                : Ansi.color(query, P.headerFg)
        }
        // Hints are dropped, not cut: `? he\u{2026}` is noise, one hint fewer is not.
        // Least useful last — the unfocused legend is a fixed 42 columns, so it
        // used to run past the border on anything narrower than about 78.
        let leftPart = " " + caret + typed
        let hintSegments = searching
            ? [Ansi.color("\u{21B5} open", P.textDim), Ansi.color("Esc done", P.textDim)]
            : [Ansi.color("/ search", P.textDim), Ansi.color("\u{2191}\u{2193} move", P.textDim),
               Ansi.color("\u{21B5} open", P.textDim), Ansi.color("? help", P.textDim)]
        // What is left once the query and a one-column gap are paid for.
        let hintRoom = innerSearch - Ansi.width(leftPart) - 2
        let hint = Ansi.fittedHint(hintSegments, separator: sep, width: max(0, hintRoom))
        let sgap = max(1, innerSearch - Ansi.width(leftPart) - Ansi.width(hint) - 1)
        let midContent = leftPart + String(repeating: " ", count: sgap) + hint + " "
        let sMid = Ansi.color("\u{2502}", bcol) + Ansi.fit(midContent, to: max(0, innerSearch))
            + Ansi.color("\u{2502}", bcol)
        let sBot = Ansi.color("\u{2570}" + String(repeating: "\u{2500}", count: max(0, sboxW - 2))
                              + "\u{256F}", bcol)

        // The 2-column margins are the first thing to give when the field is as
        // wide as the box that holds it.
        let pad2 = String(repeating: " ", count: max(0, (inner - sboxW) / 2))
        let padRight = String(repeating: " ", count: max(0, inner - sboxW - pad2.count))
        out.append(bv + pad2 + Ansi.fit(sTop, to: sboxW) + padRight + bv)
        out.append(bv + pad2 + Ansi.fit(sMid, to: sboxW) + padRight + bv)
        out.append(bv + pad2 + Ansi.fit(sBot, to: sboxW) + padRight + bv)

        // ── Separator ──
        out.append(Ansi.color("\u{251C}" + String(repeating: "\u{2500}", count: inner) + "\u{2524}", P.borderDim))

        // ── File rows ──
        let secW = detailFor.isEmpty ? 0 : (detailFor.values.map { Ansi.width($0) }.max() ?? 0)
        let end = min(top + viewport, filteredItems.count)
        if filteredItems.isEmpty {
            for i in 0..<viewport {
                if i == 1 {
                    let msg = Ansi.color("   No matching files", P.textDim)
                    out.append(bv + Ansi.pad(msg, to: inner) + bv)
                } else {
                    out.append(bv + String(repeating: " ", count: inner) + bv)
                }
            }
        } else {
            for i in 0..<viewport {
                let idx = top + i
                if idx < end {
                    let (item, indices) = filteredItems[idx]
                    let row = renderRow(path: item, detail: detailFor[item] ?? "", indices: indices,
                                        selected: idx == selected, cols: inner, secW: secW)
                    out.append(bv + row + bv)
                } else {
                    out.append(bv + String(repeating: " ", count: inner) + bv)
                }
            }
        }

        // ── Bottom border with pagination pill ──
        if filteredItems.count > viewport {
            let cur = min(selected + 1, filteredItems.count)
            let pag = " \(cur)\u{200A}/\u{200A}\(filteredItems.count) "
            let pagW = Ansi.width(pag)
            let leftD = max(1, (inner - pagW) / 2)
            let rightD = max(0, inner - leftD - pagW)
            out.append(Ansi.color("\u{2570}" + String(repeating: "\u{2500}", count: leftD) + "\u{2524}", P.borderDim)
                       + Ansi.color(pag, P.accentDim)
                       + Ansi.color("\u{251C}" + String(repeating: "\u{2500}", count: rightD) + "\u{256F}", P.borderDim))
        } else {
            out.append(Ansi.color("\u{2570}" + String(repeating: "\u{2500}", count: inner) + "\u{256F}", P.borderDim))
        }

        return out
    }

    /// Render a single file row with a matte selection surface + mauve accent bar.
    private func renderRow(path: String, detail: String, indices: [Int],
                           selected: Bool, cols: Int, secW: Int) -> String {
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
            let isDir = lastSlash != nil && j <= lastSlash!
            body += styledChar(ch, isMatch: isMatch, isDir: isDir, selected: selected)
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

    private func styledChar(_ ch: Character, isMatch: Bool, isDir: Bool, selected: Bool) -> String {
        let s = String(ch)
        guard Ansi.colorEnabled else { return s }
        let P = Ansi.Pastel.self
        if isMatch { return Ansi.wrap(s, [1] + Ansi.fg(P.matchFg)) }  // match always pops
        if selected {
            return isDir ? Ansi.color(s, P.accentDim) : Ansi.wrap(s, [1] + Ansi.fg(P.selectFg))
        }
        if isDir { return Ansi.color(s, P.textDim) }
        return s
    }
}
