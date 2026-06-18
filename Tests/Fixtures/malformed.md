# Malformed input should degrade gracefully

An unclosed code fence:

```swift
let x = 1
func greet() { print("hello") }

A paragraph after the unclosed fence keeps going without a closing ``` line.

## Broken table

| header a | header b |
|---|
| only one cell
| a | b | c |

## Mismatched emphasis

This has **bold that never closes and *italic too.

A [link without a closing paren](https://example.com and trailing text.

## Stray characters

Some $ dollars and a lone ~ tilde and an _underscore_ in the middle.
