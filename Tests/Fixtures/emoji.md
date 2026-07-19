# Emoji and wide characters

Width classes that terminals disagree about, and that padded rows depend on.

Single-scalar emoji: 😀 🌡 🎯 — and the sub-U+1F300 ones legacy tables get
wrong: ✅ ⭐ ✨ ❌ ⚡ ⛔.

Variation-selector-16 sequences, whose base is narrow but which render wide:
❤️ ⚠️ ✔️ ➡️ ⌨️ ✏️ ☀️ ❄️.

Skin-tone modifiers: 👍🏻 👍🏽 👍🏿 — the modifier adds no column of its own.

ZWJ sequences: 👨‍👩‍👧 👩‍💻 🏳️‍🌈 — joined into one glyph, not one per component.

Regional-indicator flags: 🇺🇸 🇩🇪 🇯🇵.

Task-list checkboxes must stay narrow — they are `Emoji_Presentation=No`:

- [ ] unchecked stays one column
- [x] checked stays one column

CJK for comparison: 日本語 中文 한국어.

Combining marks are zero-width: éàü vs e\u{301}a\u{300}u\u{308}.

## Inside a table

| Symbol | Name | Width |
|---|---|---|
| ✅ | check | 2 |
| ❤️ | heart vs16 | 2 |
| 👍🏽 | thumb + tone | 2 |
| 👨‍👩‍👧 | family zwj | 2 |
| 日本 | cjk | 4 |

## Inside a code card

```text
✅ done      ❤️ vs16
👍🏽 tone      👨‍👩‍👧 zwj
日本語 cjk    plain
```

Inline `❤️ code` and **bold ✅** and a [link with 😀](https://example.com).
