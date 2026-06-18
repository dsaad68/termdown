extension MathConverter {

    // MARK: - Command / symbol replacement

    /// Replace `\name` command tokens with their Unicode symbol; unknown
    /// commands fall back to the bare name, and `\{`, `\}`, `\%` etc. to the
    /// escaped character.
    static func replaceCommands(_ s: String) -> String {
        let chars = Array(s)
        var out = ""
        var i = 0
        while i < chars.count {
            if chars[i] == "\\" {
                var j = i + 1
                var name = ""
                while j < chars.count, chars[j].isLetter { name.append(chars[j]); j += 1 }
                if name.isEmpty {
                    if j < chars.count, "{}%&#_ ".contains(chars[j]) {
                        out.append(chars[j]); i = j + 1; continue
                    }
                    out.append("\\"); i += 1; continue
                }
                out += symbols[name] ?? name
                i = j; continue
            }
            out.append(chars[i]); i += 1
        }
        return out
    }

    static func blackboard(_ s: String) -> String {
        String(s.map { blackboardLetters[$0] ?? $0 })
    }

    // MARK: - Symbol tables

    static let blackboardLetters: [Character: Character] = [
        "C": "\u{2102}", "H": "\u{210D}", "N": "\u{2115}", "P": "\u{2119}",
        "Q": "\u{211A}", "R": "\u{211D}", "Z": "\u{2124}",
    ]

    static let symbols: [String: String] = [
        // Lowercase Greek
        "alpha": "\u{03B1}", "beta": "\u{03B2}", "gamma": "\u{03B3}", "delta": "\u{03B4}",
        "epsilon": "\u{03B5}", "varepsilon": "\u{03B5}", "zeta": "\u{03B6}", "eta": "\u{03B7}",
        "theta": "\u{03B8}", "vartheta": "\u{03D1}", "iota": "\u{03B9}", "kappa": "\u{03BA}",
        "lambda": "\u{03BB}", "mu": "\u{03BC}", "nu": "\u{03BD}", "xi": "\u{03BE}",
        "omicron": "\u{03BF}", "pi": "\u{03C0}", "varpi": "\u{03D6}", "rho": "\u{03C1}",
        "varrho": "\u{03F1}", "sigma": "\u{03C3}", "varsigma": "\u{03C2}", "tau": "\u{03C4}",
        "upsilon": "\u{03C5}", "phi": "\u{03C6}", "varphi": "\u{03D5}", "chi": "\u{03C7}",
        "psi": "\u{03C8}", "omega": "\u{03C9}",
        // Uppercase Greek
        "Gamma": "\u{0393}", "Delta": "\u{0394}", "Theta": "\u{0398}", "Lambda": "\u{039B}",
        "Xi": "\u{039E}", "Pi": "\u{03A0}", "Sigma": "\u{03A3}", "Upsilon": "\u{03A5}",
        "Phi": "\u{03A6}", "Psi": "\u{03A8}", "Omega": "\u{03A9}",
        // Relations
        "leq": "\u{2264}", "le": "\u{2264}", "geq": "\u{2265}", "ge": "\u{2265}",
        "neq": "\u{2260}", "ne": "\u{2260}", "equiv": "\u{2261}", "approx": "\u{2248}",
        "cong": "\u{2245}", "sim": "\u{223C}", "simeq": "\u{2243}", "propto": "\u{221D}",
        "ll": "\u{226A}", "gg": "\u{226B}", "prec": "\u{227A}", "succ": "\u{227B}",
        "subset": "\u{2282}", "supset": "\u{2283}", "subseteq": "\u{2286}", "supseteq": "\u{2287}",
        "in": "\u{2208}", "notin": "\u{2209}", "ni": "\u{220B}", "perp": "\u{22A5}",
        "parallel": "\u{2225}", "mid": "\u{2223}",
        // Binary operators
        "times": "\u{00D7}", "div": "\u{00F7}", "pm": "\u{00B1}", "mp": "\u{2213}",
        "cdot": "\u{00B7}", "ast": "\u{2217}", "star": "\u{22C6}", "circ": "\u{2218}",
        "bullet": "\u{2022}", "oplus": "\u{2295}", "ominus": "\u{2296}", "otimes": "\u{2297}",
        "oslash": "\u{2298}", "odot": "\u{2299}", "cup": "\u{222A}", "cap": "\u{2229}",
        "wedge": "\u{2227}", "vee": "\u{2228}", "setminus": "\u{2216}", "amalg": "\u{2A3F}",
        // Big operators
        "sum": "\u{2211}", "prod": "\u{220F}", "coprod": "\u{2210}", "int": "\u{222B}",
        "oint": "\u{222E}", "iint": "\u{222C}", "bigcup": "\u{22C3}", "bigcap": "\u{22C2}",
        "bigoplus": "\u{2A01}", "bigotimes": "\u{2A02}",
        // Arrows
        "rightarrow": "\u{2192}", "to": "\u{2192}", "leftarrow": "\u{2190}", "gets": "\u{2190}",
        "leftrightarrow": "\u{2194}", "Rightarrow": "\u{21D2}", "implies": "\u{21D2}",
        "Leftarrow": "\u{21D0}", "Leftrightarrow": "\u{21D4}", "iff": "\u{21D4}",
        "mapsto": "\u{21A6}", "longrightarrow": "\u{27F6}", "longleftarrow": "\u{27F5}",
        "uparrow": "\u{2191}", "downarrow": "\u{2193}", "hookrightarrow": "\u{21AA}",
        // Logic / sets / misc symbols
        "forall": "\u{2200}", "exists": "\u{2203}", "nexists": "\u{2204}", "neg": "\u{00AC}",
        "lnot": "\u{00AC}", "land": "\u{2227}", "lor": "\u{2228}", "emptyset": "\u{2205}",
        "varnothing": "\u{2205}", "infty": "\u{221E}", "partial": "\u{2202}", "nabla": "\u{2207}",
        "angle": "\u{2220}", "triangle": "\u{25B3}", "square": "\u{25A1}", "diamond": "\u{22C4}",
        "therefore": "\u{2234}", "because": "\u{2235}", "aleph": "\u{2135}", "hbar": "\u{210F}",
        "ell": "\u{2113}", "Re": "\u{211C}", "Im": "\u{2111}", "wp": "\u{2118}", "Box": "\u{25A1}",
        "top": "\u{22A4}", "bot": "\u{22A5}", "vdash": "\u{22A2}", "models": "\u{22A8}",
        // Dots, primes, delimiters, accents-as-symbols
        "ldots": "\u{2026}", "dots": "\u{2026}", "cdots": "\u{22EF}", "vdots": "\u{22EE}",
        "ddots": "\u{22F1}", "prime": "\u{2032}", "langle": "\u{27E8}", "rangle": "\u{27E9}",
        "lfloor": "\u{230A}", "rfloor": "\u{230B}", "lceil": "\u{2308}", "rceil": "\u{2309}",
        "degree": "\u{00B0}", "deg": "\u{00B0}", "surd": "\u{221A}", "checkmark": "\u{2713}",
        "backslash": "\\", "%": "%", "&": "&", "#": "#", "_": "_", "{": "{", "}": "}",
        // Common function names — keep as plain words.
        "sin": "sin", "cos": "cos", "tan": "tan", "log": "log", "ln": "ln", "exp": "exp",
        "lim": "lim", "max": "max", "min": "min", "det": "det", "gcd": "gcd",
    ]
}
