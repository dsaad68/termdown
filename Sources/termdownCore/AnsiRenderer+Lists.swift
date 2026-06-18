import Foundation
import Markdown

extension AnsiRenderer {

    // MARK: - List rendering

    func renderUnorderedList(_ list: UnorderedList, width: Int, listDepth: Int,
                             footnoteMap: [String: [String]] = [:]) -> [String] {
        let bullets = ["\u{2022}", "\u{25E6}", "\u{25AA}"] // • ◦ ▪
        let bullet = bullets[listDepth % bullets.count]
        var out: [String] = []
        let items = Array(list.listItems)
        let tight = listIsTight(items)
        for (i, item) in items.enumerated() {
            if i > 0 && !tight { out.append("") }
            let marker: String
            if let checkbox = item.checkbox {
                marker = checkbox == .checked
                    ? Ansi.color("\u{2611}", theme.quoteBar) + " "  // ☑
                    : Ansi.dim("\u{2610}") + " "                    // ☐
            } else {
                marker = Ansi.color(bullet, theme.link) + " "
            }
            out.append(contentsOf: renderListItem(item, width: width, marker: marker, markerWidth: 2,
                                                  listDepth: listDepth, tight: tight, footnoteMap: footnoteMap))
        }
        return out
    }

    func renderOrderedList(_ list: OrderedList, width: Int, listDepth: Int,
                           footnoteMap: [String: [String]] = [:]) -> [String] {
        var out: [String] = []
        let items = Array(list.listItems)
        let tight = listIsTight(items)
        let start = Int(list.startIndex)
        let maxNum = start + items.count - 1
        let numWidth = String(maxNum).count
        for (i, item) in items.enumerated() {
            if i > 0 && !tight { out.append("") }
            let label = String(start + i) + "."
            let padded = label.padding(toLength: numWidth + 1, withPad: " ", startingAt: 0)
            let marker = Ansi.color(padded, theme.link) + " "
            let markerWidth = numWidth + 2
            out.append(contentsOf: renderListItem(item, width: width, marker: marker, markerWidth: markerWidth,
                                                  listDepth: listDepth, tight: tight, footnoteMap: footnoteMap))
        }
        return out
    }

    /// Determine whether a list is "tight" (no blank lines between items).
    /// Uses source ranges to detect blank-line gaps; falls back to a structural
    /// heuristic (an item with multiple paragraph-like blocks implies loose).
    private func listIsTight(_ items: [ListItem]) -> Bool {
        for item in items {
            let nonListBlocks = item.children.filter { !($0 is UnorderedList || $0 is OrderedList) }
            if nonListBlocks.count > 1 { return false }
        }
        // A blank line between two items makes the list loose. cmark extends a
        // non-final item's source range to column 1 of the following line when a
        // blank line follows it, so that's our signal. (The final item's trailing
        // blank before the next block doesn't count.)
        if items.count >= 2 {
            for i in 0..<(items.count - 1) {
                if let range = items[i].range, range.upperBound.column == 1 { return false }
            }
        }
        return true
    }

    private func renderListItem(_ item: ListItem, width: Int, marker: String, markerWidth: Int,
                                listDepth: Int, tight: Bool,
                                footnoteMap: [String: [String]] = [:]) -> [String] {
        let contentWidth = max(4, width - markerWidth)
        let contPrefix = String(repeating: " ", count: markerWidth)
        let blocks = Array(item.children)
        var rendered: [String] = []
        for (i, block) in blocks.enumerated() {
            if i > 0 && !tight { rendered.append("") }
            rendered.append(contentsOf: renderBlock(block, width: contentWidth, listDepth: listDepth + 1,
                                                    footnoteMap: footnoteMap))
        }
        var out: [String] = []
        for (j, line) in rendered.enumerated() {
            if j == 0 {
                out.append(marker + line)
            } else {
                out.append(line.isEmpty ? "" : contPrefix + line)
            }
        }
        return out
    }
}
