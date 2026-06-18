extension MathConverter {

    // MARK: - Brace / command parsing

    /// Index of the `}` matching the `{` at `open`, or nil.
    static func matchBrace(_ chars: [Character], _ open: Int) -> Int? {
        var depth = 0
        var i = open
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            else if chars[i] == "}" { depth -= 1; if depth == 0 { return i } }
            i += 1
        }
        return nil
    }

    /// Whether `\command` starts at `i` (the command name not running into more
    /// letters, so `\text` doesn't match inside `\textbf`).
    static func matchesCommand(_ chars: [Character], _ i: Int, _ command: String) -> Bool {
        let token = Array("\\" + command)
        guard i + token.count <= chars.count else { return false }
        for k in 0..<token.count where chars[i + k] != token[k] { return false }
        let after = i + token.count
        if after < chars.count, chars[after].isLetter { return false }
        return true
    }

    /// Replace every `\command{arg}` with `f(arg)`.
    static func expandCommandArg(_ s: String, command: String, _ f: (String) -> String) -> String {
        let chars = Array(s)
        var out = ""
        var i = 0
        let nameLen = command.count + 1   // backslash + name
        while i < chars.count {
            if matchesCommand(chars, i, command), i + nameLen < chars.count, chars[i + nameLen] == "{",
               let close = matchBrace(chars, i + nameLen) {
                out += f(String(chars[(i + nameLen + 1)..<close]))
                i = close + 1
                continue
            }
            out.append(chars[i]); i += 1
        }
        return out
    }
}
