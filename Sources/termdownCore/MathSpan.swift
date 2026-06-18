extension MathConverter {

    // MARK: - Span detection

    /// Split a run of text into alternating plain / math segments, detecting
    /// `$…$` (inline) and `$$…$$` (display) spans. The inline heuristic is
    /// currency-safe: a `$` only opens math when the next character is neither a
    /// space nor a digit, and only closes when the previous character isn't a
    /// space and the following one isn't a digit — so `it costs $5 and $10` is
    /// left untouched. Returns segments as `(text, isMath)`.
    public static func split(_ s: String) -> [(text: String, isMath: Bool)] {
        guard s.contains("$") else { return [(s, false)] }
        let chars = Array(s)
        let n = chars.count
        var out: [(String, Bool)] = []
        var plain = ""
        var i = 0
        func flushPlain() { if !plain.isEmpty { out.append((plain, false)); plain = "" } }

        while i < n {
            let c = chars[i]
            // Escaped dollar -> literal $.
            if c == "\\", i + 1 < n, chars[i + 1] == "$" {
                plain.append("$"); i += 2; continue
            }
            if c == "$" {
                if i + 1 < n, chars[i + 1] == "$" {
                    // Display math $$…$$
                    if let close = findDisplayClose(chars, from: i + 2) {
                        flushPlain()
                        out.append((String(chars[(i + 2)..<close]), true))
                        i = close + 2; continue
                    }
                } else if i + 1 < n, chars[i + 1] != " ", chars[i + 1] != "$", !chars[i + 1].isNumber {
                    // Inline math $…$ (currency-safe).
                    if let close = findInlineClose(chars, from: i + 1) {
                        flushPlain()
                        out.append((String(chars[(i + 1)..<close]), true))
                        i = close + 1; continue
                    }
                }
            }
            plain.append(c); i += 1
        }
        flushPlain()
        return out
    }

    static func findDisplayClose(_ chars: [Character], from: Int) -> Int? {
        var i = from
        while i + 1 < chars.count {
            if chars[i] == "$" && chars[i + 1] == "$" { return i }
            i += 1
        }
        return nil
    }

    static func findInlineClose(_ chars: [Character], from: Int) -> Int? {
        var i = from
        while i < chars.count {
            let c = chars[i]
            if c == "\n" { return nil }
            if c == "$" {
                let prevOK = i > 0 && chars[i - 1] != " "
                let nextOK = i + 1 >= chars.count || !chars[i + 1].isNumber
                if prevOK && nextOK && i > from { return i }
            }
            i += 1
        }
        return nil
    }
}
