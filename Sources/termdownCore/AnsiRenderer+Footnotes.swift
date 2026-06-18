import Foundation
import Markdown

// swift-markdown has no dedicated FootnoteDefinition node; it parses
// `[^label]: body text` as a plain Paragraph with a leading Text node whose
// string starts with "[^label]: ".  We detect those paragraphs here, render
// their inline content (preserving bold/italic/code), and return a map from
// label → rendered body lines so they can be:
//   • skipped in the main block flow
//   • rendered as a Footnotes section at the end
//   • substituted inline as styled superscript markers
extension AnsiRenderer {

    // MARK: - Footnote parsing

    private static let footnoteDefPattern = #"^\[\^([^\]]+)\]:\s*"#
    private static let footnoteRefPattern = #"\[\^([^\]]+)\]"#

    /// Scan the document's top-level blocks for footnote definition paragraphs.
    /// Returns a map from label → rendered body lines.
    func parseFootnoteDefinitions(from document: Document) -> [String: [String]] {
        var map: [String: [String]] = [:]
        guard let regex = try? NSRegularExpression(pattern: AnsiRenderer.footnoteDefPattern) else { return map }
        for child in document.children {
            guard let para = child as? Paragraph else { continue }
            // Collect the raw text of the paragraph to check for the definition prefix.
            let raw = plainText(para)
            let nsRaw = raw as NSString
            guard let match = regex.firstMatch(in: raw, range: NSRange(location: 0, length: nsRaw.length)),
                  let labelRange = Range(match.range(at: 1), in: raw) else { continue }
            let label = String(raw[labelRange])
            // Render the body: re-render paragraph inline content, stripping the leading "[^label]: " prefix.
            let body = renderFootnoteBody(para, prefixLength: match.range.length)
            map[label] = body
        }
        return map
    }

    /// Render the inline content of a footnote definition paragraph, skipping
    /// the `[^label]: ` prefix characters.
    private func renderFootnoteBody(_ para: Paragraph, prefixLength: Int) -> [String] {
        var flat = flatten(para)
        // Drop the first `prefixLength` characters (the "[^label]: " prefix).
        let drop = min(prefixLength, flat.chars.count)
        flat = Flat(chars: Array(flat.chars.dropFirst(drop)), styles: flat.styles)
        return wrap(flat, width: width - 6)  // indent 6 for the "[N] " marker
    }

    /// Returns true if a paragraph is a footnote definition (should be skipped in main flow).
    func isFootnoteDefinition(_ para: Paragraph) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: AnsiRenderer.footnoteDefPattern) else { return false }
        let raw = plainText(para)
        return regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) != nil
    }

    /// Replace `[^label]` sequences in a Flat with a styled `[label]` superscript.
    func substituteFootnoteRefs(_ flat: Flat, footnoteMap: [String: [String]]) -> Flat {
        // Work on the plain character array; detect '[', '^', label, ']' sequences.
        let chars = flat.chars
        var result: [(Character, Int)] = []
        var styles = flat.styles

        // Add a style for footnote references (superscript-like: bold + link color).
        var refStyle = InlineStyle()
        refStyle.bold = true
        refStyle.color = theme.link
        let refStyleId: Int = {
            let idx = styles.count
            styles.append(refStyle)
            return idx
        }()

        var i = 0
        while i < chars.count {
            // Look for '[^'
            if chars[i].0 == "[" && i + 1 < chars.count && chars[i + 1].0 == "^" {
                // Scan for the closing ']'
                var j = i + 2
                var label = ""
                while j < chars.count && chars[j].0 != "]" && chars[j].0 != "\n" {
                    label.append(chars[j].0); j += 1
                }
                if j < chars.count && chars[j].0 == "]" && footnoteMap[label] != nil {
                    // Emit styled superscript marker.
                    for ch in "[\(label)]" { result.append((ch, refStyleId)) }
                    i = j + 1
                    continue
                }
            }
            result.append(chars[i]); i += 1
        }
        return Flat(chars: result, styles: styles)
    }
}
