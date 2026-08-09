# Callouts

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

## The rest of the Obsidian set

> [!INFO]
> Reads as a note — same blue.

> [!TODO]
> Still to do. Blue, like a note.

> [!ABSTRACT]
> A summary, in teal.

> [!SUCCESS]
> It worked.

> [!EXAMPLE]
> A worked example.

> [!FAILURE]
> It did not work.

> [!DANGER]
> Do not do this.

> [!BUG]
> A known defect.

## Case does not matter

> [!note]
> Lowercase tags are the same tag.

> [!Warning]
> So is mixed case.

## Custom titles

> [!TIP] Try `--width` instead
> The rest of the first line becomes the title, and it can carry **inline
> markup** of its own.

> [!EXAMPLE] A title and nothing else

## Custom tags

> [!HOUSE-STYLE] Anything else is still a callout
> An unrecognised tag keeps the plain quote colour and uses its own name as
> the title when no title is given.

> [!SIDEBAR]
> Tags with no colour of their own fall back the same way.

## Blocks inside a callout

> [!IMPORTANT] Callouts hold whole blocks
> A first paragraph.
>
> A second one, after a blank line.
>
> - a list item
> - another
>
> ```swift
> let inside = "a code block"
> ```

## Not a callout

> An ordinary blockquote is untouched.

> [!NOT VALID] A tag with a space in it is not a marker, so this stays prose.
