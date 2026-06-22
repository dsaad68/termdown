import Foundation
import Markdown
import MermaidRenderer

/// Renders a parsed Markdown document into styled ANSI lines for the terminal.
///
/// The implementation is split by concern across `AnsiRenderer+*` files:
/// - `+Blocks` — heading / paragraph / quote dispatch.
/// - `+Lists` — ordered / unordered / task lists.
/// - `+CodeBlocks` — fenced code with syntax highlighting.
/// - `+Tables` — GFM tables.
/// - `+Footnotes` — footnote definitions, refs and the footnote section.
/// - `+Inline` — inline flattening, word-wrapping and styled-run emission.
public struct AnsiRenderer {

    /// Content width in terminal columns.
    let width: Int

    /// Color theme for rendering.
    let theme: Theme

    /// When true, headings h1–h4 render as filled background blocks (the heading's
    /// color as the background, contrasting text) instead of colored text + rule.
    let headingBanners: Bool

    /// When true, ```mermaid fenced blocks render as ASCII/Unicode diagrams
    /// (falling back to a highlighted code block if parsing fails).
    let mermaidEnabled: Bool

    /// Box-drawing character set for rendered mermaid diagrams.
    let mermaidCharset: MermaidCharset

    public init(width: Int, theme: Theme = .dark, headingBanners: Bool = false,
                mermaidEnabled: Bool = true, mermaidCharset: MermaidCharset = .unicode) {
        self.width = max(20, width)
        self.theme = theme
        self.headingBanners = headingBanners
        self.mermaidEnabled = mermaidEnabled
        self.mermaidCharset = mermaidCharset
    }

    /// Parse and render markdown source into ANSI-styled lines.
    public func render(_ source: String) -> RenderedDocument {
        // Extract and handle YAML frontmatter. `frontmatterOffset` is the number
        // of leading source lines swift-markdown never sees (its line numbers are
        // relative to the frontmatter-stripped body); add it to every block range
        // so spans address the real file.
        let (frontmatter, markdownSource, frontmatterOffset) = extractFrontmatter(from: source)

        let document = Document(parsing: markdownSource)

        // Extract footnote definitions before rendering so they can be:
        //   • omitted from the main flow (rendered separately at the end)
        //   • referenced inline as superscripts
        let footnoteMap = parseFootnoteDefinitions(from: document)

        var rows = renderBlocks(Array(document.children), width: width, listDepth: 0,
                                footnoteMap: footnoteMap)

        // Add frontmatter panel if present (synthetic rows, no source span).
        if !frontmatter.isEmpty {
            let frontmatterRows = renderFrontmatter(frontmatter).map { RenderedRow($0) }
            rows.insert(contentsOf: frontmatterRows, at: 0)
        }

        // Render footnote section if any definitions were found (synthetic rows).
        if !footnoteMap.isEmpty {
            // Sort by key (label) for stable output.
            let sorted = footnoteMap.sorted { $0.key < $1.key }
            rows.append(RenderedRow(""))
            rows.append(RenderedRow(Ansi.dim(String(repeating: "─", count: width))))
            rows.append(RenderedRow(Ansi.bold("Footnotes")))
            for (label, body) in sorted {
                let marker = Ansi.color("[\(label)]", theme.link)
                // body is already rendered as styled ANSI lines; join for the entry.
                let bodyText = body.joined(separator: " ")
                rows.append(RenderedRow(marker + " " + bodyText))
            }
        }

        // Trim leading/trailing blank lines.
        while rows.first?.text.isEmpty == true { rows.removeFirst() }
        while rows.last?.text.isEmpty == true { rows.removeLast() }
        // Add 2 empty lines at the end.
        rows.append(RenderedRow(""))
        rows.append(RenderedRow(""))

        let lines = rows.map { $0.text }
        // Shift block source spans to absolute file lines (past any frontmatter).
        let sourceSpans: [SourceSpan?] = rows.map { row in
            row.span.map { SourceSpan(start: $0.start + frontmatterOffset, end: $0.end + frontmatterOffset) }
        }

        // Collect headings and links from the final rendered lines.
        var headings: [HeadingInfo] = []
        var links: [LinkInfo] = []
        collectMetadataFromLines(lines: lines, intoHeadings: &headings, intoLinks: &links)

        return RenderedDocument(lines: lines, headings: headings, links: links,
                                sourceSpans: sourceSpans, source: source)
    }

    /// Source span (1-indexed, inclusive) for a block, in frontmatter-stripped
    /// coordinates. `render` shifts these to absolute file lines. cmark often sets
    /// a block's upper bound to column 1 of the *following* line; treat that as the
    /// previous line so the span covers only the block's own content lines.
    func sourceSpan(of markup: Markup) -> SourceSpan? {
        guard let r = markup.range else { return nil }
        let start = r.lowerBound.line
        var end = r.upperBound.line
        if r.upperBound.column <= 1 && end > start { end -= 1 }
        return SourceSpan(start: start, end: max(start, end))
    }

    /// Collect headings and links from rendered lines by scanning for patterns
    private func collectMetadataFromLines(lines: [String], intoHeadings: inout [HeadingInfo], intoLinks: inout [LinkInfo]) {
        for (index, line) in lines.enumerated() {
            let plainLine = Ansi.strip(line)

            // Detect headings: lines that start with # after stripping ANSI codes
            if plainLine.hasPrefix("#") {
                let level = plainLine.prefix(while: { $0 == "#" }).count
                let text = plainLine.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if level > 0 && level <= 6 && !text.isEmpty {
                    intoHeadings.append(HeadingInfo(lineIndex: index, level: level, text: String(text)))
                }
            }

            collectLinks(from: line, lineIndex: index, into: &intoLinks)
        }
    }

    /// Extract OSC 8 hyperlinks (`ESC ] 8 ; ; URL ST  text  ESC ] 8 ; ; ST`)
    /// from a rendered line, recording the URL plus the visible column range of
    /// its display text so the pager can focus/highlight individual links.
    private func collectLinks(from line: String, lineIndex: Int, into links: inout [LinkInfo]) {
        let chars = Array(line)
        let n = chars.count
        var i = 0
        var col = 0
        var pending: (url: String, start: Int, text: String)?
        var raw: [LinkInfo] = []

        while i < n {
            let c = chars[i]
            if c == "\u{1B}" {
                if i + 1 < n && chars[i + 1] == "[" {
                    // CSI: skip to a final byte in 0x40...0x7E.
                    i += 2
                    while i < n {
                        let v = chars[i].unicodeScalars.first!.value
                        i += 1
                        if v >= 0x40 && v <= 0x7E { break }
                    }
                    continue
                } else if i + 1 < n && chars[i + 1] == "]" {
                    // OSC: read content up to the string terminator (BEL or ESC \).
                    i += 2
                    var content = ""
                    while i < n {
                        if chars[i] == "\u{07}" { i += 1; break }
                        if chars[i] == "\u{1B}" && i + 1 < n && chars[i + 1] == "\\" { i += 2; break }
                        content.append(chars[i]); i += 1
                    }
                    if content.hasPrefix("8;;") {
                        let url = String(content.dropFirst(3))
                        if url.isEmpty {
                            if let p = pending {
                                raw.append(LinkInfo(lineIndex: lineIndex, url: p.url, text: p.text,
                                                    column: p.start, length: col - p.start))
                                pending = nil
                            }
                        } else {
                            pending = (url, col, "")
                        }
                    }
                    continue
                } else {
                    i += 1
                    continue
                }
            }
            col += Ansi.charWidth(c)
            if pending != nil { pending!.text.append(c) }
            i += 1
        }

        // The renderer emits one OSC 8 run per word; merge adjacent fragments
        // that share a URL (separated only by whitespace) into a single link.
        let plain = Array(Ansi.strip(line))
        for link in raw {
            if let last = links.last, last.lineIndex == lineIndex, last.url == link.url {
                let gapLo = min(last.column + last.length, plain.count)
                let gapHi = min(link.column, plain.count)
                let between = gapLo <= gapHi ? String(plain[gapLo..<gapHi]) : "x"
                if between.allSatisfy({ $0 == " " || $0 == "\t" }) {
                    links[links.count - 1] = LinkInfo(
                        lineIndex: lineIndex, url: last.url, text: last.text + between + link.text,
                        column: last.column, length: (link.column + link.length) - last.column)
                    continue
                }
            }
            links.append(link)
        }
    }

    /// Extract YAML frontmatter from the source. Returns the frontmatter body, the
    /// markdown source with frontmatter stripped, and the number of leading source
    /// lines that were removed (so block ranges can be mapped back to the file).
    private func extractFrontmatter(from source: String) -> (frontmatter: String, body: String, offset: Int) {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 3,
              lines[0] == "---",
              let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            return ("", source, 0)
        }

        let frontmatter = lines[1..<endIndex].joined(separator: "\n")
        let markdownSource = lines[(endIndex + 1)...].joined(separator: "\n")
        return (frontmatter, markdownSource, endIndex + 1)
    }

    /// Render frontmatter as a metadata panel
    private func renderFrontmatter(_ frontmatter: String) -> [String] {
        var lines: [String] = []
        lines.append(Ansi.dim(String(repeating: "─", count: width)))
        lines.append(Ansi.dim("Metadata"))
        for line in frontmatter.split(separator: "\n") {
            lines.append(Ansi.dim("  " + String(line)))
        }
        lines.append(Ansi.dim(String(repeating: "─", count: width)))
        lines.append("")
        return lines
    }
}
