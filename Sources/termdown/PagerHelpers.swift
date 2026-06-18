import Foundation
import termdownCore

extension Pager {

    // MARK: - Link helpers

    func isExternalURL(_ url: String) -> Bool {
        if url.hasPrefix("mailto:") || url.hasPrefix("tel:") { return true }
        if let scheme = URL(string: url)?.scheme, !scheme.isEmpty, scheme != "file" { return true }
        return false
    }

    func isMarkdownPath(_ url: URL) -> Bool {
        FileScanner.markdownExtensions.contains(url.pathExtension.lowercased())
    }

    func resolveLink(_ url: String, base: URL) -> URL? {
        var path = url
        for sep in ["#", "?"] {
            if let idx = path.firstIndex(of: Character(sep)) { path = String(path[..<idx]) }
        }
        guard !path.isEmpty else { return nil }
        let decoded = path.removingPercentEncoding ?? path
        return URL(fileURLWithPath: decoded, relativeTo: base).standardizedFileURL
    }

    func openExternal(_ url: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
    }

    func headingIndex(forAnchor anchor: String) -> Int? {
        let target = slug(String(anchor.dropFirst()))
        return headings.firstIndex { slug($0.text) == target }
    }

    func slug(_ s: String) -> String {
        // Keep letters/digits, turn spaces into hyphens, and DROP everything else.
        // (Mapping a disallowed char to `Character("")` traps at runtime — "Can't
        // form a Character from an empty String" — so drop via compactMap.)
        let chars: [Character] = s.lowercased().compactMap {
            if $0.isLetter || $0.isNumber { return $0 }
            return $0 == " " ? "-" : nil
        }
        return String(chars).replacingOccurrences(of: "--", with: "-")
    }

    // MARK: - Code blocks (yank)

    /// Detect fenced code blocks in rendered lines so `y` can copy the one
    /// nearest the cursor. Code lines are `│ …`; a `┌─ lang` header may precede
    /// them. Tables (also `│`-delimited) are recognised by their `┌──┬──┐` top
    /// rule and skipped. Leading indentation (lists) is tolerated.
    static func detectCodeBlocks(_ lines: [String]) -> [CodeBlockInfo] {
        let bar = "\u{2502} "              // "│ "
        func deIndented(_ i: Int) -> Substring { Ansi.strip(lines[i]).drop(while: { $0 == " " }) }
        var blocks: [CodeBlockInfo] = []
        var i = 0
        let n = lines.count
        while i < n {
            let d = deIndented(i)
            // Tables open with a `┌──┬──┐` rule — distinguished by the column
            // tees / right corner that a code frame's `┌─ lang ──` never has.
            let isTableTop = d.hasPrefix("\u{250C}") && (d.contains("\u{252C}") || d.contains("\u{2510}"))
            if isTableTop {
                var j = i + 1
                while j < n, let f = deIndented(j).first, "\u{250C}\u{251C}\u{2514}\u{2502}".contains(f) { j += 1 }
                i = j
                continue
            }
            // Code block: a `┌─ …` top rule (no tees) or a bare `│ ` body. The
            // optional `┌`/`└` frame lines bracket the `│ ` content lines.
            if d.hasPrefix("\u{250C}") || d.hasPrefix(bar) {
                let start = i
                var j = i
                if deIndented(j).hasPrefix("\u{250C}") { j += 1 }   // top rule
                while j < n, deIndented(j).hasPrefix(bar) { j += 1 } // body
                if j < n, deIndented(j).hasPrefix("\u{2514}") { j += 1 } // bottom elbow
                blocks.append(makeCodeBlock(lines, start, j, bar: bar))
                i = j
                continue
            }
            i += 1
        }
        return blocks
    }

    private static func makeCodeBlock(_ lines: [String], _ start: Int, _ end: Int, bar: String) -> CodeBlockInfo {
        var text: [String] = []
        for li in start..<end {
            let t = Ansi.strip(lines[li]).drop(while: { $0 == " " })
            if t.hasPrefix(bar) { text.append(String(t.dropFirst(2))) }
        }
        return CodeBlockInfo(range: start..<end, text: text.joined(separator: "\n"))
    }

    /// The code block nearest the viewport centre (for `y`).
    func nearestCodeBlock(_ blocks: [CodeBlockInfo], top: Int, rows: Int) -> CodeBlockInfo? {
        guard !blocks.isEmpty else { return nil }
        let ref = top + rows / 2
        func distance(_ r: Range<Int>) -> Int {
            if r.contains(ref) { return 0 }
            return ref < r.lowerBound ? r.lowerBound - ref : ref - (r.upperBound - 1)
        }
        return blocks.min(by: { distance($0.range) < distance($1.range) })
    }

    /// The focused link, else the first link visible in the viewport (for `Y`).
    func firstVisibleLink(top: Int, rows: Int) -> Int? {
        links.firstIndex(where: { $0.lineIndex >= top && $0.lineIndex < top + rows })
            ?? links.firstIndex(where: { $0.lineIndex >= top })
    }
}
