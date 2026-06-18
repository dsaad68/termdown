import Markdown

extension AnsiRenderer {

    // MARK: - Inline flattening

    /// A character paired with the index of its style in the flatten result.
    struct Flat {
        var chars: [(Character, Int)]
        var styles: [InlineStyle]
    }

    func flatten(_ markup: Markup, baseStyle: InlineStyle = InlineStyle()) -> Flat {
        let flattener = InlineFlattener(theme: theme)
        for child in markup.children {
            flattener.walk(child, style: baseStyle)
        }
        return Flat(chars: flattener.chars, styles: flattener.styles)
    }

    // MARK: - Wrapping

    func wrap(_ flat: Flat, width: Int) -> [String] {
        layout(flat, width: width, firstPrefix: "", firstPrefixWidth: 0, contPrefix: "", contPrefixWidth: 0)
    }

    /// Word-wrap flattened inline content to `width`, applying prefixes.
    func layout(_ flat: Flat, width: Int,
                firstPrefix: String, firstPrefixWidth: Int,
                contPrefix: String, contPrefixWidth: Int) -> [String] {
        // Build items: words / spaces / forced breaks.
        enum Item { case word([(Character, Int)], Int); case space; case brk }
        var items: [Item] = []
        var current: [(Character, Int)] = []
        var currentWidth = 0
        func endWord() {
            if !current.isEmpty { items.append(.word(current, currentWidth)); current = []; currentWidth = 0 }
        }
        for (ch, id) in flat.chars {
            if ch == "\n" {
                endWord(); items.append(.brk)
            } else if ch == " " || ch == "\t" {
                endWord()
                if case .space = items.last {} else { items.append(.space) }
            } else {
                current.append((ch, id)); currentWidth += Ansi.charWidth(ch)
            }
        }
        endWord()

        var lines: [String] = []
        var line = ""
        var lineWidth = 0
        var isFirst = true
        var pendingSpace = false

        func prefixWidth() -> Int { isFirst ? firstPrefixWidth : contPrefixWidth }
        func flush() {
            let prefix = isFirst ? firstPrefix : contPrefix
            lines.append(prefix + line)
            line = ""; lineWidth = 0; pendingSpace = false; isFirst = false
        }

        for item in items {
            switch item {
            case .brk:
                flush()
            case .space:
                if lineWidth > 0 { pendingSpace = true }
            case let .word(chars, w):
                let maxWidth = width - prefixWidth()
                let need = (pendingSpace ? 1 : 0) + w
                if lineWidth > 0 && lineWidth + need > maxWidth {
                    flush()
                }
                if w > width - prefixWidth() {
                    // Word longer than a full line: hard-split.
                    var chunk: [(Character, Int)] = []
                    var chunkW = 0
                    for cc in chars {
                        let cw = Ansi.charWidth(cc.0)
                        if chunkW + cw > width - prefixWidth() && chunkW > 0 {
                            if pendingSpace && lineWidth > 0 { line += " "; lineWidth += 1 }
                            pendingSpace = false
                            let (s, sw) = styledRun(chunk, styles: flat.styles)
                            line += s; lineWidth += sw
                            flush()
                            chunk = []; chunkW = 0
                        }
                        chunk.append(cc); chunkW += cw
                    }
                    if !chunk.isEmpty {
                        let (s, sw) = styledRun(chunk, styles: flat.styles)
                        line += s; lineWidth += sw
                    }
                } else {
                    if pendingSpace && lineWidth > 0 { line += " "; lineWidth += 1; pendingSpace = false }
                    pendingSpace = false
                    let (s, _) = styledRun(chars, styles: flat.styles)
                    line += s; lineWidth += w
                }
            }
        }
        if lineWidth > 0 || lines.isEmpty { flush() }
        // Drop a trailing empty produced when nothing rendered.
        if lines == [""] { return [] }
        return lines
    }

    /// Render flattened content to a single styled string (no wrapping).
    func styledString(_ flat: Flat) -> (String, Int) {
        // Convert soft breaks / newlines to spaces for single-line contexts.
        let chars = flat.chars.map { (ch, id) in (ch == "\n" ? " " : ch, id) }
        return styledRun(chars, styles: flat.styles)
    }

    private func styledRun(_ chars: [(Character, Int)], styles: [InlineStyle]) -> (String, Int) {
        var out = ""
        var visible = 0
        var i = 0
        while i < chars.count {
            let id = chars[i].1
            var j = i
            var text = ""
            while j < chars.count && chars[j].1 == id {
                text.append(chars[j].0); j += 1
            }
            let style = id < styles.count ? styles[id] : InlineStyle()
            out += style.render(text)
            visible += Ansi.width(text)
            i = j
        }
        return (out, visible)
    }
}
