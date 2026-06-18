# termdown showcase

A document exercising **all the features**.

## Text styling

This paragraph has *italic*, **bold**, ***bold italic***, ~~strikethrough~~,
`inline code`, and a [link](https://example.com). Here is a footnote-ish note
and an autolink: https://github.com.

> Blockquotes work too.
>
> > Even nested ones.

## Lists

- Bullet one
- Bullet two
  - Nested bullet
- Bullet three

1. First
2. Second
3. Third

### Task list

- [x] Implement scanner
- [x] Render to ANSI
- [ ] Conquer the world

## Table

| Feature        | Supported | Notes                  |
|----------------|:---------:|------------------------|
| Tables         |    yes    | box-drawing borders    |
| Emphasis       |    yes    | bold/italic/strike     |
| Code blocks    |    yes    | left-bar styling       |
| Links          |    yes    | OSC 8 clickable        |
| Math           |    yes    | LaTeX → Unicode        |

## Code block

```swift
func greet(_ name: String) -> String {
    let greeting = "Hello, \(name)!"
    return greeting
}

print(greet("termdown"))
```

```python
def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

## Math

Inline math like $E = mc^2$ and $a_1 + b_2 = c_3$ render correctly.

Display math:

$$
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
$$

$$
\frac{\partial}{\partial t} \Psi = \hat{H}\,\Psi
$$

## GitHub alerts

> [!NOTE]
> Highlights information users should take into account.

> [!TIP]
> Optional advice to help users be more successful.

> [!WARNING]
> Critical content demanding immediate attention.

## Emoji shortcodes

GitHub-style shortcodes render as glyphs: ship it :rocket:, tests pass
:white_check_mark:, looks good :+1:, and :tada: for releases. Inside code they
stay literal: `:rocket:` is just text.

## Wikilinks

Obsidian-style wikilinks resolve to other Markdown files and open in-app:

- Plain: [[index]] jumps to the index document.
- Aliased: [[stress|the stress test]] shows custom text.
- With a heading: [[wikilinks#Targets]] opens that file at a section.

Press `Tab` to focus a link, then `Enter` to follow it (or click it with the
mouse). `Backspace` walks back.

## Try these keys

- `p` — open the **theme selector** and preview the 17 themes live.
- `B` — toggle **heading banners** (h1–h4 render as filled color blocks).
- `?` — the **grouped, tabbed help** overlay.

## Horizontal rule

---

That's everything.
