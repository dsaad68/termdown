# termdown

[![CI](https://github.com/dsaad68/termdown/actions/workflows/ci.yml/badge.svg)](https://github.com/dsaad68/termdown/actions/workflows/ci.yml)
![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-blue)
![Swift](https://img.shields.io/badge/swift-6.2%2B-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A minimal terminal Markdown browser written in **pure Swift**. It lists every
Markdown file under the current directory, lets you pick one with the arrow keys,
and renders it **natively in the terminal** as styled ANSI text.

<p align="center">
  <video src="https://github.com/dsaad68/termdown/raw/main/examples/demo.mp4" width="800" controls muted>
    <a href="https://github.com/dsaad68/termdown/raw/main/examples/demo.mp4">Watch the termdown demo</a>
  </video>
</p>

## Install

### Homebrew (macOS and Linux)

```sh
brew install dsaad68/termdown/termdown
```

Upgrade later with `brew upgrade termdown`.

### From source

Requires a Swift 6.2+ toolchain (see [Requirements](#requirements)).

```sh
swift build -c release
cp .build/release/termdown /usr/local/bin/termdown   # or: just install
```

`just install` builds the release binary and symlinks it into `~/.local/bin`
(no `sudo` required). To run straight from a clone without installing:

```sh
swift run termdown            # scan the current directory
swift run termdown ~/notes    # scan a specific directory
```

## Features

- Recursively finds `.md` / `.markdown` / `.mdx` … files in the current folder
  (skips `.git`, `node_modules`, `.build`, etc.).
- **Fuzzy file finder** with real-time filtering and match highlighting.
- Full terminal rendering powered by Apple's [swift-markdown] parser:
  - Headings with colored underlines
  - **Bold**, *italic*, ~~strikethrough~~, `inline code`
  - Bullet / ordered / nested lists and `- [ ]` task lists
  - Fenced code blocks with **syntax highlighting** across ~35 languages
    (via [Chroma]), drawn as a framed card and mapped onto the matte palette
  - GFM tables drawn with box-drawing borders and column alignment
  - Block quotes (including nested)
  - **GitHub alerts**: `> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, etc. as colored callouts
  - YAML frontmatter displayed as a metadata panel
  - Thematic breaks (horizontal rules)
  - Links as clickable OSC 8 hyperlinks
  - Footnotes rendered in a dedicated section
  - **Math** (`$…$` / `$$…$$`) converted to Unicode: Greek, super/subscripts,
    `\frac`, `\sqrt`, accents and common operators
- **Tabs**: open multiple documents side by side. `T` opens the file finder in a
  new tab, `Shift-Enter` (or `O`) opens the focused link in a new tab. Switch with
  `1`–`9` / `}` / `{` and close with `x`. Once a second tab is open the **footer**
  shows a tab strip (active tab highlighted).
- **Navigation**:
  - `t` opens a **Contents / Open Tabs** overlay: the document outline plus the
    list of open tabs; press `t` again to switch between the two panes
  - **Toggleable outline sidebar** (press `s`) that highlights the section
    you're currently reading as you scroll
  - **Collapsible sections**: `z` folds/unfolds the current section (or the
    one selected in the sidebar); `Z` collapses to a top-level outline
  - Heading-to-heading navigation (`]`/`[`)
  - In-document **incremental search** (`/` to search live, `n`/`N` for next/previous)
- **Copy to clipboard** (works over SSH via OSC 52): `y` yanks the code block
  nearest the cursor, `Y` yanks the focused link's URL
- **Doc browser / link navigation**:
  - `Tab`/`Shift-Tab` cycle between links in the document
  - `Enter`/`o` opens the focused link: external URLs launch in your browser,
    while relative links to other Markdown files open **in-app**
  - **Wikilinks**: `[[Page]]`, `[[Page|alias]]` and `[[Page#Heading]]` resolve to a
    discovered Markdown file (matched by name) and open in-app; `[[Page#Heading]]`
    jumps to that section after loading
  - `Backspace` walks back through your navigation history
- **Project-wide search** (`\`): a live "grep" across every discovered Markdown
  file, showing `file:line` matches with a preview; `Enter` jumps straight into
  that file at the match
- **Runtime layout controls**:
  - `w` toggles line wrapping (chop long lines; `←`/`→` scroll horizontally)
  - `+`/`-` adjust the text column width for comfortable reading
  - `F` toggles **follow mode** (`tail -f`-style auto-scroll to the bottom on reload)
- **Live reload**: automatically reloads when file changes
- **Color themes** (17): dark, light, mono; popular ports (catppuccin, rose-pine,
  nord, tokyo-night, gruvbox, dracula); and custom true-color pastels across matte,
  cold and warm families (matte-rose, matte-slate, frost, mint, dusk, blossom,
  sand, coral). Press `p` in the viewer for a live-preview **theme selector** that
  saves your pick. 24-bit color is used automatically when the terminal supports
  it (`COLORTERM`)
- **Configurable**: supports `.termdown.yaml` (project root or home dir) for default settings
- **Tests**: comprehensive test coverage for core functionality

## Requirements

- **macOS 13+** (Swift 6.2+ / Xcode 16+), or
- **Linux** with a Swift 6.2+ toolchain

  (the Swift floor is set by the [Chroma] syntax-highlighting dependency; the
  package manifest itself still declares `swift-tools-version:5.9`.)

## Usage

### Keybindings

| Context        | Key                          | Action                         |
|----------------|------------------------------|--------------------------------|
| File list      | Type text                    | fuzzy filter files             |
| File list      | `↑`/`↓` or `k`/`j`           | move selection                 |
| File list      | `g` / `G`                    | jump to first / last           |
| File list      | `Enter`                      | open the selected file         |
| File list      | `\`                          | project-wide search (live grep)|
| File list      | `q` / `Esc`                  | quit                           |
| Viewer (pager) | `↑`/`↓` or `k`/`j`           | scroll one line                |
| Viewer (pager) | `Space`/`PgDn`, `b`/`PgUp`   | scroll one page                |
| Viewer (pager) | `d` / `u`                    | scroll half a page             |
| Viewer (pager) | `←`/`→` or `h`/`l`           | scroll horizontally (no-wrap)  |
| Viewer (pager) | `g`/`Home`, `G`/`End`        | top / bottom                   |
| Viewer (pager) | `:`+number+`Enter`           | jump to line N                 |
| Viewer (pager) | `Ctrl-L`                     | force redraw                   |
| Viewer (pager) | `/`                          | incremental search (live)      |
| Viewer (pager) | `n` / `N`                    | next / previous search match   |
| Viewer (pager) | `\`                          | project-wide search (live grep)|
| Viewer (pager) | `Tab` / `Shift-Tab`          | cycle to next / previous link  |
| Viewer (pager) | `Enter` / `o`                | open the focused link in place |
| Viewer (pager) | `O` / `Shift-Enter`          | open the focused link in a new tab |
| Viewer (pager) | `T`                          | open a document in a new tab   |
| Viewer (pager) | `1`–`9`                      | jump to tab N                  |
| Viewer (pager) | `}` / `{`                    | next / previous tab            |
| Viewer (pager) | `x`                          | close current tab              |
| Viewer (pager) | `y`                          | copy code block nearest cursor |
| Viewer (pager) | `Y`                          | copy focused / nearest link URL|
| Viewer (pager) | `Backspace`                  | navigate back (history)        |
| Viewer (pager) | `t`                          | Contents / Open Tabs overlay (`t` switches panes) |
| Viewer (pager) | `s`                          | toggle outline sidebar         |
| Viewer (pager) | `s` (sidebar open)           | focus sidebar (↑↓ move, Enter jump, `z` fold, Esc unfocus, `q` close) |
| Viewer (pager) | `z`                          | fold / unfold current section  |
| Viewer (pager) | `Z`                          | fold all / unfold all sections |
| Viewer (pager) | `]` / `[`                    | next / previous heading         |
| Viewer (pager) | `w`                          | toggle line wrap               |
| Viewer (pager) | `+` / `-`                    | widen / narrow text column     |
| Viewer (pager) | `F`                          | toggle follow mode (tail)      |
| Viewer (pager) | `B`                          | toggle heading banners (h1–h4 as filled color blocks) |
| Viewer (pager) | `p`                          | theme selector (live preview, `Enter` saves to config) |
| Viewer (pager) | `q` / `Esc`                  | close sidebar, else extra tab, else back to the file list |
| Viewer (pager) | `?`                          | show help                      |

### Command-line options

```sh
termdown [options] [directory]
termdown render <file.md>
termdown -                    # read from stdin

Options:
  --width N         Set terminal width (default: auto-detect)
  --theme NAME      Set color theme: dark, light, mono, catppuccin, rose-pine,
                    nord, tokyo-night, gruvbox, dracula, matte-rose, matte-slate,
                    frost, mint, dusk, blossom, sand, coral
  --no-color        Disable ANSI colors
  --mouse           Enable mouse scroll
  --no-mouse        Disable mouse scroll
  --version, -V     Show version information
  --help, -h        Show help message
```

### Configuration

On first run termdown automatically creates a global config file at
`~/.config/termdown/config.yaml` with commented defaults:

```yaml
# termdown configuration
theme: dark       # see the full theme list below
# width: 80      # uncomment to fix column width
no-color: false
mouse: false      # true to enable mouse scroll
# ignore-patterns: [vendor, "*.snap", archive]   # extra paths to skip
```

### Config keys

| Key | Type | Values | Effect |
|---|---|---|---|
| `theme` | string | see Themes below | Content color palette (unknown values fall back to `dark`) |
| `width` | int | e.g. `80` | Fixes the text column width; omit for auto-detect |
| `no-color` | bool | `true`/`false` | Disables all ANSI color |
| `mouse` | bool | `true`/`false` | Mouse scroll in the finder and pager |
| `ignore-patterns` | list | `[a, b, c]` | Extra path patterns to skip during file discovery (beyond the built-in `.git`/`node_modules`/`.build` skips) |

**Themes:** `dark`, `light`, `mono`; ports: `catppuccin`, `rose-pine`, `nord`,
`tokyo-night`, `gruvbox`, `dracula`; custom pastels: matte (`matte-rose`,
`matte-slate`), cold (`frost`, `mint`, `dusk`), warm (`blossom`, `sand`, `coral`).
Press `p` in the viewer to preview/switch live.

**Custom viewer keys.** Bind a key to a viewer action with `key-<action>: <char>`
(the action's default key keeps working; overrides add a key). This applies to
the pager only, not text-entry contexts (search / the fuzzy file list).

```yaml
key-scroll-down: e     # 'e' now scrolls down too (j still works)
key-theme: _           # open the theme selector with '_'
```

Rebindable actions: `scroll-down`, `scroll-up`, `page-down`, `page-up`,
`half-down`, `half-up`, `top`, `bottom`, `search`, `next-match`, `prev-match`,
`project-search`, `open-link`, `new-tab`, `theme`, `sidebar`, `wrap`, `follow`,
`banner`, `fold`, `fold-all`, `next-heading`, `prev-heading`, `contents`, `help`, `quit`.

Booleans accept `true`/`yes`/`on`/`1` as true. The config reader is **flat**:
`key: value` lines only, so `ignore-patterns` must be inline (`[...]` or a
comma-separated list), not a multi-line `- item` block. Aliases: `no-color` =
`nocolor` = `no_color`; `ignore-patterns` = `ignorepatterns` = `ignore_patterns`.

To override settings for a specific project, create a `.termdown.yaml` in that
directory. It is merged on top of the global config: only the keys you set
take effect, everything else falls back to the global config:

```yaml
# .termdown.yaml (project root)
mouse: true
width: 100
```

**Priority order** (highest to lowest):
1. CLI flags (`--mouse`, `--no-color`, etc.)
2. Project-local `.termdown.yaml` in the current directory
3. Global `~/.config/termdown/config.yaml`

### Render a single file to stdout

Useful for piping or quick previews:

```sh
swift run termdown render path/to/file.md
swift run termdown render README.md | less -R
```

## Notes

- Math (`$…$` inline / `$$…$$` display) is converted to Unicode: Greek letters,
  super-/subscripts, `\frac`, `\sqrt`, accents and the common operators/relations.
  Commands without a Unicode form (and spacing macros markdown strips, like `\,`)
  degrade gracefully rather than disappearing.
- **Tabs**: `T` opens the file finder and loads the chosen document in a new tab;
  `Shift-Enter` (or `O`) opens the focused link in a new tab. `1`–`9` jump to a tab,
  `}` / `{` cycle, `x` closes the current one, and `q` peels back a layer at a time
  (sidebar → extra tab → file list). The tab strip is shown only when 2+ tabs are open.
  Each tab keeps its own scroll position, folds, sidebar state and search.
  Note: most terminals (Apple Terminal, default iTerm2) send the same bytes for
  `Enter` and `Shift-Enter`, so `Shift-Enter` only opens a new tab on terminals that
  report it distinctly (kitty keyboard protocol / xterm `modifyOtherKeys`); use `O`
  as the universal equivalent.
- **Copy to clipboard**: `y` copies the code block nearest the cursor; `Y` copies
  the focused (or nearest visible) link URL. Uses OSC 52 so it works over SSH, with
  a `pbcopy` fallback on macOS.
- **Folding**: `z` collapses/expands the section the cursor is in (or the selected
  heading in the outline sidebar); `Z` collapses the whole document to a top-level
  outline, or expands it again.
- Clickable links use the OSC 8 escape; terminals that don't support it simply
  show the underlined link text.
- **Link navigation**: `Tab` cycles links; `Enter`/`o` opens the focused one.
  Relative links to other Markdown files are followed in-app (use `Backspace`
  to go back); everything else is handed to the system (`open`) to launch in
  your browser. Link cycling requires colors (it relies on OSC 8 markers, so it
  is disabled under `--no-color`).
- **Outline sidebar** (`s`) and **wrap/width/follow** controls (`w`, `+`/`-`,
  `F`) only affect the interactive viewer, not `render` output.
- **Mouse** is off by default. Enable it with `--mouse` on the CLI or
  `mouse: true` in `.termdown.yaml`. It works in both the file list and the
  viewer (pager): the wheel scrolls, and a **click** follows the link under the
  cursor (pager) or selects a file, and clicking the highlighted file opens it
  (list). Mouse reporting uses SGR 1006 mode; terminals that don't support it
  will just ignore the escape sequences.
- Live reload monitors the file modification time and reloads when changed.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow. In short:

```sh
just test     # swift test
just check    # format-check + lint (strict) + test; run before a PR
just format   # apply SwiftFormat;  just lint runs SwiftLint --strict
```

The project is structured as a Swift Package with a library target (`termdownCore`),
an executable target (`termdown`), and two test targets: `termdownCoreTests` (the
library) and `termdownTests` (the executable's UI logic, via `@testable import`).
Source files are kept small and single-purpose (≤300 lines); larger types are split
across `Type+Concern.swift` extensions. Linting/formatting is configured in
`.swiftlint.yml` and `.swiftformat`, and CI runs the same checks on macOS and Linux.

### Snapshot tests

`SnapshotTests` renders the fixtures under `Tests/Fixtures/*.md` to ANSI and compares
them against committed `.ansi` golden files, so any change in rendered output is
caught. After an **intentional** rendering change, regenerate the goldens:

```sh
TD_UPDATE_SNAPSHOTS=1 swift test
```

Review the resulting diff before committing.

[swift-markdown]: https://github.com/apple/swift-markdown
[Chroma]: https://github.com/onevcat/Chroma
