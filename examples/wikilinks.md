# Wikilinks demo

termdown supports Obsidian-style `[[wikilinks]]` that resolve to other Markdown
files discovered in the directory and open **in-app**. Focus a link with `Tab`
and press `Enter` (or click it); `Backspace` goes back.

## Targets

These resolve to the sibling example files:

- [[index]] — the directory index.
- [[showcase]] — the full feature showcase.
- [[stress]] — the stress-test document.

## Aliases

Use `|` to show custom link text:

- [[showcase|the big showcase]]
- [[stress|render stress test]]

## Heading anchors

Append `#Heading` to jump to a section after the file loads:

- [[showcase#Emoji shortcodes]]
- [[showcase#GitHub alerts]]

## Same-document anchors

A bare `[[#Heading]]` jumps within *this* file:

- [[#Targets]] — back up to the Targets section.
- [[#Aliases]] — to the Aliases section.

## Unresolved links

A name with no matching file renders but stays inert (nothing happens on Enter):

- [[NoSuchDocument]]
