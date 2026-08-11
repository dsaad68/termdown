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

# Build & test the Linux version in a Swift 6.2 container. The build dir lives in
# a named volume (termdown-linux-build) so rebuilds stay incremental. Requires Docker.
#
# The *build* is reliable and worth running. The test run is not, on an aarch64 host
# (Apple Silicon + Docker Desktop): the XCTest process blocks in poll partway through
# even a suite of pure string tests, whichever way it is launched — the serial runner
# hangs before the first test, the parallel runner's workers wedge at 0% CPU once a
# few have accumulated, and running the .xctest bundle directly hangs too. It is the
# environment, not the suite: the same commit runs green on the x86_64 Linux CI job.
#
# So: trust CI for Linux unit tests, and use `just linux-integration` locally — those
# checks drive the built binary instead of XCTest, and they do complete here.
linux-build:
    docker run --rm -v "$PWD":/src -w /src -v termdown-linux-build:/build \
      swift:6.2 bash -c "swift build --build-path /build && swift test --parallel --build-path /build </dev/null"

# Clean build artifacts
clean:
    swift package clean
