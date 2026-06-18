import Foundation

/// ANSI SGR / escape-sequence helpers and display-width utilities.
public enum Ansi {
    static let esc = "\u{1B}"
    static let reset = "\u{1B}[0m"

    public static var colorEnabled = true

    // MARK: - SGR

    public static func code(_ codes: [Int]) -> String {
        colorEnabled && !codes.isEmpty ? "\(esc)[\(codes.map(String.init).joined(separator: ";"))m" : ""
    }

    public static func wrap(_ s: String, _ codes: [Int]) -> String {
        colorEnabled && !codes.isEmpty ? code(codes) + s + reset : s
    }

    // MARK: - Color (256-palette or 24-bit, depending on terminal support)

    /// A color: a 256-palette index, or an absolute 24-bit RGB triple. Integer
    /// literals build `.x256`, so existing palette numbers keep working unchanged.
    public enum Color: Hashable, ExpressibleByIntegerLiteral {
        case x256(Int)
        case rgb(UInt8, UInt8, UInt8)
        public init(integerLiteral value: Int) { self = .x256(value) }

        /// Build an RGB color from a `0xRRGGBB` hex value (handy for themes).
        public static func hex(_ v: Int) -> Color {
            .rgb(UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF))
        }
    }

    /// Whether the terminal supports 24-bit color (set from `$COLORTERM` at
    /// startup). When true, every color is emitted as exact RGB (`38;2;r;g;b`),
    /// so both the rendered content and the TUI chrome render in true color;
    /// otherwise colors fall back to the 256-palette.
    public static var truecolor = false

    public static func fg(_ c: Color) -> [Int] { sgr(c, base: 38) }
    public static func bg(_ c: Color) -> [Int] { sgr(c, base: 48) }

    private static func sgr(_ c: Color, base: Int) -> [Int] {
        switch c {
        case .x256(let n):
            if truecolor { let (r, g, b) = palette256RGB(n); return [base, 2, r, g, b] }
            return [base, 5, n]
        case .rgb(let r, let g, let b):
            if truecolor { return [base, 2, Int(r), Int(g), Int(b)] }
            return [base, 5, nearest256(Int(r), Int(g), Int(b))]
        }
    }

    public static func bold(_ s: String) -> String { wrap(s, [1]) }
    public static func dim(_ s: String) -> String { wrap(s, [2]) }
    public static func italic(_ s: String) -> String { wrap(s, [3]) }
    public static func underline(_ s: String) -> String { wrap(s, [4]) }
    public static func color(_ s: String, _ c: Color) -> String { wrap(s, fg(c)) }

    /// Apply both foreground and background color.
    public static func fgBg(_ s: String, fg fgC: Color, bg bgC: Color) -> String {
        wrap(s, fg(fgC) + bg(bgC))
    }

    /// A readable text color to place *on top of* `bg`: near-black for light
    /// backgrounds, near-white for dark ones (per perceived luminance).
    public static func contrastingText(on bg: Color) -> Color {
        let (r, g, b): (Int, Int, Int)
        switch bg {
        case .rgb(let rr, let gg, let bb): (r, g, b) = (Int(rr), Int(gg), Int(bb))
        case .x256(let n): (r, g, b) = palette256RGB(n)
        }
        let luma = (r * 299 + g * 587 + b * 114) / 1000
        return luma > 140 ? .rgb(28, 28, 34) : .rgb(238, 238, 244)
    }

    // MARK: - 256-palette ↔ RGB conversion

    /// Standard xterm 256-palette → RGB. 16–231 is the 6×6×6 color cube,
    /// 232–255 the grayscale ramp, 0–15 the conventional system colors.
    static func palette256RGB(_ n: Int) -> (Int, Int, Int) {
        if n >= 16 && n <= 231 {
            let i = n - 16
            let levels = [0, 95, 135, 175, 215, 255]
            return (levels[i / 36], levels[(i / 6) % 6], levels[i % 6])
        }
        if n >= 232 && n <= 255 {
            let v = 8 + 10 * (n - 232)
            return (v, v, v)
        }
        let sys: [(Int, Int, Int)] = [
            (0,0,0),(128,0,0),(0,128,0),(128,128,0),(0,0,128),(128,0,128),(0,128,128),(192,192,192),
            (128,128,128),(255,0,0),(0,255,0),(255,255,0),(0,0,255),(255,0,255),(0,255,255),(255,255,255),
        ]
        return sys[max(0, min(15, n))]
    }

    /// Nearest 256-palette index for an RGB triple (used when emitting `.rgb`
    /// colors on a 256-only terminal). Weighs the color cube against the
    /// grayscale ramp and picks whichever is closer.
    static func nearest256(_ r: Int, _ g: Int, _ b: Int) -> Int {
        let levels = [0, 95, 135, 175, 215, 255]
        func nearestLevel(_ v: Int) -> Int {
            var best = 0, bestD = Int.max
            for (i, l) in levels.enumerated() where abs(l - v) < bestD { bestD = abs(l - v); best = i }
            return best
        }
        let ri = nearestLevel(r), gi = nearestLevel(g), bi = nearestLevel(b)
        let (cr, cg, cb) = (levels[ri], levels[gi], levels[bi])
        let cubeDist = (cr-r)*(cr-r) + (cg-g)*(cg-g) + (cb-b)*(cb-b)
        let gray = (r + g + b) / 3
        let gIdx = max(0, min(23, (gray - 8 + 5) / 10))
        let gv = 8 + 10 * gIdx
        let grayDist = (gv-r)*(gv-r) + (gv-g)*(gv-g) + (gv-b)*(gv-b)
        return grayDist < cubeDist ? 232 + gIdx : 16 + 36 * ri + 6 * gi + bi
    }

    /// Fill an entire row with a background color, padding to `cols`.
    ///
    /// Styled segments inside `s` typically end with a full SGR reset
    /// (`ESC[0m`) which also clears the background — so a naive wrap would only
    /// tint the row up to the first reset. We re-assert the background after
    /// every internal reset so the fill stays continuous across the whole row.
    public static func bgRow(_ s: String, bg bgC: Color, cols: Int) -> String {
        guard colorEnabled else { return pad(s, to: cols) }
        let bgSeq = code(bg(bgC))
        let patched = s.replacingOccurrences(of: reset, with: reset + bgSeq)
        let padded = pad(patched, to: cols)
        return bgSeq + padded + reset
    }

    /// A left-edge accent bar (▌) used to mark selected / active rows.
    public static func bar(_ color: Color) -> String { Ansi.color("\u{258C}", color) }

    // MARK: - TUI Matte Pastel Palette
    //
    // A cohesive, matte pastel 256-color palette (Catppuccin / Rosé Pine
    // flavoured) used throughout the TUI chrome. Surfaces are layered matte
    // darks; accents are soft and desaturated so nothing shouts. Selection is
    // a subtle raised surface paired with a mauve accent bar — the modern look
    // shared by lazygit, yazi and helix — rather than a loud colour fill.

    public enum Pastel {
        // ── Surfaces (layered matte darks) ──
        public static let headerBg:    Color = 237   // raised title / header surface
        public static let panelBg:     Color = 236   // sidebar / panel surface
        public static let selectBg:    Color = 238   // matte selection surface
        public static let outlineSelBg: Color = 60   // focused outline selection — dark lavender, echoes accent 183
        public static let statusBg:    Color = 237   // status bar (lighter segment)
        public static let statusDimBg: Color = 235   // status bar (darker segment)
        public static let sidebarBg:   Color = 236   // focused sidebar background
        public static let shadow:      Color = 233   // drop shadow

        // ── Text ──
        public static let headerFg:    Color = 253   // near-white headings
        public static let statusFg:    Color = 250   // status bar text
        public static let textDim:     Color = 245   // muted secondary text
        public static let selectFg:    Color = 231   // bright white on selection

        // ── Matte pastel accents ──
        public static let accent:      Color = 183   // mauve / lavender — primary
        public static let accentDim:   Color = 146   // muted lavender
        public static let pink:        Color = 218   // soft pink
        public static let tealAccent:  Color = 152   // soft teal — secondary emphasis
        public static let green:       Color = 151   // sage green
        public static let peach:       Color = 216   // soft peach
        public static let blue:        Color = 111   // soft blue
        public static let yellow:      Color = 223   // soft yellow

        // ── Roles ──
        public static let selectBar:   Color = 183   // mauve accent bar on active rows
        public static let selectorFg:  Color = 151   // green prompt caret
        public static let matchFg:     Color = 223   // fuzzy-match highlight (soft yellow)
        public static let border:      Color = 244   // brighter border accent
        public static let borderDim:   Color = 240   // subtle frame border
    }

    /// OSC 8 hyperlink (clickable in modern terminals).
    public static func hyperlink(_ text: String, url: String) -> String {
        if colorEnabled {
            return "\(esc)]8;;\(url)\(esc)\\\(text)\(esc)]8;;\(esc)\\"
        } else {
            return text
        }
    }

    /// OSC 52 clipboard write: base64-encodes `text` into an escape sequence the
    /// terminal copies to the system clipboard. Works over SSH and through
    /// multiplexers that pass OSC 52 through (tmux/screen with the right config),
    /// where a host-side clipboard call wouldn't reach the user's machine.
    public static func osc52(_ text: String) -> String {
        let b64 = Data(text.utf8).base64EncodedString()
        return "\(esc)]52;c;\(b64)\(esc)\\"
    }

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
        // Zero-width
        if (0x0300...0x036F).contains(v) || (0x200B...0x200F).contains(v) || v == 0xFEFF {
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
