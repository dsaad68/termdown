import Foundation

// Ports of well-known editor palettes.
//
// Authored in RGB (`.hex(0xRRGGBB)`), so they render exactly on truecolor
// terminals and degrade to the nearest 256-palette color elsewhere. Content
// only — the TUI chrome keeps its shared pastel palette.
//
// Heading colors run h1..h6 and are picked to keep a visible hierarchy, so they
// deliberately do not always follow the upstream palette's own ordering.

extension Theme {
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

    /// Solarized Dark — Ethan Schoonover's accent ring on the base03 background.
    public static let solarizedDark = Theme(
        heading: [.hex(0x6c71c4), .hex(0x268bd2), .hex(0x2aa198), .hex(0xb58900), .hex(0xcb4b16), .hex(0x586e75)],
        inlineCode: .hex(0xd33682), codeText: .hex(0x839496), codeBar: .hex(0x586e75),
        link: .hex(0x268bd2), quoteBar: .hex(0x859900), rule: .hex(0x586e75),
        tableBorder: .hex(0x586e75), image: .hex(0xcb4b16), math: .hex(0x2aa198),
        alertNote: .hex(0x268bd2), alertTip: .hex(0x859900), alertImportant: .hex(0x6c71c4),
        alertWarning: .hex(0xb58900), alertCaution: .hex(0xdc322f),
        keyword: .hex(0x859900), string: .hex(0x2aa198), number: .hex(0xd33682),
        comment: .hex(0x586e75), type: .hex(0xb58900))

    /// Solarized Light — the same accent ring, with body text darkened for a
    /// light background. See the note in the README: the TUI chrome stays dark.
    public static let solarizedLight = Theme(
        heading: [.hex(0x6c71c4), .hex(0x268bd2), .hex(0x2aa198), .hex(0xb58900), .hex(0xcb4b16), .hex(0x657b83)],
        inlineCode: .hex(0xd33682), codeText: .hex(0x657b83), codeBar: .hex(0x93a1a1),
        link: .hex(0x268bd2), quoteBar: .hex(0x859900), rule: .hex(0x93a1a1),
        tableBorder: .hex(0x93a1a1), image: .hex(0xcb4b16), math: .hex(0x2aa198),
        alertNote: .hex(0x268bd2), alertTip: .hex(0x859900), alertImportant: .hex(0x6c71c4),
        alertWarning: .hex(0xb58900), alertCaution: .hex(0xdc322f),
        keyword: .hex(0x859900), string: .hex(0x2aa198), number: .hex(0xd33682),
        comment: .hex(0x93a1a1), type: .hex(0xb58900))

    /// Everforest (dark, medium contrast).
    public static let everforest = Theme(
        heading: [.hex(0xa7c080), .hex(0x7fbbb3), .hex(0x83c092), .hex(0xdbbc7f), .hex(0xe69875), .hex(0x859289)],
        inlineCode: .hex(0xd699b6), codeText: .hex(0xd3c6aa), codeBar: .hex(0x859289),
        link: .hex(0x7fbbb3), quoteBar: .hex(0xa7c080), rule: .hex(0x859289),
        tableBorder: .hex(0x859289), image: .hex(0xe69875), math: .hex(0x83c092),
        alertNote: .hex(0x7fbbb3), alertTip: .hex(0xa7c080), alertImportant: .hex(0xd699b6),
        alertWarning: .hex(0xdbbc7f), alertCaution: .hex(0xe67e80),
        keyword: .hex(0xe67e80), string: .hex(0xa7c080), number: .hex(0xd699b6),
        comment: .hex(0x859289), type: .hex(0xdbbc7f))

    /// Kanagawa (wave).
    public static let kanagawa = Theme(
        heading: [.hex(0x957fb8), .hex(0x7e9cd8), .hex(0x7aa89f), .hex(0xe6c384), .hex(0xffa066), .hex(0x727169)],
        inlineCode: .hex(0xd27e99), codeText: .hex(0xdcd7ba), codeBar: .hex(0x727169),
        link: .hex(0x7e9cd8), quoteBar: .hex(0x98bb6c), rule: .hex(0x727169),
        tableBorder: .hex(0x727169), image: .hex(0xffa066), math: .hex(0x7aa89f),
        alertNote: .hex(0x7e9cd8), alertTip: .hex(0x98bb6c), alertImportant: .hex(0x957fb8),
        alertWarning: .hex(0xe6c384), alertCaution: .hex(0xe82424),
        keyword: .hex(0x957fb8), string: .hex(0x98bb6c), number: .hex(0xd27e99),
        comment: .hex(0x727169), type: .hex(0x7aa89f))

    /// Atom One Dark.
    public static let oneDark = Theme(
        heading: [.hex(0xc678dd), .hex(0x61afef), .hex(0x56b6c2), .hex(0xe5c07b), .hex(0xd19a66), .hex(0x5c6370)],
        inlineCode: .hex(0xe06c75), codeText: .hex(0xabb2bf), codeBar: .hex(0x5c6370),
        link: .hex(0x61afef), quoteBar: .hex(0x98c379), rule: .hex(0x5c6370),
        tableBorder: .hex(0x5c6370), image: .hex(0xd19a66), math: .hex(0x56b6c2),
        alertNote: .hex(0x61afef), alertTip: .hex(0x98c379), alertImportant: .hex(0xc678dd),
        alertWarning: .hex(0xe5c07b), alertCaution: .hex(0xe06c75),
        keyword: .hex(0xc678dd), string: .hex(0x98c379), number: .hex(0xd19a66),
        comment: .hex(0x5c6370), type: .hex(0xe5c07b))

    /// Monokai.
    public static let monokai = Theme(
        heading: [.hex(0xf92672), .hex(0x66d9ef), .hex(0xa6e22e), .hex(0xe6db74), .hex(0xfd971f), .hex(0x75715e)],
        inlineCode: .hex(0xae81ff), codeText: .hex(0xf8f8f2), codeBar: .hex(0x75715e),
        link: .hex(0x66d9ef), quoteBar: .hex(0xa6e22e), rule: .hex(0x75715e),
        tableBorder: .hex(0x75715e), image: .hex(0xfd971f), math: .hex(0x66d9ef),
        alertNote: .hex(0x66d9ef), alertTip: .hex(0xa6e22e), alertImportant: .hex(0xae81ff),
        alertWarning: .hex(0xe6db74), alertCaution: .hex(0xf92672),
        keyword: .hex(0xf92672), string: .hex(0xe6db74), number: .hex(0xae81ff),
        comment: .hex(0x75715e), type: .hex(0x66d9ef))

    /// Ayu Mirage.
    public static let ayuMirage = Theme(
        heading: [.hex(0xffcc66), .hex(0x5ccfe6), .hex(0x73d0ff), .hex(0xffd580), .hex(0xf29e74), .hex(0x5c6773)],
        inlineCode: .hex(0xc3a6ff), codeText: .hex(0xcbccc6), codeBar: .hex(0x5c6773),
        link: .hex(0x5ccfe6), quoteBar: .hex(0xbae67e), rule: .hex(0x5c6773),
        tableBorder: .hex(0x5c6773), image: .hex(0xf29e74), math: .hex(0x73d0ff),
        alertNote: .hex(0x5ccfe6), alertTip: .hex(0xbae67e), alertImportant: .hex(0xc3a6ff),
        alertWarning: .hex(0xffcc66), alertCaution: .hex(0xff3333),
        keyword: .hex(0xc3a6ff), string: .hex(0xbae67e), number: .hex(0xffcc66),
        comment: .hex(0x5c6773), type: .hex(0x73d0ff))

    /// Night Owl.
    public static let nightOwl = Theme(
        heading: [.hex(0xc792ea), .hex(0x82aaff), .hex(0x7fdbca), .hex(0xecc48d), .hex(0xf78c6c), .hex(0x637777)],
        inlineCode: .hex(0xf78c6c), codeText: .hex(0xd6deeb), codeBar: .hex(0x637777),
        link: .hex(0x82aaff), quoteBar: .hex(0xaddb67), rule: .hex(0x637777),
        tableBorder: .hex(0x637777), image: .hex(0xf78c6c), math: .hex(0x7fdbca),
        alertNote: .hex(0x82aaff), alertTip: .hex(0xaddb67), alertImportant: .hex(0xc792ea),
        alertWarning: .hex(0xecc48d), alertCaution: .hex(0xef5350),
        keyword: .hex(0xc792ea), string: .hex(0xecc48d), number: .hex(0xf78c6c),
        comment: .hex(0x637777), type: .hex(0x7fdbca))
}
