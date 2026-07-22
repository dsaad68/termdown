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
    var action: RequestedAction = .bare(nil)
    var showHelp: Bool = false
    var showVersion: Bool = false
}

/// What the command line alone asks for.
///
/// `-o`, `-r`, `render` and `-` name an action outright. A bare path does not:
/// whether `termdown notes.md` opens the viewer or prints to stdout depends on
/// `bare-render`, which is not loaded at parse time. `ActionResolver` finishes
/// the job once it is.
enum RequestedAction: Equatable {
    /// A positional path, or nil if none was given.
    case bare(String?)
    /// `-o` / `--open`
    case open(String)
    /// `-r` / `--render`, and the older `render` spelling
    case render(String)
    case stdin
}

extension RequestedAction {
    /// Apply `transform` to whatever path this action carries. `main.swift` uses
    /// it to standardize the path once, up front, so the decision and every
    /// message it produces speak in the same terms.
    func mappingPath(_ transform: (String) -> String) -> RequestedAction {
        switch self {
        case .bare(let path):   return .bare(path.map(transform))
        case .open(let path):   return .open(transform(path))
        case .render(let path): return .render(transform(path))
        case .stdin:            return .stdin
        }
    }
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
        // Tracked separately so a positional cannot silently overwrite an action
        // named outright, and vice versa.
        var positional: String?
        var named: RequestedAction?
        // The token that named the action, so a second one can name both.
        var namedBy: String?

        /// Two actions on one command line is a mistake, not a preference —
        /// say so rather than silently picking one.
        func claim(_ token: String) -> String? {
            guard let previous = namedBy else { return nil }
            return previous == token
                ? "termdown: \(token) may only be given once"
                : "termdown: \(token) cannot be combined with \(previous)"
        }

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
            case "-r", "--render", "render":
                if let conflict = claim(arg) { return .failure(message: conflict, code: 1) }
                // Rejecting a flag as the path fixes a long-standing sharp edge:
                // `render` used to take the next token unconditionally, so
                // `termdown render --theme nord` tried to read a file called
                // `--theme`.
                guard let file = args.first, !file.hasPrefix("-") else {
                    return .failure(message: "termdown: \(arg) requires a file path", code: 1)
                }
                named = .render(file)
                namedBy = arg
                args = args.dropFirst()
            case "-o", "--open":
                if let conflict = claim(arg) { return .failure(message: conflict, code: 1) }
                guard let path = args.first, !path.hasPrefix("-") else {
                    return .failure(message: "termdown: \(arg) requires a file or directory path", code: 1)
                }
                named = .open(path)
                namedBy = arg
                args = args.dropFirst()
            case "-":
                if let conflict = claim(arg) { return .failure(message: conflict, code: 1) }
                named = .stdin
                namedBy = arg
            default:
                if !arg.hasPrefix("--") && !arg.hasPrefix("-") {
                    positional = arg
                } else {
                    return .failure(message: "termdown: unknown option \(arg)", code: 1)
                }
            }
        }

        if let positional {
            // `termdown render a.md b.md` used to drop `b.md` without a word.
            guard let namedBy else {
                config.action = .bare(positional)
                return .success(config)
            }
            return .failure(message: "termdown: unexpected argument '\(positional)' after \(namedBy)",
                            code: 1)
        }
        config.action = named ?? .bare(nil)
        return .success(config)
    }

    /// `--help` output. Kept next to the parser so a new flag and its
    /// documentation are edited together.
    static let usage = """
    termdown — browse & render markdown in your terminal
    USAGE: termdown [options] [path]
           termdown                      file picker over the current directory
           termdown DIR                  file picker over DIR
           termdown FILE.md              open FILE.md in the viewer
                                         (renders to stdout with `bare-render: true`)
           termdown -o FILE.md           always open in the viewer
           termdown -r FILE.md           always render to stdout
           termdown render FILE.md       older spelling of -r
           termdown -                    read from stdin
    OPTIONS:
      -o, --open PATH   Open PATH in the viewer whatever `bare-render` says
                        (a directory opens the file picker)
      -r, --render PATH Render PATH to stdout and exit, whatever `bare-render`
                        says
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
