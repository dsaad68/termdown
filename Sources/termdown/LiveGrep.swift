import Foundation
import termdownCore

/// Interactive project-wide search ("live grep") across every discovered
/// Markdown file. Type a query and the matching `file:line` results update
/// live; pressing Enter returns the chosen file and the query so the caller
/// can open it and jump to the match.
final class LiveGrep {
    private struct Source { let url: URL; let relativePath: String; let lines: [String] }
    struct Hit { let url: URL; let relativePath: String; let lineNo: Int; let preview: String }

    private let entries: [(url: URL, relativePath: String)]
    private var cache: [Source]?

    private static let resultCap = 500
    private static let accent: Ansi.Color = 39

    /// Rows `draw` emits above the result list (title, prompt, count, blank).
    /// A click's screen row subtracts this to land on a hit, so it must stay in
    /// step with `draw` — change one and change the other.
    static let headerLines = 4

    /// Whether mouse scroll / click are enabled.
    var mouseEnabled: Bool = false

    init(entries: [(url: URL, relativePath: String)]) {
        self.entries = entries
    }

    /// File contents are read once and cached so repeated opens and per-keystroke
    /// searches stay fast.
    private func sources() -> [Source] {
        if let c = cache { return c }
        let result = entries.map { e -> Source in
            let content = (try? String(contentsOf: e.url, encoding: .utf8)) ?? ""
            return Source(url: e.url, relativePath: e.relativePath,
                          lines: content.components(separatedBy: "\n"))
        }
        cache = result
        return result
    }

    /// Search all (cached) sources for `query`. Testable entry point used by the
    /// UI loop; reads files on first call, then serves from cache.
    func matches(_ query: String) -> [Hit] {
        search(query, in: sources())
    }

    private func search(_ query: String, in srcs: [Source]) -> [Hit] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        var hits: [Hit] = []
        outer: for s in srcs {
            for (i, line) in s.lines.enumerated() where line.lowercased().contains(q) {
                hits.append(Hit(url: s.url, relativePath: s.relativePath, lineNo: i + 1,
                                preview: line.trimmingCharacters(in: .whitespaces)))
                if hits.count >= LiveGrep.resultCap { break outer }
            }
        }
        return hits
    }

    /// Run the search UI; returns the chosen file + query, or nil if cancelled.
    func run() -> (url: URL, query: String)? {
        let srcs = sources()
        var query = ""
        var hits: [Hit] = []
        var selected = 0
        var scroll = 0
        var needsRedraw = true
        var lastRows = -1
        var lastCols = -1

        Terminal.hideCursor()
        // Own a tracking scope rather than inheriting whatever the caller left
        // on: reached via `\` from the pager tracking was already active, but
        // via `T` → grep it was not, so mouse worked or didn't depending on the
        // route. The scope stack makes claiming it here safe either way.
        if mouseEnabled { Terminal.enableMouseTracking() }
        defer {
            if mouseEnabled { Terminal.disableMouseTracking() }
            Terminal.showCursor()
        }

        while true {
            let size = Terminal.size()
            let viewport = max(1, size.rows - LiveGrep.headerLines - 2)

            if Terminal.didResize || size.rows != lastRows || size.cols != lastCols {
                Terminal.didResize = false
                lastRows = size.rows
                lastCols = size.cols
                needsRedraw = true
            }

            if selected < scroll { scroll = selected; needsRedraw = true }
            if selected >= scroll + viewport { scroll = selected - viewport + 1; needsRedraw = true }
            scroll = max(0, min(scroll, max(0, hits.count - viewport)))
            selected = max(0, min(selected, max(0, hits.count - 1)))

            if needsRedraw {
                draw(cols: size.cols, viewport: viewport, query: query, hits: hits,
                     selected: selected, scroll: scroll)
                needsRedraw = false
            }

            guard let key = Terminal.readKey(timeoutMs: 150) else { continue }
            needsRedraw = true

            switch key {
            case .up:
                selected = max(0, selected - 1)
            case .down:
                selected = min(max(0, hits.count - 1), selected + 1)
            case .pageUp:
                selected = max(0, selected - viewport)
            case .pageDown:
                selected = min(max(0, hits.count - 1), selected + viewport)
            case .enter:
                if !hits.isEmpty && selected < hits.count {
                    return (hits[selected].url, query)
                }
            case .escape:
                return nil
            case .mouseScroll(let delta):
                let d = Terminal.coalesceScroll(delta)
                selected = max(0, min(max(0, hits.count - 1), selected + d))
            case .mouseClick(_, let y):
                // A click selects the row; clicking the selected row opens it,
                // matching the file finder's idiom.
                if let idx = LiveGrep.hitIndex(atRow: y, scroll: scroll,
                                               viewport: viewport, count: hits.count) {
                    if idx == selected { return (hits[idx].url, query) }
                    selected = idx
                }
            case .backspace:
                if !query.isEmpty {
                    query.removeLast()
                    hits = search(query, in: srcs)
                    selected = 0; scroll = 0
                }
            case .char(let c):
                if c.isASCII && c != "\n" && c != "\r" {
                    query.append(c)
                    hits = search(query, in: srcs)
                    selected = 0; scroll = 0
                }
            default:
                break
            }
        }
    }

    /// Map a 1-based screen row to an index into `hits`, or nil when the click
    /// landed on the header, the footer, or past the last result. Pure so the
    /// offset math can be tested without driving the run loop.
    static func hitIndex(atRow y: Int, scroll: Int, viewport: Int, count: Int) -> Int? {
        let offset = y - 1 - headerLines
        guard offset >= 0, offset < viewport else { return nil }
        let idx = scroll + offset
        return idx < count ? idx : nil
    }

    private func draw(cols: Int, viewport: Int, query: String, hits: [Hit], selected: Int, scroll: Int) {
        var out: [String] = []
        out.append(Terminal.bold(Terminal.cyan("Project search")))
        out.append("grep> \(query)█")
        out.append(Terminal.dim("\(hits.count) match(es) · ↑↓ move · Enter open · Esc cancel"))
        out.append("")

        let end = min(scroll + viewport, hits.count)
        for i in 0..<viewport {
            let idx = scroll + i
            if idx < end {
                out.append(renderHit(hits[idx], selected: idx == selected, cols: cols))
            } else {
                out.append("")
            }
        }

        out.append("")
        if hits.count > viewport {
            out.append(Terminal.dim("[\(min(selected + 1, hits.count))/\(hits.count)]"))
        } else {
            out.append("")
        }
        Terminal.render(out)
    }

    private func renderHit(_ h: Hit, selected: Bool, cols: Int) -> String {
        let marker = selected ? "\u{276F} " : "  " // ❯
        let loc = "\(h.relativePath):\(h.lineNo)"
        let sep = "  "
        let previewW = max(0, cols - Ansi.width(marker + loc + sep))
        let preview = Ansi.truncate(h.preview, to: previewW)
        if selected {
            let line = marker + loc + sep + preview
            return Ansi.wrap(Ansi.pad(line, to: cols), [7])
        }
        let styledLoc = Ansi.dim(h.relativePath + ":") + Ansi.color("\(h.lineNo)", LiveGrep.accent)
        return marker + styledLoc + sep + preview
    }
}
