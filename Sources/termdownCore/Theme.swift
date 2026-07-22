import Foundation

/// Color theme for termdown rendering.
///
/// Only the three 256-palette originals are declared here — `dark` is the
/// default everywhere and `mono` is the no-color fallback. The truecolor themes
/// live in `Theme+Ports.swift` and the `Theme+Matte/Cold/Warm.swift` family
/// files, which keeps each under the 400-line lint ceiling (same split the
/// codebase already uses for `Ansi.swift`).
public struct Theme {
    var heading: [Ansi.Color]      // h1..h6
    var inlineCode: Ansi.Color
    var codeText: Ansi.Color
    var codeBar: Ansi.Color
    var link: Ansi.Color
    var quoteBar: Ansi.Color
    var rule: Ansi.Color
    var tableBorder: Ansi.Color
    var image: Ansi.Color
    var math: Ansi.Color

    // Alert colors (for Step 06)
    var alertNote: Ansi.Color
    var alertTip: Ansi.Color
    var alertImportant: Ansi.Color
    var alertWarning: Ansi.Color
    var alertCaution: Ansi.Color

    // Syntax highlighting colors (for Step 04)
    var keyword: Ansi.Color
    var string: Ansi.Color
    var number: Ansi.Color
    var comment: Ansi.Color
    var type: Ansi.Color

    // Matte pastel dark theme — harmonised with the TUI chrome palette
    // (mauve / blue / teal / yellow / peach), keeping a clear heading hierarchy.
    public static let dark = Theme(
        heading: [183, 111, 152, 223, 216, 245],  // mauve, blue, teal, yellow, peach, gray
        inlineCode: 218,    // soft pink
        codeText: 252,
        codeBar: 240,
        link: 117,          // soft sky blue
        quoteBar: 151,      // sage green
        rule: 240,
        tableBorder: 240,
        image: 216,         // soft peach
        math: 152,          // soft teal — distinct from prose & code
        alertNote: 111,       // Blue
        alertTip: 151,        // Green
        alertImportant: 183,  // Mauve
        alertWarning: 223,    // Yellow
        alertCaution: 217,    // Red
        keyword: 209,      // Soft pink
        string: 152,       // Soft teal
        number: 223,       // Soft yellow
        comment: 245,      // Soft gray
        type: 151          // Soft sage green
    )

    public static let light = Theme(
        heading: [126, 28, 32, 55, 23, 90],
        inlineCode: 203,
        codeText: 235,
        codeBar: 244,
        link: 26,
        quoteBar: 64,
        rule: 244,
        tableBorder: 244,
        image: 208,
        math: 30,           // soft teal
        alertNote: 27,        // Blue
        alertTip: 34,         // Green
        alertImportant: 55,  // Purple
        alertWarning: 172,   // Yellow
        alertCaution: 160,   // Red
        keyword: 168,      // Soft purple (more pastel than 127)
        string: 64,        // Soft blue (more pastel than 22)
        number: 94,        // Soft orange (more pastel than 130)
        comment: 243,      // Soft gray (slightly darker than 244)
        type: 30          // Soft teal (more pastel than 28)
    )

    public static let mono = Theme(
        heading: [7, 7, 7, 7, 7, 7],
        inlineCode: 7,
        codeText: 7,
        codeBar: 7,
        link: 7,
        quoteBar: 7,
        rule: 7,
        tableBorder: 7,
        image: 7,
        math: 7,
        alertNote: 7,
        alertTip: 7,
        alertImportant: 7,
        alertWarning: 7,
        alertCaution: 7,
        keyword: 7,
        string: 7,
        number: 7,
        comment: 7,
        type: 7
    )

    public func withColorsEnabled(_ enabled: Bool) -> Theme {
        if enabled {
            return self
        } else {
            return .mono
        }
    }

    // MARK: - Registry

    /// All built-in themes, in selector/display order. The first entry is the
    /// default. Names are the `--theme` / config values (lowercased, kebab-case).
    public static let all: [(name: String, theme: Theme)] = [
        ("dark", .dark), ("light", .light), ("mono", .mono),
        // Ports of well-known editor palettes:
        ("catppuccin", .catppuccin), ("rose-pine", .rosePine), ("nord", .nord),
        ("tokyo-night", .tokyoNight), ("gruvbox", .gruvbox), ("dracula", .dracula),
        ("solarized-dark", .solarizedDark), ("solarized-light", .solarizedLight),
        ("everforest", .everforest), ("kanagawa", .kanagawa), ("one-dark", .oneDark),
        ("monokai", .monokai), ("ayu-mirage", .ayuMirage), ("night-owl", .nightOwl),
        // Custom pastel families:
        ("matte-rose", .matteRose), ("matte-slate", .matteSlate),      // matte
        ("matte-moss", .matteMoss),
        ("frost", .frost), ("mint", .mint), ("dusk", .dusk),           // cold
        ("glacier", .glacier),
        ("blossom", .blossom), ("sand", .sand), ("coral", .coral),     // warm
        ("ember", .ember), ("terracotta", .terracotta),
    ]

    /// Resolve a theme by name (case-insensitive); nil if unknown.
    public static func named(_ name: String) -> Theme? {
        all.first { $0.name == name.lowercased() }?.theme
    }
}
