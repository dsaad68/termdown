import Markdown

extension AnsiRenderer {

    // MARK: - Tables

    func renderTable(_ table: Table, width: Int) -> [RenderedRow] {
        // Collect rows of styled cell strings AND their Flat representation for
        // wrapping — so bold/italic/code are preserved when a cell overflows.
        var headerCells: [String] = []
        var headerFlats: [Flat] = []
        for child in table.head.children {
            if let cell = child as? Table.Cell {
                let flat = flatten(cell)
                let (s, _) = styledString(flat)
                headerCells.append(s)
                headerFlats.append(flat)
            }
        }
        let headerSpan = sourceSpan(of: table.head)
        var bodyRows: [[String]] = []
        var bodyFlats: [[Flat]] = []
        var bodyRowSpans: [SourceSpan?] = []
        for rowMarkup in table.body.children {
            guard let row = rowMarkup as? Table.Row else { continue }
            var cells: [String] = []
            var flats: [Flat] = []
            for child in row.children {
                if let cell = child as? Table.Cell {
                    let flat = flatten(cell)
                    let (s, _) = styledString(flat)
                    cells.append(s)
                    flats.append(flat)
                }
            }
            bodyRows.append(cells)
            bodyFlats.append(flats)
            bodyRowSpans.append(sourceSpan(of: row))
        }

        let columnCount = max(headerCells.count, bodyRows.map { $0.count }.max() ?? 0)
        guard columnCount > 0 else { return [] }

        // Normalize row lengths (both strings and flats).
        func normalize(_ row: [String]) -> [String] {
            var r = row; while r.count < columnCount { r.append("") }; return r
        }
        func normalizeFlats(_ row: [Flat]) -> [Flat] {
            var r = row; while r.count < columnCount { r.append(Flat(chars: [], styles: [])) }; return r
        }
        headerCells = normalize(headerCells)
        headerFlats = normalizeFlats(headerFlats)
        bodyRows  = bodyRows.map(normalize)
        bodyFlats = bodyFlats.map(normalizeFlats)

        let alignments: [Ansi.TextAlign] = (0..<columnCount).map { i in
            guard i < table.columnAlignments.count, let a = table.columnAlignments[i] else { return .left }
            switch a {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }

        // Natural column widths.
        var colWidths = [Int](repeating: 0, count: columnCount)
        func consider(_ row: [String]) {
            for (i, cell) in row.enumerated() where i < columnCount {
                colWidths[i] = max(colWidths[i], Ansi.width(cell))
            }
        }
        consider(headerCells)
        bodyRows.forEach(consider)

        // Fit to terminal: borders take 3*cols + 1 columns ("│ " + " │" => each col padded by 2, plus separators).
        let chrome = columnCount * 3 + 1
        let available = max(columnCount * 3, width - chrome)
        let naturalTotal = colWidths.reduce(0, +)
        if naturalTotal > available {
            // Shrink widest columns first until it fits, keeping a minimum.
            let minWidth = 3
            var total = naturalTotal
            while total > available {
                guard let maxIdx = colWidths.indices.max(by: { colWidths[$0] < colWidths[$1] }),
                      colWidths[maxIdx] > minWidth else { break }
                colWidths[maxIdx] -= 1
                total -= 1
            }
        }

        let border = Ansi.color("\u{2502}", theme.tableBorder) // │

        /// Wrap a single cell to `w` columns, preserving inline ANSI styles via
        /// the Flat representation. Returns one or more styled lines.
        func wrapCell(_ flat: Flat, width w: Int) -> [String] {
            // layout() word-wraps and emits styled runs — same path used for paragraphs.
            let lines = layout(flat, width: w, firstPrefix: "", firstPrefixWidth: 0,
                               contPrefix: "", contPrefixWidth: 0)
            return lines.isEmpty ? [""] : lines
        }

        func renderRow(_ row: [String], flats: [Flat]) -> [String] {
            var cellLines: [[String]] = []
            var height = 1
            for i in 0..<columnCount {
                let lines: [String]
                if i < flats.count && Ansi.width(i < row.count ? row[i] : "") > colWidths[i] {
                    lines = wrapCell(flats[i], width: colWidths[i])
                } else {
                    lines = [i < row.count ? row[i] : ""]
                }
                cellLines.append(lines.isEmpty ? [""] : lines)
                height = max(height, cellLines[i].count)
            }
            var rendered: [String] = []
            for line in 0..<height {
                var parts: [String] = [border]
                for i in 0..<columnCount {
                    let content = line < cellLines[i].count ? cellLines[i][line] : ""
                    let padded = Ansi.pad(content, to: colWidths[i], align: alignments[i])
                    parts.append(" " + padded + " ")
                    parts.append(border)
                }
                rendered.append(parts.joined())
            }
            return rendered
        }

        func rule(_ left: String, _ mid: String, _ right: String) -> String {
            var s = left
            for (i, w) in colWidths.enumerated() {
                s += String(repeating: "\u{2500}", count: w + 2)
                s += (i == colWidths.count - 1) ? right : mid
            }
            return Ansi.color(s, theme.tableBorder)
        }

        var out: [RenderedRow] = []
        out.append(RenderedRow(rule("\u{250C}", "\u{252C}", "\u{2510}"))) // ┌┬┐
        out.append(contentsOf: renderRow(headerCells, flats: headerFlats).map { RenderedRow($0, headerSpan) })
        out.append(RenderedRow(rule("\u{251C}", "\u{253C}", "\u{2524}"))) // ├┼┤
        for (i, (row, flats)) in zip(bodyRows, bodyFlats).enumerated() {
            let span = i < bodyRowSpans.count ? bodyRowSpans[i] : nil
            out.append(contentsOf: renderRow(row, flats: flats).map { RenderedRow($0, span) })
        }
        out.append(RenderedRow(rule("\u{2514}", "\u{2534}", "\u{2518}"))) // └┴┘
        return out
    }
}
