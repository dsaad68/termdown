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

# Clean build artifacts
clean:
    swift package clean
