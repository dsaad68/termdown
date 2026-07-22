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

// `bare-render`: a positional argument naming a file rather than a directory is
// treated as `render <file>`. Gated on the file already existing and not being a
// directory, so `termdown ~/notes` keeps opening the picker and a typo still
// reaches the "no such file or directory" error below rather than being read as
// a document. This cannot live in the parse loop above — `appConfig` is not
// loaded yet there — and must run before the stdin auto-detect, which branches
// on `config.renderFile == nil`.
if config.renderFile == nil, let positional = config.directory, appConfig.bareRender ?? false {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: positional, isDirectory: &isDirectory),
       !isDirectory.boolValue {
        config.renderFile = positional
        config.directory = nil
    }
}

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

// MARK: - Stdin detection

func isStdinTTY() -> Bool {
    return isatty(STDIN_FILENO) != 0
}

// Auto-detect stdin if not a TTY and no directory/render file specified
if !isStdinTTY() && config.directory == nil && config.renderFile == nil {
    config.useStdin = true
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

// MARK: - Stdin handling

if config.useStdin {
    runStdin(env: env)
    exit(0)
}

// MARK: - `render` subcommand: render a single file to stdout and exit.
// Usage: termdown render <file.md>   (handy for piping / scripting)
if let file = config.renderFile {
    renderToStdout(file, env: env)
}

Terminal.installCleanup()

// MARK: - Resolve the directory to scan

let rootPath = config.directory ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL

var isDir: ObjCBool = false
guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDir) else {
    FileHandle.standardError.write(Data("termdown: '\(rootURL.path)': no such file or directory\n".utf8))
    exit(1)
}
guard isDir.boolValue else {
    // Reachable only with `bare-render` off — with it on, an existing file was
    // already promoted to `renderFile` above.
    FileHandle.standardError.write(Data("""
    termdown: '\(rootURL.path)' is not a directory
    Use `termdown render \(rootPath)` to render a single file, or set \
    `bare-render: true` in your config to allow this form.

    """.utf8))
    exit(1)
}

// MARK: - Browse the folder

let session = FolderSession(root: rootURL, env: env)
guard !session.isEmpty else {
    // Checked before the alternate screen, so the message survives on the
    // normal one.
    print("No markdown files found under \(rootURL.path)")
    exit(0)
}

withTerminalUI { session.runPicker() }
