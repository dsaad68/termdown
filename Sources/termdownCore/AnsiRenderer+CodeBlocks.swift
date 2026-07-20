import Foundation
import Markdown
import MermaidRenderer

extension AnsiRenderer {

    // MARK: - Code blocks

    /// Visible columns of card chrome per row: "│ " on the left and " │" on the
    /// right.
    private var cardChrome: Int { 4 }

    func renderCodeBlock(_ code: CodeBlock, width: Int) -> [String] {
        let lang = code.language?.trimmingCharacters(in: .whitespaces)
        let codeWidth = max(4, width - cardChrome)

        var source = code.code
        if source.hasSuffix("\n") { source.removeLast() }

        // Mermaid: render the diagram as a framed card. Any parse failure (or an
        // unsupported diagram type) falls through to the highlighted block below.
        if mermaidEnabled, lang?.lowercased() == "mermaid" {
            var options = MermaidOptions()
            options.charset = mermaidCharset
            options.colorEnabled = false
            // The diagram lives inside the card, so it gets the card's interior
            // width. Without this the layout runs at its natural size and any
            // overflow reaches the pager, which truncates it destructively.
            options.maxWidth = codeWidth
            if let rows = Mermaid.render(source, options: options) {
                return frameCard(label: "mermaid", bodyRows: rows.map { Ansi.color($0, theme.codeText) },
                                 width: width)
            }
        }

        // Tokenize the whole block once (so multi-line strings / comments stay
        // correctly highlighted), tabs expanded first so colour indices line up
        // with what we render.
        let expanded = source.replacingOccurrences(of: "\t", with: "    ")
        let colors = Highlighter.colorMap(expanded, language: lang, theme: theme)

        // Walk source lines, wrapping each to the code width and colouring every
        // piece from the matching slice of the whole-block colour map.
        var body: [String] = []
        var offset = 0
        for sub in expanded.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineChars = Array(sub)
            let lineLen = lineChars.count
            var i = 0
            repeat {
                var w = 0, j = i
                while j < lineLen {
                    let cw = Ansi.charWidth(lineChars[j])
                    if w + cw > codeWidth && j > i { break }
                    w += cw; j += 1
                }
                body.append(coloredRun(lineChars, colors, base: offset, from: i, to: j))
                i = j
            } while i < lineLen
            offset += lineLen + 1   // +1 for the consumed "\n"
        }

        return frameCard(label: lang ?? "", bodyRows: body, width: width)
    }

    /// Build an ANSI run for `chars[from..<to]`, taking each character's colour
    /// from `colors[base + position]` and grouping equal-coloured neighbours into
    /// one SGR span. Honours `Ansi.colorEnabled` via `Ansi.color`.
    private func coloredRun(_ chars: [Character], _ colors: [Ansi.Color], base: Int, from: Int, to: Int) -> String {
        func colorAt(_ k: Int) -> Ansi.Color {
            let ci = base + k
            return ci < colors.count ? colors[ci] : theme.codeText
        }
        var out = ""
        var k = from
        while k < to {
            let c = colorAt(k)
            var m = k
            while m < to, colorAt(m) == c { m += 1 }
            out += Ansi.color(String(chars[k..<m]), c)
            k = m
        }
        return out
    }

    /// Frame already-coloured `bodyRows` as a complete box: a labelled top rule
    /// (`┌─ label ──┐`), full-height left/right borders, and a closing floor
    /// (`└──┘`).
    ///
    /// The box is exactly `width` columns. It used to grow to fit any row wider
    /// than it, on the theory that the pager would scroll horizontally — but the
    /// pager only does that with wrap off, and wrap is the default. With wrap on
    /// it ran the over-wide row through `Ansi.truncate`, which strips styling and
    /// appends an ellipsis, so a large diagram lost its border and its colour.
    /// Clipping here instead keeps the card intact and the invariant that every
    /// emitted row is exactly the document width.
    ///
    /// Rows are never word-wrapped, so diagram art stays intact; a row that
    /// genuinely cannot fit is sliced (preserving its styling) and marked with
    /// an ellipsis in the border colour.
    func frameCard(label: String, bodyRows: [String], width: Int) -> [String] {
        let barColor = theme.codeBar
        let leftBar = Ansi.color("\u{2502} ", barColor)  // │ + space
        let rightBar = Ansi.color(" \u{2502}", barColor) // space + │

        let boxW = width
        let inner = max(1, boxW - cardChrome)
        let dash = "\u{2500}"

        let header = label.isEmpty ? "\u{250C}\u{2500}" : "\u{250C}\u{2500} \(label) " // ┌─ / ┌─ label
        let headerW = Ansi.width(header)
        let top = Ansi.color(header + String(repeating: dash, count: max(0, boxW - headerW - 1))
            + "\u{2510}", barColor) // ┐
        let bottom = Ansi.color("\u{2514}" + String(repeating: dash, count: max(0, boxW - 2))
            + "\u{2518}", barColor) // └ … ┘

        var out: [String] = [top]
        for row in bodyRows {
            out.append(leftBar + fitRow(row, to: inner, marker: barColor) + rightBar)
        }
        out.append(bottom)
        return out
    }

    /// Bring one card row to exactly `inner` columns: pad it if short, slice it
    /// if long.
    ///
    /// A sliced row is marked with an ellipsis, but only when the slice actually
    /// costs something. A mermaid canvas pads every row out to the width of the
    /// whole drawing, so most rows of an over-wide diagram end in nothing but
    /// spaces — marking those would put an ellipsis on rows that are visibly
    /// empty and imply content was lost where none was. The marker has to mean
    /// "something is missing here" to be worth anything.
    private func fitRow(_ row: String, to inner: Int, marker: Ansi.Color) -> String {
        let rowWidth = Ansi.width(row)
        guard rowWidth > inner else {
            return row + String(repeating: " ", count: inner - rowWidth)
        }

        // `horizontalSlice` carries the active SGR across the cut, unlike
        // `Ansi.truncate`, which flattens the row to plain text.
        let cut = Ansi.strip(Ansi.horizontalSlice(row, start: inner, width: rowWidth - inner))
        let losesContent = cut.contains { !$0.isWhitespace }

        // Leave a column for the marker only when one is actually drawn. A
        // wide glyph straddling the cut can come up a column short, so pad.
        let keptWidth = losesContent ? inner - 1 : inner
        let kept = Ansi.horizontalSlice(row, start: 0, width: keptWidth)
        let pad = String(repeating: " ", count: max(0, keptWidth - Ansi.width(kept)))
        return kept + pad + (losesContent ? Ansi.color("\u{2026}", marker) : "")
    }
}
