// Fitting a diagram into an available width.
//
// The layout engine has no width budget of its own — it sizes every column to
// whatever its contents need and sums them. That is correct for a standalone
// diagram, but a diagram embedded in a document has to live inside the text
// column, and an over-wide one used to be truncated by the pager (which strips
// styling and appends an ellipsis), producing a mangled card.
//
// Rather than teach the layout to lay out under a constraint — which would mean
// threading a budget through column assignment, edge routing and subgraph
// boxing — this re-runs the whole layout under progressively tighter plans and
// keeps the first that fits. Layout is cheap at diagram sizes, and the natural
// pass is always tried first, so an unconstrained render is bit-for-bit what it
// was before.

import Foundation

/// One attempt at making a diagram fit: how wide a node label may be before it
/// wraps, and how much horizontal room to leave between nodes.
struct FitPlan {
    /// Max display width for a node label line; nil leaves labels untouched.
    let labelWidthCap: Int?
    /// Replaces `GraphProperties.paddingX` for this attempt.
    let paddingX: Int
    /// Overrides the parsed graph direction; nil keeps what the source declared.
    var direction: String?

    /// The unconstrained layout: exactly what the renderer did before this
    /// existed, and what an unbudgeted render still does.
    static func natural(paddingX: Int) -> FitPlan {
        FitPlan(labelWidthCap: nil, paddingX: paddingX)
    }

    /// Attempts in increasing order of damage: wrap labels before squeezing the
    /// gaps, and only squeeze hard once wrapping alone has not been enough.
    ///
    /// The cap stops at 16 rather than chasing ever-narrower boxes. Below about
    /// that, ordinary words stop fitting on a line and start being split
    /// mid-word, which costs far more readability than it buys in columns — and
    /// a diagram that still overflows at 16 is almost always held open by
    /// something wrapping cannot touch (see `flattenEdgeLabel`).
    ///
    /// `minPaddingX` is the narrowest gap that still draws legibly. Fitting is
    /// judged on width alone, so without a floor the tightest rungs will happily
    /// return a diagram that fits and is unreadable — see `legiblePaddingX`.
    /// A graph whose own `paddingX` is already below the floor keeps it: fitting
    /// may only ever narrow a diagram.
    static func ladder(naturalPaddingX: Int, minPaddingX: Int = 1, direction: String? = nil) -> [FitPlan] {
        func padding(_ target: Int) -> Int { min(naturalPaddingX, max(minPaddingX, target)) }
        return [
            FitPlan(labelWidthCap: nil, paddingX: naturalPaddingX, direction: direction),
            FitPlan(labelWidthCap: 32, paddingX: padding(4), direction: direction),
            FitPlan(labelWidthCap: 28, paddingX: padding(3), direction: direction),
            FitPlan(labelWidthCap: 24, paddingX: padding(2), direction: direction),
            FitPlan(labelWidthCap: 20, paddingX: padding(2), direction: direction),
            FitPlan(labelWidthCap: 16, paddingX: padding(1), direction: direction),
        ]
    }
}

/// The narrowest inter-node gap that still draws a legible diagram.
///
/// A subgraph frame is drawn in the gap between its own boxes and whatever sits
/// beside them, so it needs a column of its own on each side. Squeezed to one,
/// the frame and the node boxes land in the same column and the renderer merges
/// them into `┤`/`├` tees: node walls and subgraph walls become the same stroke,
/// arrowheads sit flush against box edges, and the result reads as a rendering
/// fault rather than as a diagram that ran out of room.
func legiblePaddingX(_ properties: GraphProperties) -> Int {
    properties.subgraphs.isEmpty ? 1 : 2
}

extension GraphLabel {
    /// Re-wrap to `cap` display columns, preserving the caller's own line
    /// breaks — a label that already split on `<br>` keeps those breaks and
    /// only over-long segments are folded further.
    ///
    /// Node boxes already draw multi-line labels, so wrapping costs height
    /// rather than information. Edge labels get none of this: they are drawn
    /// inline along a one-row arrow and cannot wrap at all.
    func wrapped(to cap: Int) -> GraphLabel {
        guard cap > 0, width > cap else { return self }
        var out: [String] = []
        for line in lines {
            out.append(contentsOf: GraphLabel.wrap(line, to: cap))
        }
        if out.isEmpty { out = [""] }
        return GraphLabel(lines: out, width: out.reduce(0) {
            max($0, DisplayWidth.stringWidth($1))
        })
    }

    /// Greedy word wrap by display width. A single word wider than `cap` is
    /// hard-split rather than allowed to overhang, since overhanging is the
    /// failure this whole file exists to prevent.
    ///
    /// Spacing the author wrote is preserved wherever the fold does not land on
    /// it: leading indentation, and runs of spaces used to align columns inside
    /// a label. Splitting on whitespace and re-joining with a single space threw
    /// all of that away — and only under a width budget, so the same label came
    /// out aligned in a wide terminal and flush-left in a narrow one.
    private static func wrap(_ line: String, to cap: Int) -> [String] {
        if DisplayWidth.stringWidth(line) <= cap { return [line] }

        var out: [String] = []
        var current = ""
        var currentWidth = 0

        func flush() {
            if !current.isEmpty { out.append(current) }
            current = ""
            currentWidth = 0
        }

        for (gap, word) in spacedWords(line) {
            let gapWidth = DisplayWidth.stringWidth(gap)
            let wordWidth = DisplayWidth.stringWidth(word)

            if wordWidth > cap {
                flush()
                out.append(contentsOf: hardSplit(word, to: cap))
                // `hardSplit` leaves its tail as the line in progress.
                current = out.removeLast()
                currentWidth = DisplayWidth.stringWidth(current)
            } else if current.isEmpty {
                // Indentation survives only while it still leaves room to draw.
                let indent = gapWidth + wordWidth <= cap ? gap : ""
                current = indent + word
                currentWidth = DisplayWidth.stringWidth(indent) + wordWidth
            } else if currentWidth + gapWidth + wordWidth > cap {
                flush()
                current = word
                currentWidth = wordWidth
            } else {
                current += gap + word
                currentWidth += gapWidth + wordWidth
            }
        }
        flush()
        return out.isEmpty ? [line] : out
    }

    /// Split a line into `(whitespace before it, word)` pairs, so a fold that
    /// keeps two words together can put their original spacing back verbatim.
    private static func spacedWords(_ line: String) -> [(gap: String, word: String)] {
        var out: [(String, String)] = []
        var gap = ""
        var word = ""
        for ch in line {
            if ch == " " {
                if !word.isEmpty {
                    out.append((gap, word))
                    gap = ""
                    word = ""
                }
                gap.append(ch)
            } else {
                word.append(ch)
            }
        }
        if !word.isEmpty { out.append((gap, word)) }   // trailing spaces are dropped
        return out
    }

    /// Break an unbreakable run into `cap`-wide chunks, measuring by grapheme
    /// cluster so a wide glyph is never split down the middle.
    private static func hardSplit(_ word: String, to cap: Int) -> [String] {
        var out: [String] = []
        var chunk = ""
        var chunkWidth = 0
        for ch in word {
            let w = DisplayWidth.clusterWidth(ch)
            if chunkWidth + w > cap, !chunk.isEmpty {
                out.append(chunk)
                chunk = ""
                chunkWidth = 0
            }
            chunk.append(ch)
            chunkWidth += w
        }
        if !chunk.isEmpty { out.append(chunk) }
        return out
    }
}

/// Widest row of a rendered diagram, in display columns.
///
/// Escape sequences are skipped: with `MermaidOptions.colorEnabled` — the public
/// default — every styled span carries an SGR prefix and reset, and counting
/// those as visible columns makes each one measure ~24 columns too wide. Every
/// rung of the ladder then looks like an overflow, so a diagram that already fit
/// comfortably came back squeezed to the tightest layout for no reason.
func diagramWidth(_ rendered: String) -> Int {
    var widest = 0
    for line in rendered.split(separator: "\n", omittingEmptySubsequences: false) {
        widest = max(widest, DisplayWidth.stringWidth(stripEscapes(String(line))))
    }
    return widest
}

/// Drop ANSI escape sequences (CSI and OSC) from a string.
///
/// MermaidRenderer stays dependency-free so it can be vendored on its own, so it
/// cannot reach for `Ansi.strip`.
private func stripEscapes(_ s: String) -> String {
    guard s.contains("\u{1B}") else { return s }
    var out = ""
    var chars = Array(s)[...]
    while let c = chars.first {
        guard c == "\u{1B}", chars.count > 1 else {
            out.append(c)
            chars = chars.dropFirst()
            continue
        }
        let kind = chars[chars.startIndex + 1]
        if kind == "[" {                       // CSI: ends at the first @-~ byte
            chars = chars.dropFirst(2)
            while let c = chars.first {
                chars = chars.dropFirst()
                if let v = c.unicodeScalars.first?.value, (0x40...0x7E).contains(v) { break }
            }
        } else if kind == "]" {                // OSC: ends at BEL or ESC \
            chars = chars.dropFirst(2)
            while let c = chars.first {
                chars = chars.dropFirst()
                if c == "\u{07}" { break }
                if c == "\u{1B}", chars.first == "\\" { chars = chars.dropFirst(); break }
            }
        } else {
            chars = chars.dropFirst(2)
        }
    }
    return out
}
