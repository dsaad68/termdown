import Foundation
import Markdown

/// Walks inline Markdown markup and flattens it into a `(Character, styleId)`
/// stream plus a style table — the representation the renderer word-wraps. Inline
/// `$…$` / `$$…$$` math is converted to Unicode here so it flows with the prose.
final class InlineFlattener {
    var styles: [InlineStyle] = [InlineStyle()]
    private var index: [InlineStyle: Int] = [InlineStyle(): 0]
    var chars: [(Character, Int)] = []

    private let theme: Theme

    init(theme: Theme) {
        self.theme = theme
    }

    /// Whether a link destination leaves the document (has a non-file URL
    /// scheme, or is a mailto:/tel: link). Relative paths and in-page
    /// anchors (`#section`) are treated as internal.
    static func isExternal(_ destination: String?) -> Bool {
        guard let dest = destination?.trimmingCharacters(in: .whitespaces), !dest.isEmpty else { return false }
        if dest.hasPrefix("#") { return false }
        if dest.hasPrefix("mailto:") || dest.hasPrefix("tel:") { return true }
        if let scheme = URL(string: dest)?.scheme?.lowercased(), !scheme.isEmpty, scheme != "file" {
            return true
        }
        return false
    }

    private func styleId(_ s: InlineStyle) -> Int {
        if let i = index[s] { return i }
        styles.append(s)
        let i = styles.count - 1
        index[s] = i
        return i
    }

    private func emit(_ text: String, _ style: InlineStyle) {
        let id = styleId(style)
        for ch in text { chars.append((ch, id)) }
    }

    /// Emit a Text node, converting inline `$…$` / `$$…$$` math spans to Unicode
    /// and styling them distinctly (italic, math colour). Plain runs pass through
    /// unchanged so prose with stray `$` is unaffected.
    private func emitText(_ text: String, _ style: InlineStyle) {
        for segment in MathConverter.split(text) {
            if segment.isMath {
                var s = style
                s.code = false; s.italic = true; s.color = theme.math; s.link = nil
                emit(MathConverter.latexToUnicode(segment.text), s)
            } else {
                emitProse(segment.text, style)
            }
        }
    }

    /// Emit prose: split out `[[wikilinks]]` and apply `:emoji:` substitution to
    /// the surrounding plain text. (Code spans are a separate node, so they never
    /// reach here — wikilinks/emoji inside `` `code` `` stay literal.)
    private func emitProse(_ text: String, _ style: InlineStyle) {
        var rest = Substring(text)
        while let open = rest.range(of: "[[") {
            let before = rest[rest.startIndex..<open.lowerBound]
            if !before.isEmpty { emit(Emoji.substitute(String(before)), style) }
            let afterOpen = rest[open.upperBound...]
            guard let close = afterOpen.range(of: "]]") else {
                // Unterminated: emit the remainder (including "[[") literally.
                emit(Emoji.substitute(String(rest[open.lowerBound...])), style)
                return
            }
            emitWikilink(String(afterOpen[afterOpen.startIndex..<close.lowerBound]), style)
            rest = afterOpen[close.upperBound...]
        }
        if !rest.isEmpty { emit(Emoji.substitute(String(rest)), style) }
    }

    /// Emit one `[[Target|alias]]` / `[[Target#Heading]]` wikilink as an in-app
    /// link. The destination is encoded as `wikilink:Target#Heading` so the pager
    /// resolves it against the discovered files (the OSC 8 collector picks it up
    /// like any other link).
    private func emitWikilink(_ inner: String, _ style: InlineStyle) {
        let pipe = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let linkPart = pipe[0].trimmingCharacters(in: .whitespaces)
        let alias = pipe.count > 1 ? pipe[1].trimmingCharacters(in: .whitespaces) : nil
        guard !linkPart.isEmpty else { emit("[[\(inner)]]", style); return }  // malformed → literal

        let hash = linkPart.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let target = hash[0].trimmingCharacters(in: .whitespaces)
        let heading = hash.count > 1 ? hash[1].trimmingCharacters(in: .whitespaces) : nil

        var s = style
        s.underline = true; s.color = theme.link; s.code = false
        s.link = "wikilink:" + target + (heading.map { "#" + $0 } ?? "")
        emit(alias ?? linkPart, s)
    }

    func walk(_ markup: Markup, style: InlineStyle) {
        switch markup {
        case let text as Markdown.Text:
            emitText(text.string, style)
        case let code as InlineCode:
            var s = style; s.code = true; s.color = theme.inlineCode; s.bold = false; s.italic = false
            emit(code.code, s)
        case is Emphasis:
            var s = style; s.italic = true
            recurse(markup, s)
        case is Strong:
            var s = style; s.bold = true
            recurse(markup, s)
        case is Strikethrough:
            var s = style; s.strike = true
            recurse(markup, s)
        case let link as Link:
            var s = style; s.underline = true; s.color = theme.link; s.link = link.destination
            recurse(markup, s)
            if InlineFlattener.isExternal(link.destination) {
                // Small north-east arrow marks links that leave the document.
                var icon = style; icon.underline = false; icon.color = theme.link; icon.link = nil; icon.code = false
                emit(" \u{2197}", icon)  // space + ↗
            }
        case let image as Image:
            var s = style; s.color = theme.image; s.italic = true
            let alt = plainText(image)
            let label = alt.isEmpty ? (image.source ?? "image") : alt
            emit("\u{1F5BB} " + label, s) // 🖻
        case is SoftBreak:
            emit(" ", InlineStyle())
        case is LineBreak:
            emit("\n", InlineStyle())
        case let html as InlineHTML:
            var s = style; s.color = 245
            emit(html.rawHTML, s)
        default:
            recurse(markup, style)
        }
    }

    private func recurse(_ markup: Markup, _ style: InlineStyle) {
        for child in markup.children { walk(child, style: style) }
    }

    private func plainText(_ markup: Markup) -> String {
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
