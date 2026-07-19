// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Node / subgraph label: a multi-line text block sized by display width.
// `<br>` / `<br/>` and literal "\n" both split into separate lines.

import Foundation

let graphLabelLineGap = 1

struct GraphLabel {
    var lines: [String]
    var width: Int

    var height: Int { lines.count }

    /// Total drawn height including the inter-line gap.
    func contentHeight() -> Int {
        if lines.isEmpty { return 0 }
        return lines.count + (lines.count - 1) * graphLabelLineGap
    }
}

/// Flatten an edge label to a single line. Edge labels are drawn inline along a
/// one-row arrow, so unlike node labels they cannot wrap — a `<br>` or literal
/// `\n` has to become a space rather than reaching the canvas as an escape.
func flattenEdgeLabel(_ raw: String) -> String {
    var s = raw.replacingOccurrences(
        of: #"(?i)<br\s*/?>"#, with: " ", options: .regularExpression)
    s = s.replacingOccurrences(of: "\\n", with: " ")
    s = s.replacingOccurrences(of: "\n", with: " ")
    return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
}

func newGraphLabel(_ raw: String) -> GraphLabel {
    var normalized = raw.replacingOccurrences(
        of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
    // Replace the two-character escape backslash-n with a real newline.
    normalized = normalized.replacingOccurrences(of: "\\n", with: "\n")

    var lines = normalized.components(separatedBy: "\n")
    if lines.isEmpty { lines = [""] }

    var width = 0
    for line in lines {
        width = max(width, DisplayWidth.stringWidth(line))
    }
    return GraphLabel(lines: lines, width: width)
}
