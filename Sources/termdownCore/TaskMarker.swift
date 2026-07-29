import Foundation

/// Flipping a GFM task-list checkbox (`- [ ]` ⇄ `- [x]`) on a raw source line.
///
/// Kept as a pure string transform, separate from the pager, so the parsing
/// rules are testable on their own. The renderer decides what *is* a checkbox
/// (swift-markdown's `ListItem.checkbox`); this only has the raw line to go on,
/// so it re-derives the shape conservatively and returns nil rather than
/// rewriting a line it isn't sure about.
public enum TaskMarker {

    /// The state of a checkbox found on a source line.
    public enum State {
        case checked
        case unchecked
    }

    /// Toggle the checkbox on `line`, preserving indentation, bullet style and
    /// spacing exactly. Returns nil when the line is not a task list item.
    ///
    /// Unchecking always writes `[ ]`; checking always writes `[x]` (lowercase),
    /// which is what GitHub emits — a pre-existing `[X]` is accepted on the way
    /// in but not preserved on the way out.
    public static func toggle(_ line: String) -> String? {
        guard let box = checkboxIndex(in: line) else { return nil }
        var chars = Array(line)
        chars[box + 1] = chars[box + 1] == " " ? "x" : " "
        return String(chars)
    }

    /// The current state of the checkbox on `line`, or nil if there isn't one.
    public static func state(of line: String) -> State? {
        guard let box = checkboxIndex(in: line) else { return nil }
        return Array(line)[box + 1] == " " ? .unchecked : .checked
    }

    /// Index of the opening `[` of a task checkbox on `line`, or nil.
    ///
    /// Matches `<indent><bullet><space+>[ x]<space or end>`, where bullet is
    /// `-`/`*`/`+` or `<digits>.`/`<digits>)`. The trailing-whitespace rule is
    /// what keeps a line like `- [link](url)` from being mistaken for a
    /// checkbox: `[l` fails the single-character test first, but `- [x](url)`
    /// would otherwise slip through.
    private static func checkboxIndex(in line: String) -> Int? {
        let chars = Array(line)
        var i = 0

        while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }

        // Bullet: -, * or + ...
        if i < chars.count, chars[i] == "-" || chars[i] == "*" || chars[i] == "+" {
            i += 1
        } else {
            // ... or an ordered marker: digits followed by . or )
            var j = i
            while j < chars.count, chars[j].isASCII, chars[j].isNumber { j += 1 }
            guard j > i, j < chars.count, chars[j] == "." || chars[j] == ")" else { return nil }
            i = j + 1
        }

        // At least one space between the bullet and the checkbox.
        guard i < chars.count, chars[i] == " " || chars[i] == "\t" else { return nil }
        while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }

        guard i + 2 < chars.count, chars[i] == "[", chars[i + 2] == "]" else { return nil }
        let mark = chars[i + 1]
        guard mark == " " || mark == "x" || mark == "X" else { return nil }

        // The closing bracket must be followed by whitespace or end-of-line, so
        // `- [x](url)` stays a link and `- [ ]` on its own still toggles.
        let after = i + 3
        if after < chars.count, chars[after] != " ", chars[after] != "\t" { return nil }

        return i
    }
}
