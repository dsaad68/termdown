extension MathConverter {

    // MARK: - \frac

    static func expandFrac(_ s: String) -> String {
        var cur = s
        for _ in 0..<8 {
            let chars = Array(cur)
            guard let m = firstFrac(chars) else { break }
            let a = m.a.count <= 1 ? m.a : "(" + m.a + ")"
            let b = m.b.count <= 1 ? m.b : "(" + m.b + ")"
            cur = String(chars[0..<m.start]) + a + "/" + b + String(chars[m.end...])
        }
        return cur
    }

    /// Locate the first `\frac{A}{B}`, returning the slice bounds and arguments.
    static func firstFrac(_ chars: [Character]) -> (start: Int, end: Int, a: String, b: String)? {
        var i = 0
        while i < chars.count {
            if matchesCommand(chars, i, "frac") {
                var p = i + 5  // past "\frac"
                while p < chars.count, chars[p] == " " { p += 1 }
                guard p < chars.count, chars[p] == "{", let aClose = matchBrace(chars, p) else { i += 1; continue }
                var q = aClose + 1
                while q < chars.count, chars[q] == " " { q += 1 }
                guard q < chars.count, chars[q] == "{", let bClose = matchBrace(chars, q) else { i += 1; continue }
                let a = String(chars[(p + 1)..<aClose])
                let b = String(chars[(q + 1)..<bClose])
                return (i, bClose + 1, a, b)
            }
            i += 1
        }
        return nil
    }
}
