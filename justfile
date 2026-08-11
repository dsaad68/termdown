# Build the project
build:
    swift build

# Run the project
run:
    swift run termdown

# Build in release mode
build-release:
    swift build -c release

# Build release, copy to ./Release/, and symlink into ~/.local/bin (no sudo needed).
# Make sure ~/.local/bin is on your PATH (add to ~/.zshrc / ~/.bashrc if not already):
#   export PATH="$HOME/.local/bin:$PATH"
install:
    swift build -c release
    mkdir -p Release
    cp .build/release/termdown Release/termdown
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(pwd)/Release/termdown" "$HOME/.local/bin/termdown"
    @echo "Installed to $HOME/.local/bin/termdown"
    @echo "Make sure ~/.local/bin is on your PATH."

# Run the release binary
run-release:
    .build/release/termdown

# Run tests
test:
    swift test

# Format the code in place (SwiftFormat)
format:
    swiftformat .

# Check formatting without modifying files (used in CI)
format-check:
    swiftformat --lint .

# Lint the code (SwiftLint); --strict matches CI (warnings fail)
lint:
    swiftlint lint --strict

# Auto-fix what the tools can, then format
lint-fix:
    swiftlint lint --fix
    swiftformat .

# Run every check the way CI does: formatting, lint, tests
check: format-check lint test

# Run the CLI integration checks (Tests/Integration/cli.sh) against a debug build
integration: build
    ./Tests/Integration/cli.sh .build/debug/termdown

# Build the Linux image from the Dockerfile: the toolchain plus a built termdown
linux-image:
    docker build -t termdown-linux .

# Build that image and run the CLI integration checks inside it. Requires Docker.
linux-integration: linux-image
    docker run --rm termdown-linux

# Build the Linux version in a Swift 6.2 container: catches Linux-only compile
# errors (#if canImport, Glibc, corelibs API gaps) without leaving macOS. The build
# dir lives in a named volume (termdown-linux-build) so rebuilds stay incremental.
# Requires Docker.
#
# It builds, and deliberately does not run `swift test`. Under Docker Desktop's Linux
# VM the test *process* cannot finish: a suite completes its cases and then hangs on
# exit (proved by running the .xctest bundle line-buffered — "Executed 13 tests, with
# 0 failures", then nothing), and every test that spawns the binary through
# Foundation's `Process` hangs outright, including the one that only asks for
# `--version`. Both the serial and parallel SwiftPM runners inherit those hangs.
#
# The code is fine: the same commits are green on the x86_64 Linux CI job, which runs
# this image's `swift test` on GitHub's runners. So Linux unit tests come from CI, and
# locally the Linux check that does work is `just linux-integration` — it drives the
# built binary from bash, touching neither XCTest nor Foundation's `Process`.
linux-build:
    docker run --rm -v "$PWD":/src -w /src -v termdown-linux-build:/build \
      swift:6.2 bash -c "swift build --build-tests --build-path /build"

# Clean build artifacts
clean:
    swift package clean
