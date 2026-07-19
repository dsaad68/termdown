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

}
