# Task list

A page for trying out **checkbox toggling**. Press `v` to show the line cursor,
move to a task with `j`/`k` (or the arrow keys), then press `Space` to tick it
off. The header shows **●** once something is unsaved; `Ctrl-S` writes the change
back to this file, and `q` offers to save or discard.

Outside cursor mode `Space` still pages down, and so do `f` and `PgDn` even with
the cursor on a task.

## Groceries

- [ ] Milk
- [x] Coffee beans
- [ ] Bread

## Nested items

A child toggles itself, not its parent:

- [ ] Ship the release
  - [x] Write the changelog
  - [ ] Tag the version
  - [ ] Update the tap

## Ordered tasks

The bullet style is preserved exactly as written — `1.`, `2)`, `*` and `+` all
survive a toggle:

1. [x] Draft the outline
2. [ ] Fill in the details
3. [ ] Proofread

* [ ] Star bullet
+ [ ] Plus bullet

## Wrapped items

A task long enough to wrap over several rendered rows can be toggled from any of
them, because the whole item shares one source line:

- [ ] Investigate why the terminal reports a different width than the one the
      pager was told about, then decide whether the status bar should trust the
      resize event or re-measure on the next frame.
- [x] Confirm that a wrapped item's continuation rows resolve to the same
      checkbox as its first row.

## Not tasks

These lines look close but are left alone — `Space` pages down instead:

- A plain bullet
- [A link](https://example.com), not a checkbox
- [[wikilinks]] stay links
- [?] an unknown marker
