# Changelog

All notable changes to termdown are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/dsaad68/termdown/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/dsaad68/termdown/releases/tag/v0.1.4
[0.1.2]: https://github.com/dsaad68/termdown/releases/tag/v0.1.2
[0.1.1]: https://github.com/dsaad68/termdown/releases/tag/v0.1.1
[0.1.0]: https://github.com/dsaad68/termdown/releases/tag/v0.1.0
