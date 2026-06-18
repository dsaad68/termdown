import Foundation

/// Converts a subset of LaTeX math notation to Unicode so inline (`$…$`) and
/// display (`$$…$$`) math render legibly in a terminal without a typesetting
/// engine. Handles Greek letters, common operators / relations, super- and
/// subscripts, `\frac`, `\sqrt`, blackboard letters and a few wrappers
/// (`\text`, `\mathrm`, `\left`/`\right`). Unknown commands degrade gracefully
/// to their bare name rather than disappearing.
///
/// The implementation is split across focused files:
/// - `MathSpan.swift` — `$…$` / `$$…$$` span detection (currency-safe).
/// - `MathParser.swift` — brace matching and `\command{arg}` expansion.
/// - `MathFraction.swift` — `\frac` expansion.
/// - `MathSymbols.swift` — `\name` → symbol replacement + the symbol tables.
/// - `MathScripts.swift` — `^` / `_` scripts + the super/subscript tables.
public enum MathConverter {

    // MARK: - LaTeX -> Unicode

    /// Convert a LaTeX math fragment (without the surrounding `$`) to Unicode.
    public static func latexToUnicode(_ input: String) -> String {
        var s = input

        // Wrappers that expand to (a transform of) their single braced argument.
        s = expandCommandArg(s, command: "text") { $0 }
        s = expandCommandArg(s, command: "mathrm") { $0 }
        s = expandCommandArg(s, command: "mathbf") { $0 }
        s = expandCommandArg(s, command: "boldsymbol") { $0 }
        s = expandCommandArg(s, command: "operatorname") { $0 }
        s = expandCommandArg(s, command: "mathbb") { blackboard($0) }
        s = expandCommandArg(s, command: "sqrt") { inner in
            "\u{221A}" + (inner.count == 1 ? inner : "(" + inner + ")")  // √
        }

        // Accents: \hat{x} -> x̂ etc. (combining mark after each character).
        let accents: [(String, String)] = [
            ("widehat", "\u{0302}"), ("widetilde", "\u{0303}"), ("hat", "\u{0302}"),
            ("tilde", "\u{0303}"), ("bar", "\u{0304}"), ("overline", "\u{0305}"),
            ("vec", "\u{20D7}"), ("dot", "\u{0307}"), ("ddot", "\u{0308}"),
        ]
        for (cmd, mark) in accents {
            s = expandCommandArg(s, command: cmd) { inner in
                replaceCommands(inner).map { String($0) + mark }.joined()
            }
        }

        // \frac{a}{b}  (innermost first, a few passes for nesting).
        s = expandFrac(s)

        // \left( \right] etc. — drop the sizing command, keep the delimiter.
        s = s.replacingOccurrences(of: "\\left", with: "")
             .replacingOccurrences(of: "\\right", with: "")

        // Spacing commands collapse to a single space.
        for sp in ["\\,", "\\;", "\\:", "\\!", "\\quad", "\\qquad", "\\ "] {
            s = s.replacingOccurrences(of: sp, with: " ")
        }

        // Named symbols / Greek letters.
        s = replaceCommands(s)

        // Superscripts (^) and subscripts (_).
        s = applyScripts(s)

        // Strip any leftover grouping braces.
        s = s.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        return s.trimmingCharacters(in: .whitespaces)
    }
}
