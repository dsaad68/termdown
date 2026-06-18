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

/// A rendered document with metadata for navigation.
public struct RenderedDocument {
    public let lines: [String]
    public let headings: [HeadingInfo]
    public let links: [LinkInfo]
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
