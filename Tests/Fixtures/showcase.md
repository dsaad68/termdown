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
| Code blocks    |    yes    | framed-box styling     |
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

## Horizontal rule

---

That's everything.
