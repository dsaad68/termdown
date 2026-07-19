// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Delimiter nesting for the flowchart parser, shared by `maskNested` and
// `splitGraphLines`.

/// Tracks how deeply a scan sits inside node-shape delimiters (`[]`, `()`,
/// `{}`), which both `maskNested` and `splitGraphLines` need in order to tell a
/// label's contents from top-level syntax.
///
/// A plain counter cannot do this: mermaid labels routinely carry unbalanced
/// delimiters (`A[Retry (3x]`, `A[Cost (USD]`, a `:-)` smiley), and a counter
/// bumped by the stray `(` never returns to zero, so the rest of the diagram is
/// swallowed into the label. Matching by kind instead — a `]` closes back
/// through to the nearest `[`, and a closer with no opener is just a literal —
/// keeps one malformed label from consuming everything after it.
struct ShapeNesting {
    private var stack: [Unicode.Scalar] = []

    var isEmpty: Bool { stack.isEmpty }

    mutating func open(_ scalar: Unicode.Scalar) { stack.append(scalar) }

    mutating func close(_ scalar: Unicode.Scalar) {
        let opener: Unicode.Scalar
        switch scalar {
        case "]": opener = "["
        case ")": opener = "("
        default:  opener = "{"
        }
        // Unwind to the matching opener, dropping the unbalanced ones it spans.
        // With no match anywhere the closer is label text, so the depth stands.
        guard let match = stack.lastIndex(of: opener) else { return }
        stack.removeSubrange(match...)
    }
}
