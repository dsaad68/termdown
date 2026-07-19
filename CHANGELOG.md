# Changelog

All notable changes to termdown are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Display width now measures grapheme clusters, not scalars.** Emoji
  sequences were summed component-by-component, so a ZWJ family counted 6
  columns and a skin-tone thumb 4, while variation-selector emoji (`❤️`, `⚠️`,
  `✔️`, `➡️`) counted 1 instead of 2 — the under-count reaching 31 of the 220
  `:shortcode:` mappings. Rows containing any of them padded to the wrong
  width, drifting the right border and scrollbar column. `wide-emoji: scalar`
  restores the old behavior for terminals that draw the components separately.
- **Combining marks outside Latin are now zero-width.** Only `U+0300–U+036F`
  was recognized, so every Hebrew, Arabic, Devanagari and Thai document
  over-counted. Hebrew points, Arabic marks, Devanagari matras, Thai vowels and
  the combining supplements are all zero-width now.
- **The status bar no longer overflows a narrow terminal.** With flags like
  NOWRAP or "N selected" present the bar could exceed the terminal width;
  autowrap is off, so it was clipped at the margin along with the frame's right
  edge. The title and flags elide first.
- **Mouse tracking survives a nested UI.** Opening the file finder from the
  pager (`T`) tore tracking down while the pager was still running, killing
  scroll, click and drag-select for the rest of the session.
- **Mermaid node shapes other than `[...]` are now parsed.** `A{"Decide"}`,
  `A("x")`, `A(["x"])`, `A[["x"]]`, `A[("x")]`, `A(("x"))`, `A{{"x"}}` and
  `A>"x"]` previously fell through the parser, so the raw syntax became the
  label — a box captioned `A{"Decide"}` rather than one reading `Decide`. Every
  shape is still *drawn* as a rectangle (as upstream mermaid-ascii does); only
  the delimiters are now stripped.
- **A `\n` inside a label no longer splits the statement.** Statement splitting
  tracked only `[`/`]` depth and ignored quotes entirely, so a multi-line label
  in `{...}` was cut in half. The tail either became a phantom disconnected node
  or, when it contained a space, tripped the bare-node-id check and dropped the
  whole diagram to a code block.
- **Quoted edge labels** now have their quotes stripped and line breaks
  flattened; `-->|"fail, retries < 2\n(with feedback)"|` rendered verbatim,
  escape and all. Edge labels draw inline along a one-row arrow, so a `\n` or
  `<br>` becomes a space rather than wrapping.

### Added
- **Mouse text selection**: with `--mouse-select` (or `mouse-select: true`),
  drag in the viewer to select text character by character — across lines and
  starting/ending mid-word — copied to the clipboard on release. `y`/`Y`
  re-copy the selection and any other key clears it; a click that doesn't move
  still follows the link under it. Off by default and independent of `mouse`,
  since motion reporting replaces the terminal's own click-drag selection.
- `Ansi.bgRange` tints a display-column range while preserving the SGR
  attributes underneath, so a selection drawn over a code block keeps its
  syntax highlighting.

## [0.1.5] - 2026-06-22

### Added
- **Mermaid diagrams**: ` ```mermaid ` fenced blocks now render as ASCII/Unicode
  art instead of plain source. Supports flowcharts (`graph`/`flowchart` TD/LR
  with labeled, chained and grouped edges, `subgraph` grouping and `classDef`
  styling) and `sequenceDiagram`. Implemented as a self-contained native Swift
  port of [mermaid-ascii](https://github.com/AlexanderGrooff/mermaid-ascii)
  (MIT) in a new `MermaidRenderer` module — no external binary required. Diagrams
  are drawn inside a labeled card; unsupported diagram types (and parse errors)
  fall back to the previous highlighted code block. Configurable via the new
  `mermaid` (on/off) and `mermaid-charset` (`unicode`/`ascii`) settings.

### Changed
- Fenced code blocks (and mermaid diagram cards) now render as a **complete
  box** — a labelled top rule, full-height left **and right** borders, and a
  closing floor — spanning the full text column, instead of the previous
  open left-bar card. The box grows to fit content wider than the column.

### Fixed
- **File finder**: typing a filter that contains `q`, `Q` or `c` no longer quits
  the app (and `j`/`k`/`g`/`G` no longer move the selection instead of typing).
  Filtering is now modal — press `/` to focus the search box, where every
  printable key types into the query; the list/navigation keys work outside it.
  Relatedly, Ctrl-C is no longer mis-decoded as a literal `c` (it is delivered as
  `SIGINT`).

## [0.1.4] - 2026-06-22

### Added
- **Cursor mode**: press `v` to toggle a line cursor (off by default — `j`/`k`
  scroll until then). With it shown, `j`/`k` move the highlighted line and its
  source line is reported as `L42`.
- **Line selection & copy**: `Shift+↑/↓` (or `Shift+J`/`Shift+K`) select multiple
  lines; `y` copies the selection as raw markdown and `Y` as rendered text.
- **Inline editing**: press `e` to edit the block under the cursor (paragraph,
  heading, list item, table row, …) as raw markdown in place while the rest stays
  rendered. `Enter` commits to the buffer and marks the document unsaved (●),
  `Esc` cancels, `Ctrl-S` writes to disk, and quitting with unsaved changes
  prompts to Save / Discard / Cancel.
- New rebindable actions `edit` (`e`) and `cursor` (`v`).

## [0.1.2] - 2026-06-19

### Fixed
- Right border of the file finder (and the outer frame) no longer disappears
  under tmux. The full-screen renderer cleared each line *after* drawing it
  (`ESC[K`) and erased below after the last row (`ESC[J`); with autowrap disabled
  the cursor parks on the last column of a full-width row, so those erases deleted
  the right-border column and the bottom-right corner. tmux honored this strictly
  while iTerm2 was forgiving, so it only showed under tmux. Lines are now cleared
  *before* their content, and the clear-below runs only when the frame is shorter
  than the screen.

## [0.1.1] - 2026-06-19

### Fixed
- Full-screen redraw no longer corrupts while scrolling past lines containing
  wide emoji. Emoji below U+1F300 that terminals render double-width (e.g. ✅
  U+2705) were counted as a single column, so a line containing one overflowed
  its padded row; the terminal then wrapped that row and scrolled the view out
  of sync — most visible inside a tmux `display-popup`. Autowrap is now disabled
  on the alternate screen (a robust guard against any width miscount) and the
  width table covers these code points, with variation selectors counted as
  zero-width.

## [0.1.0] - 2026-06-18

Initial release.

### Added
- Recursive Markdown file finder with a fuzzy filter and project-wide live grep.
- Full terminal rendering via swift-markdown: headings, emphasis, lists/task lists,
  fenced code with syntax highlighting (Chroma), GFM tables, block quotes, GitHub
  alerts, footnotes, frontmatter, math (`$…$` / `$$…$$` → Unicode), and OSC 8 links.
- Pager with incremental search, heading navigation, outline sidebar, collapsible
  sections, tabs, link/wikilink navigation, line wrap and width controls, follow
  mode, mouse support, and OSC 52 clipboard copy.
- 17 color themes with a live-preview in-app selector, 24-bit truecolor when the
  terminal supports it, emoji shortcodes, and heading banners.
- `.termdown.yaml` configuration (global + project-local) with rebindable keys.
- Linux support: the executable builds and runs on Linux (Glibc) as well as
  macOS (Darwin).
- Version shown in the file-list window header, alongside the `termdown --version`
  / `-V` output.
- SwiftLint + SwiftFormat configuration and `just` recipes (`format`, `format-check`,
  `lint`, `lint-fix`, `check`).
- CI builds and tests on macOS **and** Linux, with a dedicated lint job.
- MIT `LICENSE`, `CONTRIBUTING.md`, and this `CHANGELOG.md`.
- Release workflow that publishes prebuilt macOS + Linux binaries on a `v*` tag and
  updates the Homebrew tap.

[Unreleased]: https://github.com/dsaad68/termdown/compare/v0.1.5...HEAD
[0.1.5]: https://github.com/dsaad68/termdown/releases/tag/v0.1.5
[0.1.4]: https://github.com/dsaad68/termdown/releases/tag/v0.1.4
[0.1.2]: https://github.com/dsaad68/termdown/releases/tag/v0.1.2
[0.1.1]: https://github.com/dsaad68/termdown/releases/tag/v0.1.1
[0.1.0]: https://github.com/dsaad68/termdown/releases/tag/v0.1.0
