import Foundation

// Custom pastel family: warm — roses, peaches, sand and clay. The counterpart
// to the cold family, same saturation, opposite side of the wheel.

extension Theme {
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

    /// Warm — deep amber and rust.
    public static let ember = Theme(
        heading: [.hex(0xd9a05f), .hex(0xcf8f5f), .hex(0xe0b070), .hex(0xc89860), .hex(0xc07850), .hex(0x806050)],
        inlineCode: .hex(0xd09070), codeText: .hex(0xefdfd0), codeBar: .hex(0x56463c),
        link: .hex(0xd0a070), quoteBar: .hex(0xb0b070), rule: .hex(0x56463c),
        tableBorder: .hex(0x56463c), image: .hex(0xe09860), math: .hex(0xc0a880),
        alertNote: .hex(0xa0a8c0), alertTip: .hex(0xb0b070), alertImportant: .hex(0xc89070),
        alertWarning: .hex(0xd9b060), alertCaution: .hex(0xd07858),
        keyword: .hex(0xcf8f5f), string: .hex(0xb8b070), number: .hex(0xe0a870),
        comment: .hex(0x806050), type: .hex(0xc0a880))

    /// Warm — earthen clay and burnt orange.
    public static let terracotta = Theme(
        heading: [.hex(0xd09078), .hex(0xc88068), .hex(0xdda890), .hex(0xc8a078), .hex(0xb87860), .hex(0x7f6558)],
        inlineCode: .hex(0xd098a0), codeText: .hex(0xeddcd4), codeBar: .hex(0x584842),
        link: .hex(0xcf9880), quoteBar: .hex(0xb0b880), rule: .hex(0x584842),
        tableBorder: .hex(0x584842), image: .hex(0xdd9870), math: .hex(0xc0a898),
        alertNote: .hex(0xa8a8c0), alertTip: .hex(0xb0b880), alertImportant: .hex(0xc890a0),
        alertWarning: .hex(0xd0ac70), alertCaution: .hex(0xcf7860),
        keyword: .hex(0xd09078), string: .hex(0xb8b880), number: .hex(0xdd9870),
        comment: .hex(0x7f6558), type: .hex(0xc0a898))
}
