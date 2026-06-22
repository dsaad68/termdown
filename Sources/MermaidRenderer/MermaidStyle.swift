// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// classDef styling. mermaid-ascii's "cli" style type colors node text with a
// truecolor ANSI escape derived from the classDef `color:` value. This is the
// only place the flowchart engine emits ANSI; with no classDef the output is
// plain text (so the upstream testdata goldens are colorless).

import Foundation

struct StyleClass {
    var name: String
    var styles: [String: String]
}

/// 24-bit RGB color parsed from a classDef `color:` value.
struct MermaidRGB: Equatable {
    var r: Int
    var g: Int
    var b: Int
}

/// Wrap `text` in a truecolor foreground SGR + reset.
func ansiTrueColor(_ text: String, _ rgb: MermaidRGB) -> String {
    "\u{1B}[38;2;\(rgb.r);\(rgb.g);\(rgb.b)m\(text)\u{1B}[0m"
}

/// Parse a hex color ("#rgb", "#rrggbb", or without the leading '#").
func parseHexColor(_ hex: String) -> MermaidRGB? {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    let chars = Array(s)
    func hexVal(_ slice: [Character]) -> Int? { Int(String(slice), radix: 16) }
    switch chars.count {
    case 3:
        guard let r = hexVal([chars[0], chars[0]]),
              let g = hexVal([chars[1], chars[1]]),
              let b = hexVal([chars[2], chars[2]]) else { return nil }
        return MermaidRGB(r: r, g: g, b: b)
    case 6:
        guard let r = hexVal(Array(chars[0..<2])),
              let g = hexVal(Array(chars[2..<4])),
              let b = hexVal(Array(chars[4..<6])) else { return nil }
        return MermaidRGB(r: r, g: g, b: b)
    default:
        return nil
    }
}

/// mermaid-ascii `wrapTextInColor` for the "cli" style type. Returns `text`
/// unchanged when there is no color or color is disabled.
func wrapTextInColor(_ text: String, _ colorHex: String, colorEnabled: Bool) -> String {
    if colorHex.isEmpty || !colorEnabled { return text }
    guard let rgb = parseHexColor(colorHex) else { return text }
    return ansiTrueColor(text, rgb)
}
