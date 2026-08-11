#!/usr/bin/env bash
#
# End-to-end checks against a built termdown binary.
#
# These exercise what the unit tests cannot: the actual executable, on the actual
# filesystem, doing the things a user's shell asks of it — rendering a document,
# reading a config file, creating one on first run, migrating an old one, and
# honouring a project-local override. They are the Linux smoke test (see
# `just linux-integration`), and they run on macOS just as well.
#
# Everything happens under a temporary HOME, so a run can never touch the config
# of the machine it runs on.
#
# Usage: Tests/Integration/cli.sh [path-to-termdown]

set -uo pipefail

BIN="${1:-.build/debug/termdown}"
if [ ! -x "$BIN" ]; then
  echo "no binary at $BIN — build first (swift build)" >&2
  exit 2
fi
BIN="$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
# `homeDirectoryForCurrentUser` ignores HOME on macOS, so HOME alone would leave
# these tests editing the config of the machine they run on. XDG_CONFIG_HOME is
# what termdown honours, and it is honoured on both platforms.
export XDG_CONFIG_HOME="$WORK/config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
CONFIG="$XDG_CONFIG_HOME/termdown/config.yaml"

passed=0
failed=0

# check <name> <expectation> — the expectation is a shell snippet; a non-zero exit
# fails the case and prints what it was looking at.
check() {
  local name="$1"
  shift
  if "$@"; then
    passed=$((passed + 1))
    printf 'ok   %s\n' "$name"
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$name"
  fi
}

# Run a command with a deadline. Without one, the bug this guards against — the
# interactive file list entered with pipes — hangs the whole run instead of failing
# it, which is exactly how it went unnoticed.
with_timeout() {
  local seconds="$1"
  shift
  "$@" &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$seconds" ]; then
      kill -9 "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

contains() { grep -qF -- "$2" <<<"$1"; }
lacks() { ! grep -qF -- "$2" <<<"$1"; }

# Strip ANSI so a check can look at the text a user sees.
plain() { sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\][^\x07\x1B]*(\x07|\x1B\\\\)//g'; }

# ── A document exercising the things this project renders ──
DOC="$WORK/doc.md"
cat >"$DOC" <<'MD'
# Heading

Some **bold** text and `code`.

> [!NOTE]
> A callout body.

| a | b |
| --- | --- |
| 1 | 2 |

```mermaid
graph TD
  A[Start] --> B[End]
```
MD

# ── The CLI surface ─────────────────────────────────────────────────────────

version_output="$("$BIN" --version 2>&1)"
expected_version="$(grep -oE 'let appVersion = "[^"]+"' "$REPO/Sources/termdown/Version.swift" \
  | sed -E 's/.*"([^"]+)".*/\1/')"
check "--version reports the built version ($expected_version)" \
  contains "$version_output" "termdown $expected_version"

help_output="$("$BIN" --help 2>&1)"
check "--help documents the render subcommand" contains "$help_output" "render"
"$BIN" --help >/dev/null 2>&1
check "--help exits 0" test $? -eq 0

"$BIN" render "$WORK/nope.md" >/dev/null 2>"$WORK/err"
status=$?
check "a missing file exits non-zero" test $status -ne 0
check "a missing file says so on stderr" contains "$(cat "$WORK/err")" "cannot read"

"$BIN" render "$DOC" "$DOC" >/dev/null 2>"$WORK/err2"
check "two actions on one command line is an error" test $? -ne 0

# ── Rendering ───────────────────────────────────────────────────────────────

rendered="$("$BIN" render "$DOC" 2>&1)"
text="$(plain <<<"$rendered")"

check "a heading is rendered" contains "$text" "Heading"
check "a table is drawn with box borders" contains "$text" "─"
check "a callout shows its header" contains "$text" "● NOTE"
check "a callout does not leak its marker" lacks "$text" "[!NOTE]"
check "a mermaid block becomes a diagram, not source" lacks "$text" "graph TD"
# The weight and a foreground in one escape — `[1;38;…` — whether the terminal
# advertised truecolor (38;2;r;g;b) or not (38;5;n).
check "bold carries a color as well as the weight" \
  grep -q $'\x1B\\[1;38;' <<<"$rendered"

plain_output="$("$BIN" render --no-color "$DOC" 2>&1)"
check "--no-color emits no escapes" test -z "$(tr -dc $'\x1B' <<<"$plain_output")"

piped="$(printf '# Piped\n\nText.\n' | "$BIN" - 2>&1)"
check "stdin renders when stdout is not a terminal" contains "$(plain <<<"$piped")" "Piped"

# ── The file list without a terminal ───────────────────────────────────────
#
# A directory argument opens the keyboard UI, which needs a terminal on both ends.
# Through a pipe it used to draw a frame and then block on a key forever.

mkdir -p "$WORK/listing"
cp "$DOC" "$WORK/listing/doc.md"
listing="$(cd "$WORK/listing" && with_timeout 10 "$BIN" . 2>&1)"
status=$?
check "a directory through a pipe does not hang" test $status -ne 124
check "a directory through a pipe lists what it found" contains "$listing" "doc.md"
check "a directory through a pipe draws no frame" lacks "$listing" $'\x1B[?1049h'

# ── The config file ─────────────────────────────────────────────────────────

check "first run creates the global config" test -f "$CONFIG"
check "the created config carries a version stamp" contains "$(cat "$CONFIG")" "config-version:"
check "the created config offers the folder-view key" \
  contains "$(cat "$CONFIG")" "file-list-view: files"

# An older file gains the keys it has never seen, keeps the values it states, and
# is stamped so it is not migrated twice.
cat >"$CONFIG" <<'YAML'
config-version: 3
theme: nord
mouse: false   # deliberate
YAML
"$BIN" render "$DOC" >/dev/null 2>&1
migrated="$(cat "$CONFIG")"
check "migration adds the new key" contains "$migrated" "file-list-view: files"
check "migration keeps an explicit value" contains "$migrated" "mouse: false"
check "migration keeps an inline comment" contains "$migrated" "# deliberate"
check "migration stamps the new version" contains "$migrated" "config-version: 4"

# The global config is honoured: no-color there means plain output with no flag.
printf 'no-color: true\n' >"$CONFIG"
check "no-color from the config reaches the renderer" \
  test -z "$(tr -dc $'\x1B' <<<"$("$BIN" render "$DOC" 2>&1)")"

# A project-local file wins over the global one, per-key.
printf 'no-color: false\ntheme: nord\n' >"$CONFIG"
mkdir -p "$WORK/project"
printf 'no-color: true\n' >"$WORK/project/.termdown.yaml"
cp "$DOC" "$WORK/project/doc.md"
local_output="$(cd "$WORK/project" && "$BIN" render doc.md 2>&1)"
check "a project-local .termdown.yaml overrides the global config" \
  test -z "$(tr -dc $'\x1B' <<<"$local_output")"

# A configured width is the width the render comes out at.
printf 'width: 40\n' >"$CONFIG"
widest="$("$BIN" render --no-color "$DOC" 2>&1 | awk '{ if (length($0) > m) m = length($0) } END { print m+0 }')"
check "a configured width bounds the output ($widest ≤ 40)" test "$widest" -le 40

# mermaid: false falls back to a code block, which shows the source verbatim.
printf 'mermaid: false\n' >"$CONFIG"
check "mermaid: false falls back to the source" \
  contains "$(plain <<<"$("$BIN" render "$DOC" 2>&1)")" "graph TD"

# ── Result ──────────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
