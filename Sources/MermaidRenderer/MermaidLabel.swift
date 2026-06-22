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
