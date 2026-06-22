/// Metadata about a heading in the document.
public struct HeadingInfo {
    public let lineIndex: Int
    public let level: Int
    public let text: String

    public init(lineIndex: Int, level: Int, text: String) {
        self.lineIndex = lineIndex
        self.level = level
        self.text = text
    }
}

/// Metadata about a link in the document.
public struct LinkInfo {
    public let lineIndex: Int
    public let url: String
    public let text: String
    /// Visible start column of the link text on its rendered line.
    public let column: Int
    /// Visible width of the link text in terminal cells.
    public let length: Int

    public init(lineIndex: Int, url: String, text: String, column: Int = 0, length: Int = 0) {
        self.lineIndex = lineIndex
        self.url = url
        self.text = text
        self.column = column
        self.length = length
    }
}

/// An inclusive, 1-indexed range of source-file lines that a rendered row was
/// produced from. Used to map the viewer cursor / edit target back to the source.
public struct SourceSpan: Equatable {
    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

/// A rendered document with metadata for navigation.
public struct RenderedDocument {
    public let lines: [String]
    public let headings: [HeadingInfo]
    public let links: [LinkInfo]
    /// Per-output-row source span, parallel to `lines`. `nil` for synthetic rows
    /// (frontmatter panel, footnote section, block separators, trailing blanks).
    public let sourceSpans: [SourceSpan?]
    /// The exact source string that produced this view (including any
    /// frontmatter), so callers can edit against precisely what was rendered.
    public let source: String

    public init(lines: [String], headings: [HeadingInfo], links: [LinkInfo],
                sourceSpans: [SourceSpan?] = [], source: String = "") {
        self.lines = lines
        self.headings = headings
        self.links = links
        self.sourceSpans = sourceSpans
        self.source = source
    }
}

/// A rendered output row paired with the source span of the block that produced
/// it. Internal to the renderer; flattened into `RenderedDocument` at the end.
struct RenderedRow {
    var text: String
    var span: SourceSpan?

    init(_ text: String, _ span: SourceSpan? = nil) {
        self.text = text
        self.span = span
    }
}

// MARK: - Inline style

/// A resolved set of inline text attributes (bold/italic/code/link/color) that
/// renders a run of characters to styled ANSI.
struct InlineStyle: Hashable {
    var bold = false
    var italic = false
    var strike = false
    var underline = false
    var code = false
    var color: Ansi.Color?
    var link: String?

    private func sgr() -> [Int] {
        var codes: [Int] = []
        if bold { codes.append(1) }
        if italic { codes.append(3) }
        if underline { codes.append(4) }
        if strike { codes.append(9) }
        if let color { codes.append(contentsOf: Ansi.fg(color)) }
        return codes
    }

    func render(_ text: String) -> String {
        var s = Ansi.wrap(text, sgr())
        if let link { s = Ansi.hyperlink(s, url: link) }
        return s
    }
}
