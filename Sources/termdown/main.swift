import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import termdownCore
import MermaidRenderer

let arguments = CommandLine.arguments

// MARK: - Argument parsing

struct Config {
    var width: Int?
    var themeName: String?
    var noColor: Bool = false
    var mouse: Bool?  // nil = use yaml/default
    var mouseSelect: Bool?  // nil = use yaml/default
    var directory: String?
    var renderFile: String?
    var showHelp: Bool = false
    var showVersion: Bool = false
    var useStdin: Bool = false
}

var config = Config()
var args = arguments.dropFirst()

while let arg = args.first {
    args = args.dropFirst()
    switch arg {
    case "--help", "-h":
        config.showHelp = true
    case "--version", "-V":
        config.showVersion = true
    case "--width":
        guard let w = args.first, let width = Int(w) else {
            FileHandle.standardError.write(Data("termdown: --width requires a number\n".utf8))
            exit(1)
        }
        config.width = width
        args = args.dropFirst()
    case "--theme":
        guard let theme = args.first else {
            FileHandle.standardError.write(Data("termdown: --theme requires a name\n".utf8))
            exit(1)
        }
        config.themeName = theme
        args = args.dropFirst()
    case "--no-color":
        config.noColor = true
    case "--mouse":
        config.mouse = true
    case "--no-mouse":
        config.mouse = false
    case "--mouse-select":
        config.mouseSelect = true
    case "--no-mouse-select":
        config.mouseSelect = false
    case "render":
        guard let file = args.first else {
            FileHandle.standardError.write(Data("termdown: render requires a file path\n".utf8))
            exit(1)
        }
        config.renderFile = file
        args = args.dropFirst()
    case "-":
        config.useStdin = true
    default:
        if !arg.hasPrefix("--") && !arg.hasPrefix("-") {
            config.directory = arg
        } else {
            FileHandle.standardError.write(Data("termdown: unknown option \(arg)\n".utf8))
            exit(1)
        }
    }
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

// MARK: - Resolve theme

func resolveTheme(_ name: String?) -> Theme {
    guard let name = name else { return .dark }
    return Theme.named(name) ?? .dark
}

// Mutable so the in-app theme selector can swap it at runtime; the render
// closures below capture it and read the current value on each call.
var activeTheme = resolveTheme(config.themeName)
var activeThemeName = config.themeName.flatMap { Theme.named($0) != nil ? $0.lowercased() : nil } ?? "dark"

// Heading-banner mode (toggle `B` in the viewer): render closures read it live.
var headingBanners = false

// Mermaid diagram rendering (config-driven; defaults to on + Unicode).
let mermaidEnabled = appConfig.mermaid ?? true
let mermaidCharset: MermaidCharset = (appConfig.mermaidCharset == "ascii") ? .ascii : .unicode

// MARK: - Help and version

if config.showHelp {
    print("""
    termdown — browse & render markdown in your terminal
    USAGE: termdown [options] [directory]
           termdown render <file.md>
           termdown -                    (read from stdin)
    OPTIONS:
      --width N         Set terminal width (default: auto-detect)
      --theme NAME      Set color theme. Base: dark, light, mono. Ports:
                        catppuccin, rose-pine, nord, tokyo-night, gruvbox,
                        dracula, solarized-dark, solarized-light, everforest,
                        kanagawa, one-dark, monokai, ayu-mirage, night-owl.
                        Pastels: matte-rose, matte-slate, matte-moss, frost,
                        mint, dusk, glacier, blossom, sand, coral, ember,
                        terracotta
      --no-color        Disable ANSI colors
      --mouse           Enable mouse scroll (on by default)
      --no-mouse        Disable mouse scroll (overrides config)
      --mouse-select    Enable drag-to-select text, copied on release (on by
                        default). Replaces the terminal's own click-drag
                        selection while active — hold Shift (Option on macOS)
                        to fall back to it
      --no-mouse-select Disable drag-to-select (overrides config)
      --version, -V     Show version information
      --help, -h        Show this help message
    """)
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

// MARK: - Stdin handling

if config.useStdin {
    let source = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""

    // If stdout is a TTY, use interactive pager; otherwise just print
    if isatty(STDOUT_FILENO) != 0 {
        Terminal.installCleanup()
        Terminal.enableRawMode()
        Terminal.enterAltScreen()
        var pager = Pager(title: "stdin", lines: [])
        pager.fixedWidth = config.width
        pager.mouseEnabled = mouseEnabled
        pager.mouseSelectEnabled = mouseSelectEnabled
        pager.renderSource = { w in
            AnsiRenderer(width: w, theme: activeTheme, headingBanners: headingBanners,
                         mermaidEnabled: mermaidEnabled, mermaidCharset: mermaidCharset).render(source)
        }
        pager.keyTranslation = keyTranslation
        pager.onToggleHeadingBanners = { headingBanners = $0 }
        pager.run()
        Terminal.exitAltScreen()
        Terminal.disableRawMode()
        Terminal.showCursor()
    } else {
        let cols = config.width ?? Terminal.size().cols
        let doc = AnsiRenderer(width: cols, theme: activeTheme,
                               mermaidEnabled: mermaidEnabled, mermaidCharset: mermaidCharset).render(source)
        print(doc.lines.joined(separator: "\n"))
    }
    exit(0)
}

// MARK: - `render` subcommand: render a single file to stdout and exit.
// Usage: termdown render <file.md>   (handy for piping / scripting)
if let file = config.renderFile {
    let fileURL = URL(fileURLWithPath: file).standardizedFileURL
    guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
        FileHandle.standardError.write(Data("termdown: cannot read \(fileURL.path)\n".utf8))
        exit(1)
    }
    let cols = config.width ?? Terminal.size().cols
    let doc = AnsiRenderer(width: cols, theme: activeTheme,
                           mermaidEnabled: mermaidEnabled, mermaidCharset: mermaidCharset).render(source)
    print(doc.lines.joined(separator: "\n"))
    exit(0)
}

Terminal.installCleanup()

// MARK: - Resolve the directory to scan

let rootPath = config.directory ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL

var isDir: ObjCBool = false
guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else {
    FileHandle.standardError.write(Data("termdown: '\(rootURL.path)' is not a directory\n".utf8))
    exit(1)
}

// MARK: - Discover markdown files

var entries = FileScanner.scan(root: rootURL, ignorePatterns: appConfig.ignorePatterns ?? [])
guard !entries.isEmpty else {
    print("No markdown files found under \(rootURL.path)")
    exit(0)
}

// Watch the folder so newly added/removed files show up in the picker
// without restarting termdown.
FolderWatcher.start(root: rootURL)

// MARK: - Main loop: pick a file -> view it -> repeat

var details = fileDetails(entries)

let homePath = FileManager.default.homeDirectoryForCurrentUser.path
let displayPath = rootURL.path.hasPrefix(homePath)
    ? "~" + String(rootURL.path.dropFirst(homePath.count))
    : rootURL.path

var menu = TerminalMenu(
    title: "termdown",
    items: entries.map { $0.relativePath },
    details: details
)
menu.path = displayPath
menu.mouseEnabled = mouseEnabled

// Project-wide search across all discovered files (reused from list + pager).
var liveGrep = LiveGrep(entries: entries.map { ($0.url, $0.relativePath) })
liveGrep.mouseEnabled = mouseEnabled

// Re-scan the directory after `FolderWatcher` reports a change, syncing
// `entries`/`details`/`liveGrep` if the file list actually differs (an
// FSEvents firing can also be a same-file mtime touch with no list change).
@discardableResult
func refreshEntries() -> Bool {
    let rescanned = FileScanner.scan(root: rootURL, ignorePatterns: appConfig.ignorePatterns ?? [])
    guard rescanned.map(\.relativePath) != entries.map(\.relativePath) else { return false }
    entries = rescanned
    details = fileDetails(entries)
    liveGrep.updateEntries(entries.map { ($0.url, $0.relativePath) })
    return true
}

menu.onFolderChanged = {
    refreshEntries() ? (items: entries.map { $0.relativePath }, details: details) : nil
}

// Render any markdown file at a given width (current doc, reload, link nav).
let renderFile: (URL, Int) -> RenderedDocument? = { url, w in
    guard let src = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    return AnsiRenderer(width: w, theme: activeTheme, headingBanners: headingBanners,
                        mermaidEnabled: mermaidEnabled, mermaidCharset: mermaidCharset).render(src)
}

// Render arbitrary markdown text (used to re-render unsaved in-memory edits).
let renderText: (String, Int) -> RenderedDocument = { src, w in
    AnsiRenderer(width: w, theme: activeTheme, headingBanners: headingBanners).render(src)
}

// Resolve a [[wikilink]] page name to one of the discovered files — matching by
// filename (with or without extension) or relative path, case-insensitively.
let resolveWikilink: (String) -> URL? = { name in
    let needle = name.lowercased()
    let needleStem = (needle as NSString).deletingPathExtension
    return entries.first { entry in
        let file = entry.url.lastPathComponent.lowercased()
        let stem = (file as NSString).deletingPathExtension
        let rel = entry.relativePath.lowercased()
        let relStem = (rel as NSString).deletingPathExtension
        return file == needle || stem == needleStem || rel == needle || relStem == needleStem
    }?.url
}

/// Open a file in the pager (which then handles in-app link/grep navigation).
func viewFile(_ url: URL, query: String?) {
    var pager = Pager(title: url.lastPathComponent, lines: [])
    pager.fileURL = url
    pager.fixedWidth = config.width
    pager.mouseEnabled = mouseEnabled
    pager.mouseSelectEnabled = mouseSelectEnabled
    pager.initialQuery = query
    pager.renderFile = renderFile
    pager.renderText = renderText
    pager.resolveWikilink = resolveWikilink
    pager.keyTranslation = keyTranslation
    pager.onProjectSearch = { liveGrep.run() }
    // Theme selector (`p`): preview swaps the active theme live; save persists it.
    pager.currentThemeName = activeThemeName
    pager.onPreviewTheme = { name in activeTheme = resolveTheme(name) }
    pager.onSaveTheme = { name in
        activeTheme = resolveTheme(name)
        activeThemeName = name
        AppConfig.setTheme(name)
    }
    pager.bannerOn = headingBanners
    pager.onToggleHeadingBanners = { headingBanners = $0 }
    pager.onNewTab = {
        // Reuse the file finder (and grep) to choose a document for a new tab;
        // `.quit` here means the user cancelled, so no tab is opened. The "New tab"
        // context swaps the launch wordmark for a slim header so it's clearly a
        // picker, not the app relaunching.
        switch menu.run(initialSelection: lastSelection, context: "New tab") {
        case .open(let index):
            lastSelection = index
            return entries[index].url
        case .grep:
            return liveGrep.run()?.url
        case .quit:
            return nil
        }
    }
    pager.run()
}

Terminal.enableRawMode()
Terminal.enterAltScreen()

var lastSelection = 0
menuLoop: while true {
    switch menu.run(initialSelection: lastSelection) {
    case .quit:
        break menuLoop
    case .open(let index):
        lastSelection = index
        viewFile(entries[index].url, query: nil)
    case .grep:
        if let result = liveGrep.run() {
            viewFile(result.url, query: result.query)
        }
    }
}

Terminal.exitAltScreen()
Terminal.disableRawMode()
Terminal.showCursor()
