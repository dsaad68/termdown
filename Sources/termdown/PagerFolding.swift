import Foundation
import termdownCore

extension Pager {

    // MARK: - Fold actions (driven by `z` / `Z`)

    /// Fold/unfold the section the cursor is currently in.
    mutating func foldCurrentSection() {
        if let d = headings.lastIndex(where: { $0.lineIndex <= top }), d < dispHeadingBaseIndex.count {
            let base = dispHeadingBaseIndex[d]
            if foldedHeadings.contains(base) { foldedHeadings.remove(base) }
            else { foldedHeadings.insert(base) }
            reapplyFolds()
            let newMaxTop = max(0, lines.count - contentRows)
            let anchor = baseHeadings[base].lineIndex
            top = (anchor < baseToDisp.count && baseToDisp[anchor] >= 0)
                ? min(max(0, baseToDisp[anchor]), newMaxTop) : min(top, newMaxTop)
            if let lf = linkFocus, lf >= links.count { linkFocus = links.isEmpty ? nil : links.count - 1 }
        }
    }

    /// Toggle fold-all: collapse to a top-level outline, or expand all. Fold
    /// everything below the shallowest heading level so the top sections stay
    /// visible (rather than vanishing under one root).
    mutating func foldAllToggle() {
        let anchorBase = headings.lastIndex(where: { $0.lineIndex <= top })
            .flatMap { $0 < dispHeadingBaseIndex.count ? dispHeadingBaseIndex[$0] : nil }
        if foldedHeadings.isEmpty {
            let minLevel = baseHeadings.map { $0.level }.min() ?? 1
            let deeper = Set(baseHeadings.indices.filter { baseHeadings[$0].level > minLevel })
            foldedHeadings = deeper.isEmpty ? Set(baseHeadings.indices) : deeper
        } else {
            foldedHeadings = []
        }
        reapplyFolds()
        let newMaxTop = max(0, lines.count - contentRows)
        if let ab = anchorBase, ab < baseToDisp.count, baseToDisp[ab] >= 0 {
            top = min(max(0, baseToDisp[ab]), newMaxTop)
        } else { top = min(top, newMaxTop) }
        if let lf = linkFocus, lf >= links.count { linkFocus = links.isEmpty ? nil : links.count - 1 }
    }

    // MARK: - Folding

    /// Recompute the display arrays (`self.lines/headings/links` + the derived
    /// fold state) from the unfolded base document and the set of folded
    /// headings. A folded heading hides its body — every line down to the next
    /// heading of equal-or-higher level — and gains a `▸ N lines` marker.
    mutating func reapplyFolds() {
        let t = Pager.foldTransform(baseLines: baseLines, baseHeadings: baseHeadings,
                                    baseLinks: baseLinks, baseSourceSpans: baseSourceSpans,
                                    folded: foldedHeadings)
        lines = t.lines
        headings = t.headings
        links = t.links
        dispSourceSpans = t.dispSourceSpans
        plainLines = t.lines.map { Ansi.strip($0) }
        maxLineWidth = plainLines.map { Ansi.width($0) }.max() ?? 0
        baseToDisp = t.baseToDisp
        dispHeadingBaseIndex = t.dispHeadingBaseIndex
        codeBlocks = Pager.detectCodeBlocks(t.lines)
        foldHiddenCount = t.foldHiddenCount
    }

    /// The folded display view derived from the base document.
    struct FoldResult {
        var lines: [String]
        var headings: [HeadingInfo]
        var links: [LinkInfo]
        var dispSourceSpans: [SourceSpan?]
        var baseToDisp: [Int]
        var dispHeadingBaseIndex: [Int]
        var foldHiddenCount: [Int: Int]
    }

    /// Pure fold transform: maps the base document to a folded display view.
    static func foldTransform(baseLines: [String], baseHeadings: [HeadingInfo],
                              baseLinks: [LinkInfo], baseSourceSpans: [SourceSpan?] = [],
                              folded: Set<Int>) -> FoldResult {

        // Mark hidden base lines + record each fold's hidden-line count.
        var hidden = [Bool](repeating: false, count: baseLines.count)
        var hiddenCount: [Int: Int] = [:]
        for k in folded.sorted() {
            guard k < baseHeadings.count else { continue }
            let line = baseHeadings[k].lineIndex
            let level = baseHeadings[k].level
            var end = baseLines.count
            var j = k + 1
            while j < baseHeadings.count {
                if baseHeadings[j].level <= level { end = baseHeadings[j].lineIndex; break }
                j += 1
            }
            // Keep the heading's own underline rule (levels 1–2) visible.
            let bodyStart = min(line + 1 + (level <= 2 ? 1 : 0), baseLines.count)
            if bodyStart < end {
                for i in bodyStart..<end where !hidden[i] { hidden[i] = true }
            }
            hiddenCount[k] = max(0, end - bodyStart)
        }

        // Build base→display line map and the visible line list (carrying spans).
        var baseToDisp = [Int](repeating: -1, count: baseLines.count)
        var dispLines: [String] = []
        var dispSourceSpans: [SourceSpan?] = []
        for i in 0..<baseLines.count where !hidden[i] {
            baseToDisp[i] = dispLines.count
            dispLines.append(baseLines[i])
            dispSourceSpans.append(i < baseSourceSpans.count ? baseSourceSpans[i] : nil)
        }

        // Remap headings, appending fold markers to collapsed ones.
        var dispHeadings: [HeadingInfo] = []
        var dispHeadingBaseIndex: [Int] = []
        for (k, h) in baseHeadings.enumerated() {
            guard h.lineIndex < baseToDisp.count else { continue }
            let d = baseToDisp[h.lineIndex]
            guard d >= 0 else { continue }   // hidden inside an outer fold
            if folded.contains(k) {
                let n = hiddenCount[k] ?? 0
                let label = n > 0 ? "  \u{25B8} \(n) line\(n == 1 ? "" : "s")" : "  \u{25B8}"
                dispLines[d] += Ansi.color(label, Ansi.Pastel.borderDim)
            }
            dispHeadings.append(HeadingInfo(lineIndex: d, level: h.level, text: h.text))
            dispHeadingBaseIndex.append(k)
        }

        // Remap links, dropping any inside folded regions.
        var dispLinks: [LinkInfo] = []
        for l in baseLinks {
            guard l.lineIndex < baseToDisp.count else { continue }
            let d = baseToDisp[l.lineIndex]
            guard d >= 0 else { continue }
            dispLinks.append(LinkInfo(lineIndex: d, url: l.url, text: l.text, column: l.column, length: l.length))
        }

        return FoldResult(lines: dispLines, headings: dispHeadings, links: dispLinks,
                          dispSourceSpans: dispSourceSpans, baseToDisp: baseToDisp,
                          dispHeadingBaseIndex: dispHeadingBaseIndex, foldHiddenCount: hiddenCount)
    }
}
