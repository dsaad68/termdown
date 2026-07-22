import Foundation

// Custom pastel family: cold — blues, cyans, greens and violets. Cooler than
// the matte family, and a shade more saturated.

extension Theme {
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

    /// Cold — steel blue and pale ice.
    public static let glacier = Theme(
        heading: [.hex(0xa8c8dd), .hex(0x90b8d0), .hex(0xb0d8dd), .hex(0xc0d0e0), .hex(0x98b0c8), .hex(0x64788c)],
        inlineCode: .hex(0xb8b0d8), codeText: .hex(0xdbe6ef), codeBar: .hex(0x45505e),
        link: .hex(0x8fc0dd), quoteBar: .hex(0xa0c8c0), rule: .hex(0x45505e),
        tableBorder: .hex(0x45505e), image: .hex(0xb0c8d8), math: .hex(0x9fd0d8),
        alertNote: .hex(0x90b8d0), alertTip: .hex(0xa0c8c0), alertImportant: .hex(0xb8b0d8),
        alertWarning: .hex(0xd0cc98), alertCaution: .hex(0xd8a0a8),
        keyword: .hex(0xb8b0d8), string: .hex(0xa0c8c0), number: .hex(0xb0c8d8),
        comment: .hex(0x64788c), type: .hex(0x9fd0d8))
}
