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

    /// How emoji clusters are measured. `cluster` (the default) is correct for
    /// terminals that render a ZWJ sequence as one glyph — iTerm2, WezTerm,
    /// Kitty, VTE and modern tmux. `scalar` restores the legacy sum-the-scalars
    /// behavior for a terminal that draws the components separately.
    public enum EmojiWidthMode {
        case cluster
        case scalar
    }

    public static var emojiWidthMode: EmojiWidthMode = .cluster

    /// Visible display width in terminal cells.
    ///
    /// Iterates grapheme clusters, not scalars: a ZWJ sequence like 👨‍👩‍👧 is one
    /// glyph occupying two cells, and summing its parts counted six. Anything
    /// that measures a row — padding, wrapping, table columns, the frame-width
    /// invariant — depends on this agreeing with what the terminal draws.
    public static func width(_ s: String) -> Int {
        var w = 0
        for ch in strip(s) {
            w += charWidth(ch)
        }
        return w
    }

    /// Display width of a single grapheme cluster. This is the per-cell advance
    /// used by `horizontalSlice` and `bgRange`, so it must agree with `width` or
    /// tinted cells drift from the text they cover.
    public static func charWidth(_ c: Character) -> Int {
        let scalars = Array(c.unicodeScalars)
        guard emojiWidthMode == .cluster, scalars.count > 1 else {
            return scalars.reduce(0) { $0 + scalarWidth($1) }
        }
        // A cluster carrying emoji-sequence evidence is one glyph, two cells:
        //   ZWJ            👨‍👩‍👧 — components joined into a single glyph
        //   skin tone      👍🏽  — the modifier adds no column
        //   VS16           ❤️  — selects emoji presentation of a narrow base,
        //                        which the scalar table alone scores as 1
        //   regional pair  🇺🇸  — two indicators, one flag
        var sawZWJ = false
        var sawModifier = false
        var sawVS16 = false
        var regionalIndicators = 0
        for s in scalars {
            switch s.value {
            case 0x200D: sawZWJ = true
            case 0x1F3FB...0x1F3FF: sawModifier = true
            case 0xFE0F: sawVS16 = true
            case 0x1F1E6...0x1F1FF: regionalIndicators += 1
            default: break
            }
        }
        if sawZWJ || sawModifier || sawVS16 || regionalIndicators >= 2 { return 2 }
        return scalars.reduce(0) { $0 + scalarWidth($1) }
    }

    private static func scalarWidth(_ s: Unicode.Scalar) -> Int {
        let v = s.value
        if v == 0 { return 0 }
        if inRanges(v, zeroWidthRanges) { return 0 }
        if inRanges(v, wideRanges) { return 2 }
        return 1
    }

    private static func inRanges(_ v: UInt32, _ ranges: [(UInt32, UInt32)]) -> Bool {
        // Ranges are sorted and disjoint; binary search.
        var lo = 0
        var hi = ranges.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let (start, end) = ranges[mid]
            if v < start { hi = mid - 1 } else if v > end { lo = mid + 1 } else { return true }
        }
        return false
    }

    // Combining marks across every script (not just Latin — a Hebrew, Arabic,
    // Devanagari or Thai mark occupies no column either), zero-width
    // spaces/joiners, the BOM, and the variation selectors (incl. U+FE0F, which
    // selects emoji presentation but adds no column itself).
    //
    // Byte-for-byte identical to `DisplayWidth.zeroWidthRanges` in
    // MermaidRenderer — see the note on `charWidth`. Edit both or a diagram's
    // borders drift from the rows around it.
    private static let zeroWidthRanges: [(UInt32, UInt32)] = [
        (0x0300, 0x036F), (0x0483, 0x0489), (0x0591, 0x05BD), (0x05BF, 0x05BF),
        (0x05C1, 0x05C2), (0x05C4, 0x05C5), (0x05C7, 0x05C7), (0x0610, 0x061A),
        (0x064B, 0x065F), (0x0670, 0x0670), (0x06D6, 0x06DC), (0x06DF, 0x06E4),
        (0x06E7, 0x06E8), (0x06EA, 0x06ED), (0x0711, 0x0711), (0x0730, 0x074A),
        (0x07A6, 0x07B0), (0x07EB, 0x07F3), (0x0816, 0x0819), (0x081B, 0x0823),
        (0x0825, 0x0827), (0x0829, 0x082D), (0x0859, 0x085B), (0x08E3, 0x0902),
        (0x093A, 0x093A), (0x093C, 0x093C), (0x0941, 0x0948), (0x094D, 0x094D),
        (0x0951, 0x0957), (0x0962, 0x0963), (0x0E31, 0x0E31), (0x0E34, 0x0E3A),
        (0x0E47, 0x0E4E), (0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x2064),
        (0x20D0, 0x20F0), (0xFE00, 0xFE0F), (0xFE20, 0xFE2F), (0xFEFF, 0xFEFF),
        (0x1AB0, 0x1AFF), (0x1DC0, 0x1DFF), (0xE0100, 0xE01EF),
    ]

    // East-Asian Wide / Fullwidth, plus the Emoji_Presentation=Yes code points
    // below U+1F300 that terminals draw double-width even though legacy wcwidth
    // tables call them narrow. Miscounting one of those by a column overflows a
    // padded row and corrupts the full-screen redraw (e.g. ✅ U+2705, ⭐ U+2B50).
    //
    // Identical to `DisplayWidth.wideRanges` — same caveat as above.
    private static let wideRanges: [(UInt32, UInt32)] = [
        (0x1100, 0x115F), (0x231A, 0x231B), (0x2329, 0x232A), (0x23E9, 0x23EC),
        (0x23F0, 0x23F0), (0x23F3, 0x23F3), (0x25FD, 0x25FE), (0x2614, 0x2615),
        (0x2648, 0x2653), (0x267F, 0x267F), (0x2693, 0x2693), (0x26A1, 0x26A1),
        (0x26AA, 0x26AB), (0x26BD, 0x26BE), (0x26C4, 0x26C5), (0x26CE, 0x26CE),
        (0x26D4, 0x26D4), (0x26EA, 0x26EA), (0x26F2, 0x26F3), (0x26F5, 0x26F5),
        (0x26FA, 0x26FA), (0x26FD, 0x26FD), (0x2705, 0x2705), (0x270A, 0x270B),
        (0x2728, 0x2728), (0x274C, 0x274C), (0x274E, 0x274E), (0x2753, 0x2755),
        (0x2757, 0x2757), (0x2795, 0x2797), (0x27B0, 0x27B0), (0x27BF, 0x27BF),
        (0x2B1B, 0x2B1C), (0x2B50, 0x2B50), (0x2B55, 0x2B55), (0x2E80, 0x303E),
        (0x3041, 0x33FF), (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xA000, 0xA4CF),
        (0xA960, 0xA97F), (0xAC00, 0xD7A3), (0xF900, 0xFAFF), (0xFE10, 0xFE19),
        (0xFE30, 0xFE6F), (0xFF00, 0xFF60), (0xFFE0, 0xFFE6), (0x1F004, 0x1F004),
        (0x1F0CF, 0x1F0CF), (0x1F18E, 0x1F18E), (0x1F191, 0x1F19A),
        (0x1F1E6, 0x1F1FF), (0x1F200, 0x1F2FF), (0x1F300, 0x1F64F),
        (0x1F680, 0x1F6FF), (0x1F900, 0x1F9FF), (0x1FA70, 0x1FAFF),
        (0x20000, 0x3FFFD),
    ]

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
            let w = charWidth(c)
            let cellEnd = col + w
            // Admit any cluster that *overlaps* the window, not only one whose
            // first cell is inside it: a double-width glyph straddling `start`
            // covers a requested column, and skipping it left the slice a
            // column short and dropped a visible character.
            if cellEnd > start && col < end {
                if !started {
                    if colorEnabled && !active.isEmpty { out += active }
                    started = true
                }
                // A wide cluster cut by either edge cannot be drawn half-width,
                // so stand in a space per visible cell. That keeps the result
                // exactly `width` columns, which every caller pads against.
                if col < start || cellEnd > end {
                    out += String(repeating: " ", count: min(cellEnd, end) - max(col, start))
                } else {
                    out.append(c)
                }
            }
            col = cellEnd
            if col >= end { break }
            i += 1
        }
        if started && !active.isEmpty { out += reset }
        return out
    }

    /// The whole grapheme clusters of a *plain* string that overlap the display
    /// columns `[start, start + width)`.
    ///
    /// Where `horizontalSlice` is column-exact — it substitutes spaces for a
    /// glyph an edge cuts in half, because a drawn row must occupy the columns
    /// it claims — this favors keeping a character intact. It backs copy, where
    /// a glyph the selection visibly covered should come along whole rather
    /// than arrive as a space.
    public static func clusterSlice(_ s: String, start: Int, width: Int) -> String {
        guard width > 0 else { return "" }
        let end = start + width
        var col = 0
        var out = ""
        for c in s {
            let cellEnd = col + charWidth(c)
            if cellEnd > start, col < end { out.append(c) }
            col = cellEnd
            if col >= end { break }
        }
        return out
    }

    /// The index of the character boundary nearest display column `col` in a
    /// *plain* string — the inverse of summing `charWidth`, for turning a click
    /// into a caret position. A column inside the trailing half of a wide glyph
    /// rounds past it, and a column beyond the text maps to the end.
    public static func characterIndex(_ s: String, atColumn col: Int) -> Int {
        var c = 0
        for (i, ch) in s.enumerated() {
            let w = charWidth(ch)
            if col < c + w { return col - c >= (w + 1) / 2 ? i + 1 : i }
            c += w
        }
        return s.count
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
