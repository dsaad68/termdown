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
    static func ladder(naturalPaddingX: Int, direction: String? = nil) -> [FitPlan] {
        [
            FitPlan(labelWidthCap: nil, paddingX: naturalPaddingX, direction: direction),
            FitPlan(labelWidthCap: 32, paddingX: min(naturalPaddingX, 4), direction: direction),
            FitPlan(labelWidthCap: 28, paddingX: min(naturalPaddingX, 3), direction: direction),
            FitPlan(labelWidthCap: 24, paddingX: min(naturalPaddingX, 2), direction: direction),
            FitPlan(labelWidthCap: 20, paddingX: min(naturalPaddingX, 2), direction: direction),
            FitPlan(labelWidthCap: 16, paddingX: 1, direction: direction),
        ]
    }
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
    private static func wrap(_ line: String, to cap: Int) -> [String] {
        if DisplayWidth.stringWidth(line) <= cap { return [line] }

        var out: [String] = []
        var current = ""
        var currentWidth = 0

        for word in line.split(separator: " ", omittingEmptySubsequences: true).map(String.init) {
            let wordWidth = DisplayWidth.stringWidth(word)

            if wordWidth > cap {
                if !current.isEmpty {
                    out.append(current)
                    current = ""
                    currentWidth = 0
                }
                out.append(contentsOf: hardSplit(word, to: cap))
                // `hardSplit` leaves its tail as the line in progress.
                current = out.removeLast()
                currentWidth = DisplayWidth.stringWidth(current)
                continue
            }

            let separator = current.isEmpty ? 0 : 1
            if currentWidth + separator + wordWidth > cap {
                out.append(current)
                current = word
                currentWidth = wordWidth
            } else {
                if !current.isEmpty { current += " " }
                current += word
                currentWidth += separator + wordWidth
            }
        }
        if !current.isEmpty { out.append(current) }
        return out.isEmpty ? [line] : out
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
func diagramWidth(_ rendered: String) -> Int {
    var widest = 0
    for line in rendered.split(separator: "\n", omittingEmptySubsequences: false) {
        widest = max(widest, DisplayWidth.stringWidth(String(line)))
    }
    return widest
}
