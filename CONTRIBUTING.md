# Contributing to termdown

Thanks for your interest in improving termdown! This document covers the local
workflow, the tooling, and the conventions the codebase follows.

## Prerequisites

- **macOS 13+** or **Linux** with a **Swift 6.2+** toolchain
- [`just`](https://github.com/casey/just) (optional, for the task recipes)
- [SwiftLint](https://github.com/realm/SwiftLint) and
  [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) for linting/formatting
  (`brew install just swiftlint swiftformat`)

## Build, run, test

```sh
just build          # swift build
just run            # swift run termdown
just test           # swift test
just build-release  # swift build -c release
just install        # build release + symlink into ~/.local/bin
```

Without `just`, the underlying commands are plain `swift build` / `swift run` /
`swift test`.

## Linting & formatting

SwiftFormat owns pure formatting; SwiftLint catches correctness/smell issues. Both
are configured to respect the codebase's deliberately compact style (`.swiftformat`
and `.swiftlint.yml`).

```sh
just format        # apply SwiftFormat in place
just format-check  # verify formatting (no writes) — what CI runs
just lint          # SwiftLint in --strict mode (warnings fail) — what CI runs
just lint-fix      # auto-fix what the tools can, then format
just check         # format-check + lint + test (run this before opening a PR)
```

CI (`.github/workflows/ci.yml`) runs the same checks on macOS **and** Linux, plus a
dedicated lint job. Please make sure `just check` is green before pushing.

## Code conventions

- Source files are kept **small and single-purpose (≤ ~300 lines)**; larger types
  are split across `Type+Concern.swift` extensions (e.g. `AnsiRenderer+Blocks.swift`).
- The project favors a **compact style**: single-line function bodies, hand-aligned
  palette tables, and dense numeric literals. The lint config is tuned for this — if
  you see a formatting rule fighting an intentional choice, raise it in the PR rather
  than reflowing swathes of unrelated code.
- Platform-specific code uses `#if canImport(Darwin) … #elseif canImport(Glibc) …`
  so the executable builds on both macOS and Linux. Terminal-only features (e.g. the
  `pbcopy` clipboard fallback) stay guarded by `#if canImport(Darwin)`.
- Colors go through `Ansi.Color` (256-palette or truecolor). Content colors live in
  `Theme`; TUI chrome colors live in `Ansi.Pastel`.

## Tests

The package has two test targets: `termdownCoreTests` (the library) and
`termdownTests` (the executable's UI logic, via `@testable import termdown`).

`SnapshotTests` renders the fixtures under `Tests/Fixtures/*.md` to ANSI and compares
them against committed `.ansi` goldens. After an **intentional** rendering change,
regenerate the goldens and review the diff before committing:

```sh
TD_UPDATE_SNAPSHOTS=1 swift test
```

> Snapshot goldens are generated in 256-color mode (truecolor off), so they stay
> byte-stable across terminals.

`FrameGoldenTests` does the same for assembled **pager frames**, under
`Tests/Fixtures/frames/*.frame`, and uses the same environment variable. It
complements the width sweep in `PagerDrawingTests`: the sweep proves every row
measures exactly `cols`, but it measures with `Ansi.width` itself, so it cannot
notice a frame that is correctly sized and visually wrong.

Two golden sets are **not** regenerable and must never be rewritten to make a
test pass:

- `Tests/MermaidRendererTests/testdata/` — 99 fixtures copied verbatim from
  upstream mermaid-ascii. They encode upstream fidelity, so a diff there means
  the port has diverged, not that the golden is stale. There is deliberately no
  regeneration path.
- Width behavior — `WidthTests` asserts what terminals actually draw for emoji
  and combining marks. If one fails, the table is wrong; the expectation is not
  a snapshot to be refreshed.

## Releases

The version lives in `Sources/termdown/Version.swift` (`appVersion`). To cut a
release, bump that constant and push a matching `v*` tag (e.g. `v0.1.0` ↔
`appVersion = "0.1.0"`). The release workflow verifies the two match, builds macOS +
Linux binaries, publishes a GitHub Release, and updates the Homebrew tap. See
`CHANGELOG.md` for the running history.
