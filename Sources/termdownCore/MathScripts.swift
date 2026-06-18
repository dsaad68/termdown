extension MathConverter {

    // MARK: - Scripts (^ / _)

    /// Convert `^arg` / `_arg` (braced or single char) to Unicode scripts, with
    /// a `^(arg)` / `_(arg)` fallback when a character has no script form.
    static func applyScripts(_ s: String) -> String {
        let chars = Array(s)
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "^" || c == "_" {
                let sup = c == "^"
                var arg = ""
                if i + 1 < chars.count, chars[i + 1] == "{", let close = matchBrace(chars, i + 1) {
                    arg = String(chars[(i + 2)..<close]); i = close + 1
                } else if i + 1 < chars.count {
                    arg = String(chars[i + 1]); i += 2
                } else {
                    out.append(c); i += 1; continue
                }
                if let mapped = mapScript(arg, superscript: sup) {
                    out += mapped
                } else {
                    out += (sup ? "^" : "_") + (arg.count == 1 ? arg : "(" + arg + ")")
                }
                continue
            }
            out.append(c); i += 1
        }
        return out
    }

    static func mapScript(_ arg: String, superscript sup: Bool) -> String? {
        let table = sup ? superscripts : subscripts
        var result = ""
        for ch in arg {
            if ch == " " { result += " "; continue }
            guard let mapped = table[ch] else { return nil }
            result.append(mapped)
        }
        return result.isEmpty ? nil : result
    }

    // MARK: - Script tables

    static let superscripts: [Character: Character] = [
        "0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}", "4": "\u{2074}",
        "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}", "8": "\u{2078}", "9": "\u{2079}",
        "+": "\u{207A}", "-": "\u{207B}", "=": "\u{207C}", "(": "\u{207D}", ")": "\u{207E}",
        "a": "\u{1D43}", "b": "\u{1D47}", "c": "\u{1D9C}", "d": "\u{1D48}", "e": "\u{1D49}",
        "f": "\u{1DA0}", "g": "\u{1D4D}", "h": "\u{02B0}", "i": "\u{2071}", "j": "\u{02B2}",
        "k": "\u{1D4F}", "l": "\u{02E1}", "m": "\u{1D50}", "n": "\u{207F}", "o": "\u{1D52}",
        "p": "\u{1D56}", "r": "\u{02B3}", "s": "\u{02E2}", "t": "\u{1D57}", "u": "\u{1D58}",
        "v": "\u{1D5B}", "w": "\u{02B7}", "x": "\u{02E3}", "y": "\u{02B8}", "z": "\u{1DBB}",
    ]

    static let subscripts: [Character: Character] = [
        "0": "\u{2080}", "1": "\u{2081}", "2": "\u{2082}", "3": "\u{2083}", "4": "\u{2084}",
        "5": "\u{2085}", "6": "\u{2086}", "7": "\u{2087}", "8": "\u{2088}", "9": "\u{2089}",
        "+": "\u{208A}", "-": "\u{208B}", "=": "\u{208C}", "(": "\u{208D}", ")": "\u{208E}",
        "a": "\u{2090}", "e": "\u{2091}", "h": "\u{2095}", "i": "\u{1D62}", "j": "\u{2C7C}",
        "k": "\u{2096}", "l": "\u{2097}", "m": "\u{2098}", "n": "\u{2099}", "o": "\u{2092}",
        "p": "\u{209A}", "r": "\u{1D63}", "s": "\u{209B}", "t": "\u{209C}", "u": "\u{1D64}",
        "v": "\u{1D65}", "x": "\u{2093}",
    ]
}
