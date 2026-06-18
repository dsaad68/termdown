import Foundation
import Markdown

extension AnsiRenderer {

    // MARK: - Code blocks

    func renderCodeBlock(_ code: CodeBlock, width: Int) -> [String] {
        let barColor = theme.codeBar
        let bar = Ansi.color("\u{2502} ", barColor) // │
        let barWidth = 2
        let codeWidth = max(4, width - barWidth)
        let lang = code.language?.trimmingCharacters(in: .whitespaces)

        var source = code.code
        if source.hasSuffix("\n") { source.removeLast() }

        // Tokenize the whole block once (so multi-line strings / comments stay
        // correctly highlighted), tabs expanded first so colour indices line up
        // with what we render.
        let expanded = source.replacingOccurrences(of: "\t", with: "    ")
        let colors = Highlighter.colorMap(expanded, language: lang, theme: theme)

        // Walk source lines, wrapping each to the code width and colouring every
        // piece from the matching slice of the whole-block colour map.
        var body: [String] = []
        var maxW = 0
        var offset = 0
        for sub in expanded.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineChars = Array(sub)
            let lineLen = lineChars.count
            var i = 0
            repeat {
                var w = 0, j = i
                while j < lineLen {
                    let cw = Ansi.charWidth(lineChars[j])
                    if w + cw > codeWidth && j > i { break }
                    w += cw; j += 1
                }
                body.append(bar + coloredRun(lineChars, colors, base: offset, from: i, to: j))
                maxW = max(maxW, barWidth + w)
                i = j
            } while i < lineLen
            offset += lineLen + 1   // +1 for the consumed "\n"
        }

        // Frame: a labelled top rule and a closing bottom elbow, so the block
        // reads as a complete card rather than a dangling left bar.
        let header = (lang?.isEmpty == false) ? "\u{250C}\u{2500} \(lang!) " : "\u{250C}\u{2500}"  // ┌─ lang  /  ┌─
        let headerW = Ansi.width(header)
        let floorW = min(width, max(maxW, headerW))
        let top = Ansi.color(header + String(repeating: "\u{2500}", count: max(0, floorW - headerW)), barColor)
        let bottom = Ansi.color("\u{2514}" + String(repeating: "\u{2500}", count: max(1, floorW - 1)), barColor)

        return [top] + body + [bottom]
    }

    /// Build an ANSI run for `chars[from..<to]`, taking each character's colour
    /// from `colors[base + position]` and grouping equal-coloured neighbours into
    /// one SGR span. Honours `Ansi.colorEnabled` via `Ansi.color`.
    private func coloredRun(_ chars: [Character], _ colors: [Ansi.Color], base: Int, from: Int, to: Int) -> String {
        func colorAt(_ k: Int) -> Ansi.Color {
            let ci = base + k
            return ci < colors.count ? colors[ci] : theme.codeText
        }
        var out = ""
        var k = from
        while k < to {
            let c = colorAt(k)
            var m = k
            while m < to, colorAt(m) == c { m += 1 }
            out += Ansi.color(String(chars[k..<m]), c)
            k = m
        }
        return out
    }
}
