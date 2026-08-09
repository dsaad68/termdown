# Callouts

A blockquote whose first line opens with a `[!TAG]` marker renders as a
callout: a colored bar down the left and a `● TITLE` header.

## GitHub's five

> [!NOTE]
> Useful information that users should know, even when skimming content.

> [!TIP]
> Helpful advice for doing things better or more easily.

> [!IMPORTANT]
> Key information users need to know to achieve their goal.

> [!WARNING]
> Urgent info that needs immediate user attention to avoid problems.

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.

## The rest of the set

Ten more tags carry colors of their own — Obsidian's vocabulary, plus
`DECISION` for notes and plans that record one. Tags that mean the same thing
share a color, so the palette stays a legible six rather than a rainbow nobody
can tell apart at a glance.

> [!INFO]
> Reads as a note — the same blue.

> [!TODO]
> Something still to do. Blue, like a note.

> [!ABSTRACT]
> A summary or a TL;DR. Teal, the one color with no counterpart among the five.

> [!SUCCESS]
> It worked. Green, like a tip.

> [!EXAMPLE]
> A worked example. Mauve, like an important.

> [!QUESTION]
> Something still open. Yellow, like a warning.

> [!DECISION]
> Something settled, and why. Mauve, like an important.

> [!FAILURE]
> It did not work.

> [!DANGER]
> Do not do this.

> [!BUG]
> A known defect. Red, like a caution.

## Case does not matter

Tags are matched case-insensitively, so an Obsidian vault written in lowercase
renders the same as a GitHub README written in caps.

> [!note]
> `[!note]`, `[!Note]` and `[!NOTE]` are all the same tag.

## Custom titles

Whatever follows the tag on that first line becomes the title, in place of the
tag's own name.

> [!TIP] Try `--width 100` instead
> The title is markup, not a string, so it can carry **bold**, *italic* and
> `code` like any other line.

> [!WARNING] A title is enough on its own

## Custom tags

An unrecognized tag is still a callout. It takes the plain quote color and uses
its own name as the title, so house-style tags read sensibly here rather than
leaking `[!MYTAG]` into the prose.

> [!HOUSE-STYLE] Anything else is still a callout
> Only the color is shared with ordinary blockquotes — the marker is still
> consumed, and a custom title still works.

> [!SIDEBAR]
> Tags with no color of their own fall back the same way.

## Callouts hold whole blocks

> [!IMPORTANT] Not just one paragraph
> A callout wraps everything in the blockquote, not only its first line.
>
> A second paragraph, after a blank line. The bar continues through the gap.
>
> - a list item
> - another one
>
> ```swift
> let inside = "a fenced code block, highlighted as usual"
> ```

## What is not a callout

A tag has to be a single word at the very start of the quote. Anything else is
ordinary prose and survives verbatim.

> An ordinary blockquote is untouched.

> [!NOT VALID] A tag with a space in it is not a marker, so this stays prose.
