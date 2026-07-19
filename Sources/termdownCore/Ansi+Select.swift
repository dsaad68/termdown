import Foundation

/// Column-range highlighting — the primitive behind mouse text selection.
/// Split out of `Ansi.swift`, which sits right on the 400-line lint ceiling.
extension Ansi {

    /// Tint the display-column range `[from, to)` of a styled string, keeping the
    /// SGR attributes already present — unlike the strip-and-reverse helpers in
    /// the pager, a selection drawn over a code block keeps its syntax colors.
    ///
    /// Walks the string like `horizontalSlice` (tracking the SGR run active since
    /// the last reset) and re-asserts the background the way `bgRow` does, so the
    /// tint survives styled segments. On leaving the range the active run is
    /// restored with a reset rather than `ESC[49m`: the result is fed straight
    /// into `horizontalSlice`, whose `active` accumulator is only cleared by a
    /// full reset, so anything else would leak the background across a clip.
    ///
    /// A double-width character belongs to the range when its *start* column
    /// falls inside it — the same rule `horizontalSlice` uses, which is what
    /// makes the tinted cells and the copied text agree by construction. OSC
    /// sequences pass through untouched (nothing is being cut here, so
    /// hyperlinks stay intact and clickable).
    ///
    /// Width-neutral: only escape sequences are inserted, never visible cells, so
    /// a tinted row still measures exactly as many columns as the original. The
    /// full-screen redraw depends on that — autowrap is off, and a row one column
    /// over the terminal width desyncs every later frame.
    public static func bgRange(_ s: String, from: Int, to: Int, bg bgC: Color) -> String {
        guard from < to else { return s }
        // Without color, mark the range with reverse video so a selection stays
        // visible under `--no-color` (where `code()` returns an empty string).
        let enterSeq = colorEnabled ? code(bg(bgC)) : "\(esc)[7m"
        let chars = Array(s)
        let n = chars.count
        var i = 0
        var col = 0
        var active = ""        // SGR sequences active since the last reset
        var inside = false
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
                    out += seq
                    if seq.hasSuffix("m") {
                        if seq == reset || seq == "\u{1B}[m" { active = "" } else { active += seq }
                        // Inside the range the tint has to win: a reset clears it,
                        // and content that sets its own background (code cards,
                        // table headers) would otherwise override it. Re-assert
                        // after every SGR sequence — a background code leaves the
                        // foreground the content just set untouched.
                        if inside { out += enterSeq }
                    }
                    continue
                } else if i + 1 < n && chars[i + 1] == "]" {
                    // OSC: copy through to the string terminator (BEL or ESC \).
                    out += "\u{1B}]"
                    i += 2
                    while i < n {
                        out.append(chars[i])
                        if chars[i] == "\u{07}" { i += 1; break }
                        if chars[i] == "\u{1B}", i + 1 < n, chars[i + 1] == "\\" {
                            out.append(chars[i + 1]); i += 2; break
                        }
                        i += 1
                    }
                    continue
                } else {
                    out.append(c)
                    i += 1
                    continue
                }
            }
            if !inside, col >= from, col < to {
                out += enterSeq
                inside = true
            } else if inside, col >= to {
                out += reset + active
                inside = false
            }
            out.append(c)
            col += charWidth(c)
            i += 1
        }
        if inside { out += reset + active }
        return out
    }
}
