import Foundation
import Markdown
import MermaidRenderer

extension AnsiRenderer {

    // MARK: - Code blocks

    /// Visible columns of card chrome per row: "│ " on the left and " │" on the
    /// right.
    private var cardChrome: Int { 4 }

    /// Interior width of a card drawn at `width` columns, or nil when `width`
    /// cannot hold the chrome plus a single column of content.
    ///
    /// Both the wrapper and `frameCard` size themselves from this so the two can
    /// never disagree. They used to floor differently — `max(4, width - chrome)`
    /// when wrapping, `max(1, width - chrome)` when framing — so a deeply nested
    /// block (list indentation floors the content width at 4) was wrapped to 4
    /// columns and then sliced back to nothing, emitting a card whose every row
    /// was just an ellipsis.
    func cardInterior(for width: Int) -> Int? {
        let inner = width - cardChrome
        return inner >= 1 ? inner : nil
    }

    func renderCodeBlock(_ code: CodeBlock, width: Int) -> [String] {
        let lang = code.language?.trimmingCharacters(in: .whitespaces)
        // Too narrow to frame: the block still renders, just without the box.
        let codeWidth = cardInterior(for: width) ?? max(1, width)

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
            if let rows = Mermaid.render(source, options: options),
               rows.allSatisfy({ Ansi.width($0) <= codeWidth }) {
                return frameCard(label: "mermaid", bodyRows: rows.map { Ansi.color($0, theme.codeText) },
                                 width: width)
            }
            // Wider than the column even after fitting — usually an edge label,
            // which is drawn inline along a one-row arrow and so cannot wrap.
            // Showing 60% of a diagram is worse than showing none of it: you
            // cannot tell which nodes are missing, and a node cut off mid-box
            // reads as a rendering fault. Fall through to the source instead,
            // which is what an unsupported diagram already does.
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

        // No room for chrome plus content. A box drawn here would hold nothing,
        // so emit the rows bare rather than an empty frame.
        guard let inner = cardInterior(for: width) else {
            return bodyRows.map { fitRow($0, to: max(1, width), marker: barColor) }
        }

        let leftBar = Ansi.color("\u{2502} ", barColor)  // │ + space
        let rightBar = Ansi.color(" \u{2502}", barColor) // space + │

        let boxW = width
        let dash = "\u{2500}"

        let header = cardHeader(label, boxW: boxW)
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

    /// The card's opening rule, `┌─ label `, with the label truncated to fit.
    ///
    /// The label is the fence's info string, which is arbitrary author text —
    /// ```` ```json title="config/production.json" linenos ```` is a perfectly
    /// ordinary fence. Left unbounded it produces a top rule wider than the
    /// card, which pushes the frame's right border off-screen in the viewer
    /// (autowrap is off) and gets its styling stripped by the pager: exactly the
    /// damage the exact-width card exists to prevent.
    private func cardHeader(_ label: String, boxW: Int) -> String {
        let corner = "\u{250C}\u{2500}" // ┌─
        guard !label.isEmpty else { return corner }

        let decorated = "\(corner) \(label) "
        let budget = boxW - 2 // leave at least one dash and the closing ┐
        if Ansi.width(decorated) <= budget { return decorated }

        // What remains for the label itself once the corner and its two
        // surrounding spaces are paid for.
        let room = budget - Ansi.width(corner) - 2
        guard room >= 1 else { return corner }
        return "\(corner) \(Ansi.truncate(label, to: room)) "
    }

    /// Whether anything but whitespace sits at or beyond column `inner`.
    ///
    /// Walks the plain text rather than inspecting the sliced-off tail, because
    /// `Ansi.horizontalSlice` substitutes a space for a double-width glyph that
    /// the cut lands inside — so a CJK character straddling the card's right
    /// edge reads as blank in the tail, and testing it there would drop the
    /// character while reporting nothing was lost. A straddling glyph cannot be
    /// drawn, so it counts as lost.
    private func contentLost(beyond inner: Int, in row: String) -> Bool {
        var col = 0
        for ch in Ansi.strip(row) {
            let w = Ansi.charWidth(ch)
            if col + w > inner, !ch.isWhitespace { return true }
            col += w
        }
        return false
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

        let losesContent = contentLost(beyond: inner, in: row)

        // Leave a column for the marker only when one is actually drawn. A
        // wide glyph straddling the cut can come up a column short, so pad.
        let keptWidth = losesContent ? inner - 1 : inner
        let kept = Ansi.horizontalSlice(row, start: 0, width: keptWidth)
        let pad = String(repeating: " ", count: max(0, keptWidth - Ansi.width(kept)))
        return kept + pad + (losesContent ? Ansi.color("\u{2026}", marker) : "")
    }
}
