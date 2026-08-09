import Foundation
import Markdown

/// A callout — a blockquote whose first line opens with a `[!TAG]` marker:
///
///     > [!NOTE]
///     > Body text.
///
///     > [!TIP] Try this instead
///     > Body text.
///
/// Covers GitHub's five alerts and the wider Obsidian vocabulary, matched
/// case-insensitively (`[!note]` and `[!NOTE]` are the same thing). A tag that
/// is not in `palette` is still a callout — it renders in the plain quote color
/// with its own name as the title — so a vault full of house-style tags reads
/// sensibly here instead of leaking `[!MYTAG]` into the prose.
///
/// Parsing splits the opening paragraph three ways: the marker itself (dropped),
/// the rest of that first line (the title, if any), and everything from the
/// following line on (body). Keeping them as markup rather than strings is what
/// lets a title carry inline styling — `> [!TIP] Use **--width**` renders bold.
struct Callout {

    /// The tag as written, upper-cased. Doubles as the title when none is given.
    let kind: String

    /// Inline markup making up the title, or empty to fall back to `kind`.
    let titleInlines: [Markup]

    /// The remainder of the opening paragraph — everything after the first line.
    let bodyInlines: [Markup]

    /// Blocks of the quote after the opening paragraph.
    let restBlocks: [Markup]

    /// `[!TAG]` at the head of the first line. The tag is deliberately loose —
    /// any word — because unknown tags are supported rather than rejected.
    private static let marker = try? NSRegularExpression(
        pattern: #"^\s*\[!([A-Za-z][A-Za-z0-9_-]*)\]"#)

    /// Which theme color each known tag draws. Tags that mean the same thing
    /// share one — `INFO` is a `NOTE`, `DANGER`/`FAILURE`/`BUG` are all the
    /// `CAUTION` red — so the palette stays a legible six rather than a rainbow
    /// nobody can tell apart at a glance.
    private static let palette: [String: KeyPath<Theme, Ansi.Color>] = [
        "NOTE": \.alertNote,
        "INFO": \.alertNote,
        "TODO": \.alertNote,
        "TIP": \.alertTip,
        "SUCCESS": \.alertTip,
        "IMPORTANT": \.alertImportant,
        "EXAMPLE": \.alertImportant,
        "WARNING": \.alertWarning,
        "CAUTION": \.alertCaution,
        "DANGER": \.alertCaution,
        "FAILURE": \.alertCaution,
        "BUG": \.alertCaution,
        "ABSTRACT": \.alertAbstract,
    ]

    /// Every tag with a color of its own, for docs and tests.
    static var knownKinds: [String] { palette.keys.sorted() }

    /// The bar / title color: the tag's own, or the plain quote color for a tag
    /// this build has never heard of.
    func color(_ theme: Theme) -> Ansi.Color {
        Self.palette[kind].map { theme[keyPath: $0] } ?? theme.quoteBar
    }

    /// Read a callout out of a blockquote, or nil if it does not open with a marker.
    static func parse(_ quote: BlockQuote) -> Callout? {
        let blocks = Array(quote.children)
        guard let paragraph = blocks.first as? Paragraph else { return nil }

        let inlines = Array(paragraph.children)
        guard let head = inlines.first as? Markdown.Text else { return nil }

        let text = head.string
        guard let marker,
              let match = marker.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let tag = Range(match.range(at: 1), in: text),
              let consumed = Range(match.range, in: text) else { return nil }

        // The title runs to the end of the marker's own line, so it ends at the
        // paragraph's first line break — not at the end of the paragraph, which
        // would swallow the body of every multi-line callout.
        let brk = inlines.firstIndex { $0 is SoftBreak || $0 is LineBreak }
        let sameLine = brk.map { Array(inlines[1 ..< $0]) } ?? Array(inlines.dropFirst())
        let rest = brk.map { Array(inlines[($0 + 1)...]) } ?? []

        // Leading space only: a trailing one is the gap before whatever inline
        // follows on the same line, and trimming it welded `[!TIP] Use **-w**`
        // into "Use-w".
        let leading = String(text[consumed.upperBound...].drop { $0 == " " || $0 == "\t" })
        let title: [Markup] = (leading.isEmpty ? [] : [Markdown.Text(leading)]) + sameLine

        return Callout(kind: text[tag].uppercased(), titleInlines: title,
                       bodyInlines: rest, restBlocks: Array(blocks.dropFirst()))
    }
}
