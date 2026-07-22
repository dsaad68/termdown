import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import termdownCore
import MermaidRenderer

// MARK: - Argument parsing

var config: Config
switch Config.parse(CommandLine.arguments.dropFirst()) {
case .success(let parsed):
    config = parsed
case .failure(let message, let code):
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

// MARK: - Load config file and merge with CLI arguments

let appConfig = AppConfig.load()
if config.themeName == nil {
    config.themeName = appConfig.theme
}
if config.width == nil {
    config.width = appConfig.width
}
if !config.noColor {
    config.noColor = appConfig.noColor ?? false
}
// CLI flag wins; fall back to yaml; default = true (on). Both keys move together
// so the finder and the viewer behave the same: `TerminalMenu`/`LiveGrep` gate on
// `mouse` alone, so shipping only `mouse-select` would leave the finder mouse-dead.
if config.mouse == nil {
    config.mouse = appConfig.mouse ?? true
}
if config.mouseSelect == nil {
    config.mouseSelect = appConfig.mouseSelect ?? true
}
let mouseEnabled = config.mouse ?? true
let mouseSelectEnabled = config.mouseSelect ?? true

// Viewer key rebindings (config `key-<action>: <char>`) → canonical-key translation.
let keyTranslation = KeyBindings.translation(from: appConfig.keyBindings)

// MARK: - Render context (theme, banners, mermaid — all live-mutable)

let renderContext = RenderContext(
    themeName: config.themeName,
    // Mermaid diagram rendering (config-driven; defaults to on + Unicode).
    mermaidEnabled: appConfig.mermaid ?? true,
    mermaidCharset: (appConfig.mermaidCharset == "ascii") ? .ascii : .unicode
)

// MARK: - Help and version

if config.showHelp {
    print(Config.usage)
    exit(0)
}

if config.showVersion {
    print("termdown \(appVersion)")
    exit(0)
}

// Apply color setting
Ansi.colorEnabled = !config.noColor

// Emoji width mode: `scalar` restores legacy per-scalar summing for terminals
// that draw the components of a ZWJ sequence separately. Both measurement
// tables have to move together — a diagram measured one way inside a document
// measured the other has its borders off by a cell on every emoji row.
if appConfig.wideEmoji?.lowercased() == "scalar" {
    Ansi.emojiWidthMode = .scalar
    DisplayWidth.emojiWidthMode = .scalar
}

// Detect 24-bit color support so content + chrome render in true color when the
// terminal advertises it (most modern terminals set COLORTERM=truecolor/24bit).
if let colorterm = ProcessInfo.processInfo.environment["COLORTERM"]?.lowercased() {
    Ansi.truecolor = colorterm.contains("truecolor") || colorterm.contains("24bit")
}

// MARK: - Everything the entry points need, in one value

let env = AppEnvironment(
    width: config.width,
    mouseEnabled: mouseEnabled,
    mouseSelectEnabled: mouseSelectEnabled,
    keyTranslation: keyTranslation,
    ignorePatterns: appConfig.ignorePatterns ?? [],
    render: renderContext
)

// MARK: - Decide what to do

// Standardize the path once, up front, so the decision and every message it
// produces speak in the same terms.
let requested = config.action.mappingPath { URL(fileURLWithPath: $0).standardizedFileURL.path }

let resolved: ResolvedAction
switch ActionResolver.resolve(requested,
                              bareRender: appConfig.bareRender ?? false,
                              stdinIsTTY: isatty(STDIN_FILENO) != 0,
                              cwd: FileManager.default.currentDirectoryPath,
                              kind: PathKind.of) {
case .action(let action):
    resolved = action
case .failure(let message, let code):
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

switch resolved {
case .stdin:
    runStdin(env: env)

case .render(let file):
    renderToStdout(file, env: env)

case .view(let file):
    let url = URL(fileURLWithPath: file).standardizedFileURL
    let session = FolderSession(root: url.deletingLastPathComponent(), env: env)
    withTerminalUI { session.view(url) }

case .picker(let directory):
    let root = URL(fileURLWithPath: directory, isDirectory: true).standardizedFileURL
    let session = FolderSession(root: root, env: env)
    // Checked before the alternate screen, so the message survives on the
    // normal one.
    guard !session.isEmpty else {
        print("No markdown files found under \(root.path)")
        exit(0)
    }
    withTerminalUI { session.runPicker() }
}
