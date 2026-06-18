import Foundation
import Chroma

/// Syntax highlighting for code blocks, backed by the Chroma tokenizer.
///
/// We use Chroma purely as a *tokenizer* and render the colours ourselves with
/// `termdown`'s matte-pastel `Theme` and `Ansi` helpers — so highlighting stays
/// on-palette, honours `--no-color`, and flows through the same width / framing
/// logic as the rest of the renderer. Chroma brings ~35 languages (with the
/// usual fence aliases: `sh`→bash, `py`→python, `js`→javascript, …); anything it
/// doesn't recognise degrades to plain `codeText`.
public struct Highlighter {

    /// A color for every character of `code` (count matches the character count).
    /// Characters not covered by a coloured token — and all text when the language
    /// is unknown — get `theme.codeText`.
    public static func colorMap(_ code: String, language: String?, theme: Theme) -> [Ansi.Color] {
        let charCount = code.count
        guard charCount > 0 else { return [] }
        var colors = [Ansi.Color](repeating: theme.codeText, count: charCount)

        guard let langID = resolveLanguage(language),
              let tokens = try? Chroma.tokenize(code, language: langID) else {
            return colors
        }

        // Resolve colours in UTF-16 space (Chroma ranges are NSRanges), honouring
        // precedence so e.g. a keyword inside a string stays string-coloured.
        let ns = code as NSString
        let u16 = ns.length
        guard u16 > 0 else { return colors }
        var colorU16 = [Ansi.Color](repeating: theme.codeText, count: u16)
        var prioU16  = [Int](repeating: Int.max, count: u16)
        for token in tokens {
            guard let c = color(for: token.kind, theme: theme) else { continue }
            let p = priority(token.kind)
            let lo = max(0, token.range.location)
            let hi = min(u16, token.range.location + token.range.length)
            var i = lo
            while i < hi { if p < prioU16[i] { prioU16[i] = p; colorU16[i] = c }; i += 1 }
        }

        // Collapse UTF-16 colours down to one per Character (using each
        // character's first UTF-16 unit).
        var idx = 0
        var u16Index = 0
        for ch in code {
            colors[idx] = colorU16[min(u16Index, u16 - 1)]
            u16Index += ch.utf16.count
            idx += 1
        }

        // Chroma's shell grammar doesn't colour command names; do it ourselves so
        // `swift test` / `brew install …` read as commands rather than flat text.
        if ["bash", "sh", "zsh"].contains(langID.rawValue) {
            applyShellCommands(code, &colors, theme: theme)
        }
        return colors
    }

    /// Colour the leading command word at each command position (line start, or
    /// after `| & ; (`) as a function call — but only where Chroma left it plain,
    /// so keywords, strings and comments keep their colours.
    private static func applyShellCommands(_ code: String, _ colors: inout [Ansi.Color], theme: Theme) {
        let chars = Array(code)
        let n = chars.count
        func isCommandChar(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_" || c == "-" || c == "." || c == "/" || c == "+"
        }
        var i = 0
        var atStart = true
        while i < n {
            let ch = chars[i]
            if ch == "\n" || ch == ";" || ch == "|" || ch == "&" || ch == "(" { atStart = true; i += 1; continue }
            if ch == " " || ch == "\t" { i += 1; continue }
            guard atStart else { i += 1; continue }
            atStart = false
            // Skip a prompt marker ($ / #␠) but treat a bare leading # as a comment.
            if ch == "$" || ch == "#", i + 1 < n, chars[i + 1] == " " { i += 2; atStart = true; continue }
            if ch == "#" { i += 1; continue }
            let start = i
            while i < n, isCommandChar(chars[i]) { i += 1 }
            for k in start..<i where colors[k] == theme.codeText { colors[k] = theme.link }
        }
    }

    // MARK: - Token → theme mapping

    /// Token precedence when ranges overlap (lower wins).
    private static func priority(_ kind: TokenKind) -> Int {
        switch kind {
        case .comment:  return 0
        case .string:   return 1
        case .keyword:  return 2
        case .type:     return 3
        case .function: return 3
        case .number:   return 4
        default:        return Int.max   // plain / operator / punctuation / property
        }
    }

    private static func color(for kind: TokenKind, theme: Theme) -> Ansi.Color? {
        switch kind {
        case .keyword:  return theme.keyword
        case .string:   return theme.string
        case .number:   return theme.number
        case .comment:  return theme.comment
        case .type:     return theme.type
        case .function: return theme.link    // call sites pop in soft blue
        default:        return nil            // plain / operator / punctuation / property → codeText
        }
    }

    // MARK: - Language resolution

    /// Map a Markdown fence info-string to a Chroma `LanguageID`. Chroma already
    /// registers the common aliases (`sh`, `py`, `js`, `yml`, `cpp`/`c++`, …); we
    /// add a few fence synonyms it doesn't, and treat plain-text fences as nil so
    /// they render uncoloured.
    private static func resolveLanguage(_ language: String?) -> LanguageID? {
        guard let raw = language?.lowercased().trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        let synonyms: [String: String] = [
            "shell": "bash", "console": "bash", "shellsession": "bash", "shell-session": "bash", "fish": "bash",
            "node": "javascript", "c#": "csharp", "cc": "cpp", "hpp": "cpp", "h": "c",
            "jsonc": "json", "json5": "json", "svg": "xml", "plist": "xml", "vue": "html",
            "text": "", "plaintext": "", "plain": "", "txt": "", "": "",
        ]
        let id = synonyms[raw] ?? raw
        guard !id.isEmpty else { return nil }
        return LanguageID(rawValue: id)
    }
}
