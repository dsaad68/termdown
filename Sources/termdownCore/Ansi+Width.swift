import Foundation

/// Display-width measurement, ANSI stripping, padding, slicing and
/// truncation. Split out of `Ansi.swift`, which sits on the 400-line lint
/// ceiling. `scalarWidth` is file-private, so its only callers — `width` and
/// `charWidth` — must live here with it.
extension Ansi {

    // MARK: - Width handling

    /// Remove SGR and OSC escape sequences, leaving only visible characters.
    public static func strip(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        let scalars = Array(s.unicodeScalars)
        var i = 0
        let n = scalars.count
        while i < n {
            let c = scalars[i]
            if c == "\u{1B}" {
                let next = i + 1 < n ? scalars[i + 1] : "\0"
                if next == "[" {
                    // CSI: ESC [ ... final byte in 0x40-0x7E
                    i += 2
                    while i < n {
                        let v = scalars[i].value
                        i += 1
                        if v >= 0x40 && v <= 0x7E { break }
                    }
                    continue
                } else if next == "]" {
                    // OSC: ESC ] ... terminated by BEL or ESC \
                    i += 2
                    while i < n {
                        if scalars[i] == "\u{07}" { i += 1; break }
                        if scalars[i] == "\u{1B}", i + 1 < n, scalars[i + 1] == "\\" { i += 2; break }
                        i += 1
                    }
                    continue
                } else {
                    i += 1
                    continue
                }
            }
            out.append(c)
            i += 1
        }
        return String(out)
    }

    /// Visible display width in terminal cells (handles common wide characters).
    public static func width(_ s: String) -> Int {
        var w = 0
        for scalar in strip(s).unicodeScalars {
            w += scalarWidth(scalar)
        }
        return w
    }

    public static func charWidth(_ c: Character) -> Int {
        c.unicodeScalars.reduce(0) { $0 + scalarWidth($1) }
    }

    private static func scalarWidth(_ s: Unicode.Scalar) -> Int {
        let v = s.value
        if v == 0 { return 0 }
        // Zero-width: combining marks, zero-width spaces/joiners, BOM, and the
        // variation selectors (incl. U+FE0F, which selects emoji presentation but
        // adds no column of its own).
        if (0x0300...0x036F).contains(v) || (0x200B...0x200F).contains(v) ||
           (0xFE00...0xFE0F).contains(v) || v == 0xFEFF {
            return 0
        }
        // Wide (CJK, Hangul, fullwidth, common emoji blocks)
        if (0x1100...0x115F).contains(v) ||      // Hangul Jamo
           (0x2E80...0xA4CF).contains(v) ||      // CJK
           (0xAC00...0xD7A3).contains(v) ||      // Hangul syllables
           (0xF900...0xFAFF).contains(v) ||      // CJK compat
           (0xFE30...0xFE4F).contains(v) ||      // CJK compat forms
           (0xFF00...0xFF60).contains(v) ||      // Fullwidth forms
           (0xFFE0...0xFFE6).contains(v) ||
           (0x1F300...0x1FAFF).contains(v) ||    // emoji / symbols
           (0x20000...0x3FFFD).contains(v) {     // CJK extensions
            return 2
        }
        // Emoji_Presentation=Yes code points that live below U+1F300, which
        // terminals render double-width even though legacy wcwidth tables call
        // them single-width. Miscounting these by one column overflows a padded
        // row and corrupts the full-screen redraw (e.g. ✅ U+2705, ⭐ U+2B50).
        if (0x231A...0x231B).contains(v) || (0x23E9...0x23EC).contains(v) ||
           v == 0x23F0 || v == 0x23F3 || (0x25FD...0x25FE).contains(v) ||
           (0x2614...0x2615).contains(v) || (0x2648...0x2653).contains(v) ||
           v == 0x267F || v == 0x2693 || v == 0x26A1 ||
           (0x26AA...0x26AB).contains(v) || (0x26BD...0x26BE).contains(v) ||
           (0x26C4...0x26C5).contains(v) || v == 0x26CE || v == 0x26D4 ||
           v == 0x26EA || (0x26F2...0x26F3).contains(v) || v == 0x26F5 ||
           v == 0x26FA || v == 0x26FD || v == 0x2705 ||
           (0x270A...0x270B).contains(v) || v == 0x2728 || v == 0x274C ||
           v == 0x274E || (0x2753...0x2755).contains(v) || v == 0x2757 ||
           (0x2795...0x2797).contains(v) || v == 0x27B0 || v == 0x27BF ||
           (0x2B1B...0x2B1C).contains(v) || v == 0x2B50 || v == 0x2B55 {
            return 2
        }
        return 1
    }

    /// Pad a (possibly styled) string to `target` visible width.
    public static func pad(_ s: String, to target: Int, align: TextAlign = .left) -> String {
        let w = width(s)
        if w >= target { return s }
        let total = target - w
        switch align {
        case .left:
            return s + String(repeating: " ", count: total)
        case .right:
            return String(repeating: " ", count: total) + s
        case .center:
            let left = total / 2
            let right = total - left
            return String(repeating: " ", count: left) + s + String(repeating: " ", count: right)
        }
    }

    /// Return the visible columns `[start, start + width)` of a styled string,
    /// preserving SGR (color/style) attributes that are active at the slice
    /// start. OSC sequences (e.g. hyperlinks) are dropped — used for no-wrap
    /// horizontal scrolling where carrying OSC state across a cut is unsafe.
    public static func horizontalSlice(_ s: String, start: Int, width: Int) -> String {
        guard width > 0 else { return "" }
        let chars = Array(s)
        let n = chars.count
        var i = 0
        var col = 0
        let end = start + width
        var active = ""        // SGR sequences active since the last reset
        var started = false
        var out = ""

        while i < n {
            let c = chars[i]
            if c == "\u{1B}" {
                if i + 1 < n && chars[i + 1] == "[" {
                    var seq = "\u{1B}["
                    i += 2
                    while i < n {
                        seq.append(chars[i])
                        let v = chars[i].unicodeScalars.first!.value
                        i += 1
                        if v >= 0x40 && v <= 0x7E { break }
                    }
                    if seq.hasSuffix("m") {
                        if seq == "\u{1B}[0m" || seq == "\u{1B}[m" {
                            active = ""
                            if started { out += "\u{1B}[0m" }
                        } else {
                            active += seq
                            if started { out += seq }
                        }
                    }
                    continue
                } else if i + 1 < n && chars[i + 1] == "]" {
                    // OSC: skip up to the string terminator (BEL or ESC \).
                    i += 2
                    while i < n {
                        if chars[i] == "\u{07}" { i += 1; break }
                        if chars[i] == "\u{1B}" && i + 1 < n && chars[i + 1] == "\\" { i += 2; break }
                        i += 1
                    }
                    continue
                } else {
                    i += 1
                    continue
                }
            }
            if col >= start && col < end {
                if !started {
                    if colorEnabled && !active.isEmpty { out += active }
                    started = true
                }
                out.append(c)
            }
            col += charWidth(c)
            if col >= end { break }
            i += 1
        }
        if started && !active.isEmpty { out += reset }
        return out
    }

    /// Truncate a styled string to a maximum visible width, appending an ellipsis.
    public static func truncate(_ s: String, to maxWidth: Int) -> String {
        guard maxWidth > 0 else { return "" }
        if width(s) <= maxWidth { return s }
        // Fall back to stripping styles for a safe truncation.
        let plain = strip(s)
        var result = ""
        var w = 0
        for ch in plain {
            let cw = charWidth(ch)
            if w + cw > maxWidth - 1 { break }
            result.append(ch)
            w += cw
        }
        return result + "\u{2026}"
    }

    public enum TextAlign { case left, center, right }
}
