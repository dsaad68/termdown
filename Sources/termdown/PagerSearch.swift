import Foundation
import termdownCore

/// Incremental search: building the match list and moving between hits.
extension Pager {

    mutating func performSearch() {
        searchMatches = []
        currentMatchIndex = 0
        guard !searchQuery.isEmpty else { return }
        let lowerQuery = searchQuery.lowercased()
        // `plainLines` is already ANSI-stripped, so measure the cells directly
        // rather than through `Ansi.width`, whose `strip` would copy every
        // substring again for nothing.
        func columns(_ s: Substring) -> Int { s.reduce(0) { $0 + Ansi.charWidth($1) } }
        for (lineIndex, line) in plainLines.enumerated() {
            let lowerLine = line.lowercased()
            var searchStart = lowerLine.startIndex
            // Display columns, not character offsets: the highlight is drawn
            // with `Ansi.bgRange`, which walks cells, and the two diverge on any
            // line containing CJK or emoji. Carry the column forward with the
            // scan — re-measuring from the start of the line for each hit made
            // a line with k matches cost O(k·n), and `performSearch` runs on
            // every keystroke typed into the `/` prompt.
            var col = 0
            while let range = lowerLine.range(of: lowerQuery, range: searchStart..<lowerLine.endIndex) {
                let lo = col + columns(lowerLine[searchStart..<range.lowerBound])
                let hi = lo + columns(lowerLine[range])
                searchMatches.append((lineIndex, lo..<hi))
                col = hi
                searchStart = range.upperBound
            }
        }
    }

    mutating func centerTop(on lineIndex: Int, viewport: Int) {
        let maxTop = max(0, plainLines.count - viewport)
        top = max(0, min(lineIndex - viewport / 2, maxTop))
    }

    mutating func ensureVisible(_ lineIndex: Int, viewport: Int) {
        if lineIndex < top + Pager.scrolloff || lineIndex >= top + viewport - Pager.scrolloff {
            let maxTop = max(0, plainLines.count - viewport)
            top = max(0, min(lineIndex - Pager.scrolloff, maxTop))
        }
    }
}
