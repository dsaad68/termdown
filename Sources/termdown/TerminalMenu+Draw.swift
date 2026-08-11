import termdownCore

/// Rendering for the file picker's frame: the wordmark banner, the header and its
/// breadcrumb row, the search box and the bordered list. Pure layout — no input
/// handling or state mutation. The rows themselves live in `TerminalMenu+Row.swift`.
extension TerminalMenu {

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
    ///
    /// `visible` is the filtered list as shown — file rows in the flat list, folder
    /// rows in the browser — and `total` how many there were before filtering.
    func draw(selected: Int, top: Int, viewport: Int, rows: Int, cols: Int,
              query: String, searching: Bool, visible: [MenuList.Visible],
              total: Int, context: String? = nil) -> [String] {
        let P = Ansi.Pastel.self
        let bv = Ansi.color("\u{2502}", P.borderDim)
        // `max(0, …)`: a terminal narrower than the two border columns would
        // otherwise hand a negative count to `String(repeating:count:)`, which
        // traps rather than drawing something ugly.
        let inner = max(0, cols - 2)  // inside the box borders
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
        // The path stays the folder termdown was opened on, whatever the browser is
        // showing — it is what says which termdown window this is. Where you are
        // *inside* it goes in the breadcrumb row below.
        // `../` is a way out, not one of the things being counted.
        let countText = list.countText(shown: visible.count { !$0.row.isUp }, total: total)
        // The right side is a fixed ~26 columns and the path on the left is
        // unbounded, so this used to run past the border on anything under about
        // 52 columns — and on a deep folder path at any width. Drop the tagline
        // first, then the version, then elide the path: the file count is the
        // only part that is actually information.
        let taglineText = context == nil ? "markdown viewer" : "pick a file"
        let versionText = context == nil ? "v" + appVersion : ""
        let dot = Ansi.color("  \u{00B7}  ", P.borderDim)
        let dotW = 5

        // Priority order, most useful first: the file count, then the folder
        // path (the only thing that says *which* termdown window this is), then
        // the version, then the static tagline. The right-hand side used to be
        // chosen first, which inverted this — on a 48-column terminal it kept
        // "markdown viewer · v0.1.8" and dropped the path entirely.
        //
        // A minimum of 12 columns for the path: shorter than that elides to
        // little more than an ellipsis, which is worth less than the room.
        let countW = Ansi.width(countText)
        let room = max(0, inner - countW - 3 - dotW - 2)
        let pathW = path.isEmpty ? 0 : min(Ansi.width(path), room)
        // A path that fits is shown whatever its length; the 12-column floor is
        // about *elision*, and applying it to the width itself hid every short path
        // there was — `~/notes` is seven columns, so `termdown ~/notes` named no
        // folder at all.
        let showPath = pathW > 0 && (pathW == Ansi.width(path) || pathW >= 12)
        var spent = 3 + countW + 1 + (showPath ? pathW + dotW : 0)

        var rightParts: [String] = []
        if !versionText.isEmpty, spent + dotW + Ansi.width(versionText) + 2 <= inner {
            rightParts.append(versionText)
            spent += dotW + Ansi.width(versionText)
        }
        if spent + dotW + Ansi.width(taglineText) + 2 <= inner {
            rightParts.insert(taglineText, at: 0)
        }

        let subRight = rightParts.enumerated().map { index, text in
            (index == 0 ? "" : dot)
                + Ansi.color(text, text == versionText ? P.textDim : P.accentDim)
        }.joined()

        var sub = "   "
        if showPath {
            sub += Ansi.color(Ansi.clip(path, to: pathW), P.textDim) + dot
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
        // The field scrolls to keep the caret in view instead of being cut from
        // the right, which removed the block cursor and the characters just
        // typed — so the field looked frozen while the list below kept
        // filtering, and you could not see what you were typing.
        var leftPart = " " + caret + typed
        let leftRoom = max(0, innerSearch - 2)
        if Ansi.width(leftPart) > leftRoom {
            let caretPrefix = " " + caret
            let prefixW = Ansi.width(caretPrefix)
            let tailRoom = max(0, leftRoom - prefixW)
            // Show the tail of what was typed, with the cut marked on the left.
            let typedW = Ansi.width(typed)
            let elided = Ansi.color("\u{2026}", P.borderDim)
            leftPart = caretPrefix + elided
                + Ansi.horizontalSlice(typed, start: typedW - max(0, tailRoom - 1),
                                       width: max(0, tailRoom - 1))
        }
        // The browser's keys are not the list's: Enter goes *in*, Backspace comes
        // back out, and `d` is the way to the files. Showing the file list's legend
        // there would advertise the wrong ones.
        let hintSegments: [String]
        if searching {
            hintSegments = [Ansi.color("\u{21B5} open", P.textDim), Ansi.color("Esc done", P.textDim)]
        } else if list.mode == .folders {
            hintSegments = [Ansi.color("\u{21B5} enter", P.textDim), Ansi.color("\u{232B} up", P.textDim),
                            Ansi.color("d files", P.textDim), Ansi.color("? help", P.textDim)]
        } else {
            // A narrowed list can be left the same way a folder can, so it says so.
            hintSegments = [Ansi.color("/ search", P.textDim), Ansi.color("d folders", P.textDim)]
                + (list.showsBreadcrumbRow ? [Ansi.color("\u{232B} up", P.textDim)] : [])
                + [Ansi.color("\u{21B5} open", P.textDim), Ansi.color("? help", P.textDim)]
        }
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

        // ── Breadcrumb, directly above the rows it describes — including `../`,
        // which is the way back *out* of the folder this row names. ──
        let listRows = list.listRows(in: viewport)
        if list.showsBreadcrumbRow {
            out.append(bv + Self.breadcrumbRow(list.breadcrumb, width: max(0, inner - 3),
                                               cols: inner) + bv)
        }

        // ── File / folder rows ──
        let secW = visible.map { Ansi.width($0.row.detail) }.max() ?? 0
        let end = min(top + listRows, visible.count)
        if visible.isEmpty {
            // An empty browser is a project with no folders in it, not a filter
            // that matched nothing — saying "no matching files" there is a lie.
            let msg = query.isEmpty && list.mode == .folders
                ? "   No folders here"
                : "   No matching \(list.noun)"
            for i in 0..<listRows {
                if i == 1 {
                    out.append(bv + Ansi.fit(Ansi.color(msg, P.textDim), to: inner) + bv)
                } else {
                    out.append(bv + String(repeating: " ", count: inner) + bv)
                }
            }
        } else {
            for i in 0..<listRows {
                let idx = top + i
                if idx < end {
                    let item = visible[idx]
                    let row = renderRow(path: item.row.label, detail: item.row.detail,
                                        indices: item.indices, selected: idx == selected,
                                        cols: inner, secW: secW, isFolder: item.row.isFolder)
                    out.append(bv + row + bv)
                } else {
                    out.append(bv + String(repeating: " ", count: inner) + bv)
                }
            }
        }

        // ── Bottom border with pagination pill ──
        let pagCur = min(selected + 1, visible.count)
        let pagText = " \(pagCur)\u{200A}/\u{200A}\(visible.count) "
        // The pill needs its own text plus the four glyphs around it; below that
        // there is no room for a counter and the border goes back to plain.
        if visible.count > listRows, Ansi.width(pagText) + 4 <= cols {
            let pag = pagText
            let pagW = Ansi.width(pag)
            // The row carries four glyphs (╰ ┤ ├ ╯), not two, so the dashes get
            // `inner - pagW - 2`. Budgeting for two made this row two columns
            // too wide at *every* terminal size, in the ordinary case of a
            // folder with more files than fit the viewport.
            let dashes = max(0, inner - pagW - 2)
            let leftD = dashes / 2
            let rightD = dashes - leftD
            out.append(Ansi.color("\u{2570}" + String(repeating: "\u{2500}", count: leftD) + "\u{2524}", P.borderDim)
                       + Ansi.color(pag, P.accentDim)
                       + Ansi.color("\u{251C}" + String(repeating: "\u{2500}", count: rightD) + "\u{256F}", P.borderDim))
        } else {
            out.append(Ansi.color("\u{2570}" + String(repeating: "\u{2500}", count: inner) + "\u{256F}", P.borderDim))
        }

        return out
    }
}
