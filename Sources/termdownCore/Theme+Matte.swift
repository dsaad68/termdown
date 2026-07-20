import Foundation

// Custom pastel family: matte — muted, low-saturation neutrals. Desaturated
// enough that no single hue dominates a page of prose.

extension Theme {
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

    /// Matte — moss / olive neutrals.
    public static let matteMoss = Theme(
        heading: [.hex(0xa9c0a0), .hex(0xa0b8a9), .hex(0xb8c0a0), .hex(0xc8c0a0), .hex(0xa8b898), .hex(0x78806f)],
        inlineCode: .hex(0xb0c0a9), codeText: .hex(0xd4dcd2), codeBar: .hex(0x505850),
        link: .hex(0xa0b8b0), quoteBar: .hex(0xa9c0a0), rule: .hex(0x505850),
        tableBorder: .hex(0x505850), image: .hex(0xc0b898), math: .hex(0xa0c0b0),
        alertNote: .hex(0xa0b0b8), alertTip: .hex(0xa9c0a0), alertImportant: .hex(0xb8b0c0),
        alertWarning: .hex(0xc8c098), alertCaution: .hex(0xc0a098),
        keyword: .hex(0xa9c0a0), string: .hex(0xb8c0a0), number: .hex(0xc0b898),
        comment: .hex(0x78806f), type: .hex(0xa0c0b0))
}
