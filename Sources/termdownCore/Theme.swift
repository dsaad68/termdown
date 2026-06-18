import Foundation

/// Color theme for termdown rendering.
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

    // MARK: - True-color matte themes
    //
    // Authored in RGB (`.hex(0xRRGGBB)`), so they render exactly on truecolor
    // terminals and degrade to the nearest 256-palette color elsewhere. Content
    // only — the TUI chrome keeps its shared pastel palette.

    /// Catppuccin Mocha.
    public static let catppuccin = Theme(
        heading: [.hex(0xcba6f7), .hex(0x89b4fa), .hex(0x94e2d5), .hex(0xf9e2af), .hex(0xfab387), .hex(0xa6adc8)],
        inlineCode: .hex(0xf5c2e7), codeText: .hex(0xcdd6f4), codeBar: .hex(0x6c7086),
        link: .hex(0x89b4fa), quoteBar: .hex(0xa6e3a1), rule: .hex(0x6c7086),
        tableBorder: .hex(0x6c7086), image: .hex(0xfab387), math: .hex(0x94e2d5),
        alertNote: .hex(0x89b4fa), alertTip: .hex(0xa6e3a1), alertImportant: .hex(0xcba6f7),
        alertWarning: .hex(0xf9e2af), alertCaution: .hex(0xf38ba8),
        keyword: .hex(0xcba6f7), string: .hex(0xa6e3a1), number: .hex(0xfab387),
        comment: .hex(0x6c7086), type: .hex(0xf9e2af))

    /// Rosé Pine.
    public static let rosePine = Theme(
        heading: [.hex(0xc4a7e7), .hex(0x9ccfd8), .hex(0xebbcba), .hex(0xf6c177), .hex(0x31748f), .hex(0x908caa)],
        inlineCode: .hex(0xebbcba), codeText: .hex(0xe0def4), codeBar: .hex(0x6e6a86),
        link: .hex(0x9ccfd8), quoteBar: .hex(0x31748f), rule: .hex(0x6e6a86),
        tableBorder: .hex(0x6e6a86), image: .hex(0xf6c177), math: .hex(0x9ccfd8),
        alertNote: .hex(0x9ccfd8), alertTip: .hex(0x31748f), alertImportant: .hex(0xc4a7e7),
        alertWarning: .hex(0xf6c177), alertCaution: .hex(0xeb6f92),
        keyword: .hex(0xc4a7e7), string: .hex(0xf6c177), number: .hex(0xebbcba),
        comment: .hex(0x6e6a86), type: .hex(0x9ccfd8))

    /// Nord.
    public static let nord = Theme(
        heading: [.hex(0x88c0d0), .hex(0x81a1c1), .hex(0x8fbcbb), .hex(0xebcb8b), .hex(0xd08770), .hex(0x4c566a)],
        inlineCode: .hex(0xb48ead), codeText: .hex(0xd8dee9), codeBar: .hex(0x4c566a),
        link: .hex(0x88c0d0), quoteBar: .hex(0xa3be8c), rule: .hex(0x4c566a),
        tableBorder: .hex(0x4c566a), image: .hex(0xd08770), math: .hex(0x8fbcbb),
        alertNote: .hex(0x81a1c1), alertTip: .hex(0xa3be8c), alertImportant: .hex(0xb48ead),
        alertWarning: .hex(0xebcb8b), alertCaution: .hex(0xbf616a),
        keyword: .hex(0x81a1c1), string: .hex(0xa3be8c), number: .hex(0xb48ead),
        comment: .hex(0x616e88), type: .hex(0x8fbcbb))

    /// Tokyo Night.
    public static let tokyoNight = Theme(
        heading: [.hex(0xbb9af7), .hex(0x7aa2f7), .hex(0x7dcfff), .hex(0xe0af68), .hex(0xff9e64), .hex(0x565f89)],
        inlineCode: .hex(0xbb9af7), codeText: .hex(0xc0caf5), codeBar: .hex(0x565f89),
        link: .hex(0x7aa2f7), quoteBar: .hex(0x9ece6a), rule: .hex(0x565f89),
        tableBorder: .hex(0x565f89), image: .hex(0xff9e64), math: .hex(0x7dcfff),
        alertNote: .hex(0x7aa2f7), alertTip: .hex(0x9ece6a), alertImportant: .hex(0xbb9af7),
        alertWarning: .hex(0xe0af68), alertCaution: .hex(0xf7768e),
        keyword: .hex(0xbb9af7), string: .hex(0x9ece6a), number: .hex(0xff9e64),
        comment: .hex(0x565f89), type: .hex(0x7dcfff))

    /// Gruvbox (soft dark).
    public static let gruvbox = Theme(
        heading: [.hex(0xfabd2f), .hex(0x8ec07c), .hex(0xb8bb26), .hex(0xfe8019), .hex(0x83a598), .hex(0x928374)],
        inlineCode: .hex(0xd3869b), codeText: .hex(0xebdbb2), codeBar: .hex(0x928374),
        link: .hex(0x83a598), quoteBar: .hex(0xb8bb26), rule: .hex(0x928374),
        tableBorder: .hex(0x928374), image: .hex(0xfe8019), math: .hex(0x8ec07c),
        alertNote: .hex(0x83a598), alertTip: .hex(0xb8bb26), alertImportant: .hex(0xd3869b),
        alertWarning: .hex(0xfabd2f), alertCaution: .hex(0xfb4934),
        keyword: .hex(0xfb4934), string: .hex(0xb8bb26), number: .hex(0xd3869b),
        comment: .hex(0x928374), type: .hex(0xfabd2f))

    /// Dracula.
    public static let dracula = Theme(
        heading: [.hex(0xbd93f9), .hex(0x8be9fd), .hex(0xff79c6), .hex(0xf1fa8c), .hex(0xffb86c), .hex(0x6272a4)],
        inlineCode: .hex(0xff79c6), codeText: .hex(0xf8f8f2), codeBar: .hex(0x6272a4),
        link: .hex(0x8be9fd), quoteBar: .hex(0x50fa7b), rule: .hex(0x6272a4),
        tableBorder: .hex(0x6272a4), image: .hex(0xffb86c), math: .hex(0x8be9fd),
        alertNote: .hex(0x8be9fd), alertTip: .hex(0x50fa7b), alertImportant: .hex(0xbd93f9),
        alertWarning: .hex(0xf1fa8c), alertCaution: .hex(0xff5555),
        keyword: .hex(0xff79c6), string: .hex(0xf1fa8c), number: .hex(0xbd93f9),
        comment: .hex(0x6272a4), type: .hex(0x8be9fd))

    // MARK: - Custom pastel families (matte / cold / warm)

    /// Matte — muted rose/sage neutrals, low saturation.
    public static let matteRose = Theme(
        heading: [.hex(0xc9a9b8), .hex(0xa9b8c9), .hex(0xb8c9a9), .hex(0xd0c0a0), .hex(0xc0a0a8), .hex(0x807880)],
        inlineCode: .hex(0xc9a9c0), codeText: .hex(0xd8d0d4), codeBar: .hex(0x565058),
        link: .hex(0xa9b8c9), quoteBar: .hex(0xa9c0a9), rule: .hex(0x565058),
        tableBorder: .hex(0x565058), image: .hex(0xc9b0a0), math: .hex(0xa9c0c0),
        alertNote: .hex(0xa9b8c9), alertTip: .hex(0xa9c0a9), alertImportant: .hex(0xc9a9b8),
        alertWarning: .hex(0xd0c0a0), alertCaution: .hex(0xc99fa0),
        keyword: .hex(0xc9a9b8), string: .hex(0xa9c0a9), number: .hex(0xc9b0a0),
        comment: .hex(0x807880), type: .hex(0xa9c0c0))

    /// Matte — slate / blue-gray neutrals.
    public static let matteSlate = Theme(
        heading: [.hex(0x9fb0c0), .hex(0x8fa0b8), .hex(0xa0c0c0), .hex(0xc0b8a0), .hex(0xb89fa8), .hex(0x6f7884)],
        inlineCode: .hex(0xb0a9c0), codeText: .hex(0xd2d6dc), codeBar: .hex(0x4c545e),
        link: .hex(0x8fb0c8), quoteBar: .hex(0x9fb8a8), rule: .hex(0x4c545e),
        tableBorder: .hex(0x4c545e), image: .hex(0xc0a890), math: .hex(0x9fc0c0),
        alertNote: .hex(0x8fa0b8), alertTip: .hex(0x9fb8a8), alertImportant: .hex(0xb0a9c0),
        alertWarning: .hex(0xc0b8a0), alertCaution: .hex(0xc09fa0),
        keyword: .hex(0x9fa8c8), string: .hex(0x9fb8a8), number: .hex(0xc0a890),
        comment: .hex(0x6f7884), type: .hex(0x9fc0c0))

    /// Cold — icy blues, cyan and lavender.
    public static let frost = Theme(
        heading: [.hex(0x8ec7e6), .hex(0x7fb3d5), .hex(0xa3d5d3), .hex(0xb8c7e0), .hex(0x9db4d4), .hex(0x6b7a99)],
        inlineCode: .hex(0xc0a9e0), codeText: .hex(0xd6e2f0), codeBar: .hex(0x4a5468),
        link: .hex(0x7fc7e8), quoteBar: .hex(0x8fc7b0), rule: .hex(0x4a5468),
        tableBorder: .hex(0x4a5468), image: .hex(0xa9c7e0), math: .hex(0x8fd0d0),
        alertNote: .hex(0x7fb3d5), alertTip: .hex(0x8fc7b0), alertImportant: .hex(0xb3a9e0),
        alertWarning: .hex(0xd9c98f), alertCaution: .hex(0xe09aa0),
        keyword: .hex(0xb3a9e0), string: .hex(0x8fc7b0), number: .hex(0xc0a9e0),
        comment: .hex(0x6b7a99), type: .hex(0x8fd0d0))

    /// Cold — cool greens and aqua.
    public static let mint = Theme(
        heading: [.hex(0x86d6b0), .hex(0x7ec4a8), .hex(0x9ad9c0), .hex(0xa7d6b8), .hex(0x8fb8a8), .hex(0x5f7a70)],
        inlineCode: .hex(0xc4b0e0), codeText: .hex(0xdcebe2), codeBar: .hex(0x44564e),
        link: .hex(0x7fc7d0), quoteBar: .hex(0x86d6b0), rule: .hex(0x44564e),
        tableBorder: .hex(0x44564e), image: .hex(0xc7d6a0), math: .hex(0x8fd0c4),
        alertNote: .hex(0x7fc7d0), alertTip: .hex(0x86d6b0), alertImportant: .hex(0xc4b0e0),
        alertWarning: .hex(0xd9d08f), alertCaution: .hex(0xe0a0a0),
        keyword: .hex(0x9fd0c0), string: .hex(0xc7d6a0), number: .hex(0xc4b0e0),
        comment: .hex(0x5f7a70), type: .hex(0x8fd0c4))

    /// Cold — indigo / violet periwinkle.
    public static let dusk = Theme(
        heading: [.hex(0xb9a3e3), .hex(0x9a8fd0), .hex(0xc4b0e8), .hex(0xa0b0e0), .hex(0x8f9fd0), .hex(0x6a6a8a)],
        inlineCode: .hex(0xd0a9d8), codeText: .hex(0xdcd6ec), codeBar: .hex(0x4a4a64),
        link: .hex(0x9fb0e8), quoteBar: .hex(0x9fc0c0), rule: .hex(0x4a4a64),
        tableBorder: .hex(0x4a4a64), image: .hex(0xd0b0d8), math: .hex(0xa0c0e0),
        alertNote: .hex(0x9fb0e8), alertTip: .hex(0x9fc0b0), alertImportant: .hex(0xb9a3e3),
        alertWarning: .hex(0xd9c98f), alertCaution: .hex(0xe0a0b0),
        keyword: .hex(0xb9a3e3), string: .hex(0x9fc0b0), number: .hex(0xd0a9d8),
        comment: .hex(0x6a6a8a), type: .hex(0xa0c0e0))

    /// Warm — rose, peach and pink.
    public static let blossom = Theme(
        heading: [.hex(0xe6a0b8), .hex(0xe0a890), .hex(0xe8b0c8), .hex(0xd9c08f), .hex(0xc89fb0), .hex(0x8a7078)],
        inlineCode: .hex(0xe0a9c0), codeText: .hex(0xf0e2e8), codeBar: .hex(0x5a4a50),
        link: .hex(0xd99fb0), quoteBar: .hex(0xb8c790), rule: .hex(0x5a4a50),
        tableBorder: .hex(0x5a4a50), image: .hex(0xe8b090), math: .hex(0xd0a0b8),
        alertNote: .hex(0xb0a9d0), alertTip: .hex(0xa8c790), alertImportant: .hex(0xe6a0b8),
        alertWarning: .hex(0xe0c080), alertCaution: .hex(0xe08080),
        keyword: .hex(0xe6a0b8), string: .hex(0xc0c790), number: .hex(0xe0b090),
        comment: .hex(0x8a7078), type: .hex(0xd0a0b8))

    /// Warm — sand, tan and clay.
    public static let sand = Theme(
        heading: [.hex(0xd9c79a), .hex(0xcbb088), .hex(0xd6c0a0), .hex(0xc0b890), .hex(0xc7a070), .hex(0x807860)],
        inlineCode: .hex(0xd0b0a0), codeText: .hex(0xece2d4), codeBar: .hex(0x58504a),
        link: .hex(0xc7b088), quoteBar: .hex(0xb0c090), rule: .hex(0x58504a),
        tableBorder: .hex(0x58504a), image: .hex(0xd6a878), math: .hex(0xa0c0a0),
        alertNote: .hex(0xa0b8c0), alertTip: .hex(0xb0c090), alertImportant: .hex(0xc7a888),
        alertWarning: .hex(0xd9c07f), alertCaution: .hex(0xd99080),
        keyword: .hex(0xc79f7f), string: .hex(0xb0c090), number: .hex(0xd0b090),
        comment: .hex(0x807860), type: .hex(0xa0c0a0))

    /// Warm — coral, apricot and salmon.
    public static let coral = Theme(
        heading: [.hex(0xe69a8f), .hex(0xe0a878), .hex(0xe8b0a0), .hex(0xd9c08f), .hex(0xc98f8f), .hex(0x8a7068)],
        inlineCode: .hex(0xe0a0b0), codeText: .hex(0xf0e4de), codeBar: .hex(0x5a4a46),
        link: .hex(0xe0a890), quoteBar: .hex(0xc0c088), rule: .hex(0x5a4a46),
        tableBorder: .hex(0x5a4a46), image: .hex(0xe8a080), math: .hex(0xd0b0a0),
        alertNote: .hex(0xc0a8d0), alertTip: .hex(0xb8c888), alertImportant: .hex(0xe69a8f),
        alertWarning: .hex(0xe0be80), alertCaution: .hex(0xe08070),
        keyword: .hex(0xe69a8f), string: .hex(0xc8c888), number: .hex(0xe0a878),
        comment: .hex(0x8a7068), type: .hex(0xd0b0a0))

    // MARK: - Registry

    /// All built-in themes, in selector/display order. The first entry is the
    /// default. Names are the `--theme` / config values (lowercased, kebab-case).
    public static let all: [(name: String, theme: Theme)] = [
        ("dark", .dark), ("light", .light), ("mono", .mono),
        ("catppuccin", .catppuccin), ("rose-pine", .rosePine), ("nord", .nord),
        ("tokyo-night", .tokyoNight), ("gruvbox", .gruvbox), ("dracula", .dracula),
        // Custom pastel families:
        ("matte-rose", .matteRose), ("matte-slate", .matteSlate),   // matte
        ("frost", .frost), ("mint", .mint), ("dusk", .dusk),        // cold
        ("blossom", .blossom), ("sand", .sand), ("coral", .coral),  // warm
    ]

    /// Resolve a theme by name (case-insensitive); nil if unknown.
    public static func named(_ name: String) -> Theme? {
        all.first { $0.name == name.lowercased() }?.theme
    }
}
