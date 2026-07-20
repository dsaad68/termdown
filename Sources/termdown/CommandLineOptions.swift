import Foundation

/// Options gathered from the command line, before the config file is merged in.
///
/// Optional fields mean "not given on the CLI", which is what lets a config file
/// value show through; `main.swift` fills them in after `AppConfig.load()`.
///
/// Lives here rather than in `main.swift` so that file stays under the
/// file-length lint ceiling — parsing is self-contained and testable, while
/// `main.swift` keeps only the top-level program flow.
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

extension Config {
    /// What a parse produced: either options, or the message and exit code the
    /// caller should terminate with. Returning the failure instead of calling
    /// `exit` keeps this testable.
    enum ParseResult {
        case success(Config)
        case failure(message: String, code: Int32)
    }

    /// Parse arguments (excluding argv[0]).
    ///
    /// The only bare words with meaning are `render` and `-`; any other
    /// non-dash argument is the positional directory (or, with `bare-render`
    /// on, a file — `main.swift` decides that once the config is loaded, since
    /// it isn't known here). Last positional wins.
    static func parse(_ arguments: some Sequence<String>) -> ParseResult {
        var config = Config()
        var args = ArraySlice(Array(arguments))

        while let arg = args.first {
            args = args.dropFirst()
            switch arg {
            case "--help", "-h":
                config.showHelp = true
            case "--version", "-V":
                config.showVersion = true
            case "--width":
                guard let w = args.first, let width = Int(w) else {
                    return .failure(message: "termdown: --width requires a number", code: 1)
                }
                config.width = width
                args = args.dropFirst()
            case "--theme":
                guard let theme = args.first else {
                    return .failure(message: "termdown: --theme requires a name", code: 1)
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
                    return .failure(message: "termdown: render requires a file path", code: 1)
                }
                config.renderFile = file
                args = args.dropFirst()
            case "-":
                config.useStdin = true
            default:
                if !arg.hasPrefix("--") && !arg.hasPrefix("-") {
                    config.directory = arg
                } else {
                    return .failure(message: "termdown: unknown option \(arg)", code: 1)
                }
            }
        }
        return .success(config)
    }

    /// `--help` output. Kept next to the parser so a new flag and its
    /// documentation are edited together.
    static let usage = """
    termdown — browse & render markdown in your terminal
    USAGE: termdown [options] [directory]
           termdown render <file.md>
           termdown <file.md>            (with `bare-render: true` in config)
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
    """
}
