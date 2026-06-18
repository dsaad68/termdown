import Foundation
import Markdown

extension AnsiRenderer {

    // MARK: - Block rendering

    func renderBlocks(_ blocks: [Markup], width: Int, listDepth: Int,
                      footnoteMap: [String: [String]] = [:]) -> [String] {
        var out: [String] = []
        var first = true
        for block in blocks {
            let rendered = renderBlock(block, width: width, listDepth: listDepth, footnoteMap: footnoteMap)
            if rendered.isEmpty { continue }
            if !first { out.append("") }
            out.append(contentsOf: rendered)
            first = false
        }
        return out
    }

    func renderBlock(_ block: Markup, width: Int, listDepth: Int,
                     footnoteMap: [String: [String]] = [:]) -> [String] {
        switch block {
        case let heading as Heading:
            return renderHeading(heading, width: width)
        case let paragraph as Paragraph:
            // Skip footnote definition paragraphs — they're rendered in the footnote section.
            if isFootnoteDefinition(paragraph) { return [] }
            return renderParagraph(paragraph, width: width, footnoteMap: footnoteMap)
        case let quote as BlockQuote:
            return renderQuote(quote, width: width, listDepth: listDepth, footnoteMap: footnoteMap)
        case let list as UnorderedList:
            return renderUnorderedList(list, width: width, listDepth: listDepth, footnoteMap: footnoteMap)
        case let list as OrderedList:
            return renderOrderedList(list, width: width, listDepth: listDepth, footnoteMap: footnoteMap)
        case let code as CodeBlock:
            return renderCodeBlock(code, width: width)
        case is ThematicBreak:
            return [Ansi.color(String(repeating: "\u{2500}", count: width), theme.rule)]
        case let table as Table:
            return renderTable(table, width: width)
        case let html as HTMLBlock:
            return html.rawHTML
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { Ansi.dim(String($0)) }
        default:
            // Fall back to rendering children.
            let children = Array(block.children)
            if children.isEmpty { return [] }
            return renderBlocks(children, width: width, listDepth: listDepth, footnoteMap: footnoteMap)
        }
    }

    private func renderHeading(_ heading: Heading, width: Int) -> [String] {
        let level = max(1, min(heading.level, 6))
        let color = theme.heading[level - 1]

        // Banner mode: h1–h4 become a filled background block (no rule).
        if headingBanners && level <= 4 {
            return headingBanner(heading, level: level, color: color, width: width)
        }

        let hashes = String(repeating: "#", count: level)
        let prefix = Ansi.dim(hashes + " ")
        let prefixWidth = level + 1

        var style = InlineStyle()
        style.bold = true
        style.color = color

        let chars = flatten(heading, baseStyle: style)
        var lines = layout(chars, width: width,
                           firstPrefix: prefix, firstPrefixWidth: prefixWidth,
                           contPrefix: String(repeating: " ", count: prefixWidth), contPrefixWidth: prefixWidth)
        // Underline rule for top-level headings.
        if level <= 2 {
            let ruleChar = level == 1 ? "\u{2550}" : "\u{2500}"
            lines.append(Ansi.color(String(repeating: ruleChar, count: width), color))
        }
        return lines
    }

    /// Render a heading as a filled background block: contrasting bold text on the
    /// heading's color, padded to the content width, wrapping long titles. The
    /// leading `#`s are kept but painted in the background color (invisible) so the
    /// metadata scanner still detects the heading (level + text) and the outline,
    /// `]`/`[` nav and contents overlay keep working; they also form a per-level
    /// left inset.
    private func headingBanner(_ heading: Heading, level: Int, color: Ansi.Color, width: Int) -> [String] {
        let fg = Ansi.contrastingText(on: color)
        let hashes = String(repeating: "#", count: level)
        let text = String(flatten(heading).chars.map { $0.0 })
        let inner = max(1, width - level - 2)
        let wrapped = wrapPlain(text, to: inner)
        return wrapped.enumerated().map { (i, line) in
            let lead = i == 0
                ? Ansi.wrap(hashes + " ", Ansi.fg(color) + Ansi.bg(color))   // invisible marker
                : Ansi.wrap(String(repeating: " ", count: level + 1), Ansi.bg(color))
            let body = lead + Ansi.wrap(line, [1] + Ansi.fg(fg) + Ansi.bg(color))
            return Ansi.bgRow(body, bg: color, cols: width)
        }
    }

    /// Simple word-wrap of plain text to a cell width (used for heading banners).
    private func wrapPlain(_ text: String, to width: Int) -> [String] {
        var lines: [String] = []
        var line = ""
        var w = 0
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            let ww = Ansi.width(String(word))
            if w > 0, w + 1 + ww > width { lines.append(line); line = ""; w = 0 }
            if w > 0 { line += " "; w += 1 }
            line += word; w += ww
        }
        if !line.isEmpty || lines.isEmpty { lines.append(line) }
        return lines
    }

    private func renderParagraph(_ paragraph: Paragraph, width: Int,
                                 footnoteMap: [String: [String]] = [:]) -> [String] {
        // Display math: a paragraph that is entirely `$$…$$` is converted to
        // Unicode and centred on its own line.
        let raw = plainText(paragraph).trimmingCharacters(in: .whitespaces)
        if raw.hasPrefix("$$"), raw.hasSuffix("$$"), raw.count > 4 {
            let inner = String(raw.dropFirst(2).dropLast(2))
            let converted = MathConverter.latexToUnicode(inner)
            let styled = Ansi.italic(Ansi.color(converted, theme.math))
            return [Ansi.pad(styled, to: width, align: .center)]
        }

        var flat = flatten(paragraph)
        // Substitute [^label] references with styled superscript markers.
        if !footnoteMap.isEmpty {
            flat = substituteFootnoteRefs(flat, footnoteMap: footnoteMap)
        }
        return wrap(flat, width: width)
    }

    private func renderQuote(_ quote: BlockQuote, width: Int, listDepth: Int,
                             footnoteMap: [String: [String]] = [:]) -> [String] {
        // Check for GitHub alerts: > [!NOTE], > [!TIP], etc.
        var alertType: String?
        var alertColor: Ansi.Color?

        let children = Array(quote.children)
        if let firstChild = children.first, let firstParagraph = firstChild as? Paragraph {
            let paragraphChildren = Array(firstParagraph.children)
            if let firstInline = paragraphChildren.first, let firstText = firstInline as? Markdown.Text {
                let text = firstText.string.trimmingCharacters(in: .whitespaces)
                let alertPattern = #"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]"#
                if let regex = try? NSRegularExpression(pattern: alertPattern, options: []),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   let range = Range(match.range(at: 1), in: text) {
                    alertType = String(text[range])
                    switch alertType {
                    case "NOTE": alertColor = theme.alertNote
                    case "TIP": alertColor = theme.alertTip
                    case "IMPORTANT": alertColor = theme.alertImportant
                    case "WARNING": alertColor = theme.alertWarning
                    case "CAUTION": alertColor = theme.alertCaution
                    default: break
                    }
                }
            }
        }

        // Render as alert if detected
        if let alertType = alertType, let alertColor = alertColor {
            let bar = Ansi.color("\u{2503}", alertColor) + " " // ┃
            let title = Ansi.color("● \(alertType)", alertColor)
            var out: [String] = [bar + title]

            let inner = renderBlocks(children, width: width - 2, listDepth: listDepth, footnoteMap: footnoteMap)
            for line in inner where !line.isEmpty {
                out.append(bar + line)
            }
            return out
        }

        // Default quote rendering
        let bar = Ansi.color("\u{2503}", theme.quoteBar) + " " // ┃
        let inner = renderBlocks(Array(quote.children), width: width - 2, listDepth: listDepth, footnoteMap: footnoteMap)
        return inner.map { line in
            line.isEmpty ? Ansi.color("\u{2503}", theme.quoteBar) : bar + line
        }
    }

    /// Extract plain text from markup (for alt text, etc.)
    func plainText(_ markup: Markup) -> String {
        var result = ""
        for child in markup.children {
            if let text = child as? Markdown.Text {
                result += text.string
            } else if let code = child as? InlineCode {
                result += code.code
            } else {
                result += plainText(child)
            }
        }
        return result
    }
}
