import Foundation

/// Configuration loaded from ~/.config/termdown/config.yaml (global) merged with
/// an optional project-local .termdown.yaml (which takes priority key-by-key).
public struct AppConfig: Codable {
    /// Which generation of shipped defaults this file has already been through.
    /// Absent (or lower than `currentConfigVersion`) means `migrate` still has
    /// work to do. Never read for behavior — only for migration.
    public var configVersion: Int?
    public var theme: String?
    public var width: Int?
    public var noColor: Bool?
    public var mouse: Bool?
    /// Drag-to-select text with the mouse (default false). Independent of
    /// `mouse`: it needs motion reporting, which costs the terminal's own
    /// click-drag selection, so it stays a separate opt-in.
    public var mouseSelect: Bool?
    /// Emoji width mode: "cluster" (default, one glyph per grapheme cluster) or
    /// "scalar" (legacy per-scalar summing) for terminals that draw the
    /// components of a ZWJ sequence separately.
    public var wideEmoji: String?
    public var ignorePatterns: [String]?
    /// Render ```mermaid fenced blocks as diagrams (default true).
    public var mermaid: Bool?
    /// Mermaid box-drawing character set: "unicode" (default) or "ascii".
    public var mermaidCharset: String?
    /// Treat a bare file path as `render <file>` (default false), so
    /// `termdown notes.md` works without the subcommand. Opt-in because it
    /// changes what an existing invocation means.
    public var bareRender: Bool?
    /// Which list the file picker opens on: "files" (default, every markdown file
    /// in the project) or "folders" (the folder browser, one level at a time).
    /// `d` switches at any time either way; this only picks the starting point.
    public var fileListView: String?
    /// Viewer key overrides: action name → key (from `key-<action>: <char>`).
    public var keyBindings: [String: String]?

    public init() {}

    // MARK: - Default config file content

    /// The global config file every write lands in — and the path the settings view
    /// shows, so the user can see which file they are editing.
    public static let globalConfigPath: URL = configPath(
        env: ProcessInfo.processInfo.environment,
        home: FileManager.default.homeDirectoryForCurrentUser)

    /// `$XDG_CONFIG_HOME/termdown/config.yaml` when that variable is set, else
    /// `~/.config/termdown/config.yaml`. The default *is* the XDG default, so
    /// honouring the variable only surprises someone who set it on purpose.
    ///
    /// Pure and injectable because the alternative is untestable: `HOME` is ignored
    /// by `homeDirectoryForCurrentUser` on Darwin, so without this there is no way to
    /// exercise the config on a machine without editing the config of that machine —
    /// which is exactly what the integration script must not do.
    static func configPath(env: [String: String], home: URL) -> URL {
        if let xdg = env["XDG_CONFIG_HOME"], !xdg.trimmingCharacters(in: .whitespaces).isEmpty {
            return URL(fileURLWithPath: xdg).appendingPathComponent("termdown/config.yaml")
        }
        return home.appendingPathComponent(".config/termdown/config.yaml")
    }

    /// Bumped whenever a shipped default changes in a way existing configs should
    /// pick up. `migrate` compares it against the `config-version:` line in the
    /// user's file and upgrades once; see `migrate(_:)`.
    static let currentConfigVersion = 4

    static let defaultConfigContent = """
    # termdown configuration
    # ---------------------
    # config-version: written by termdown so it knows which shipped defaults this
    # file has already seen. Leave it alone.
    config-version: 4

    # theme: Color theme to use.
    #   base:    dark, light, mono
    #   ports:   catppuccin, rose-pine, nord, tokyo-night, gruvbox, dracula,
    #            solarized-dark, solarized-light, everforest, kanagawa, one-dark,
    #            monokai, ayu-mirage, night-owl
    #   pastels: matte-rose, matte-slate, matte-moss, frost, mint, dusk, glacier,
    #            blossom, sand, coral, ember, terracotta
    # Press `p` in the viewer to preview and switch live.
    theme: dark

    # width: Text column width. 0 = auto-detect from terminal size.
    # width: 80

    # no-color: Disable all ANSI colors (true/false).
    no-color: false

    # mouse: Mouse scroll in the viewer and file list (true/false, default true).
    # Set false to hand the mouse back to the terminal entirely.
    mouse: true

    # mouse-select: Drag with the mouse to select text, copied on release
    # (true/false, default true). This reports pointer motion, which replaces the
    # terminal's own click-drag selection — hold Shift (or Option on macOS) to
    # fall back to it, or set this to false.
    mouse-select: true

    # wide-emoji: How emoji are measured — "cluster" (default) treats a ZWJ
    # sequence, skin-tone or variation-selector emoji as one two-column glyph.
    # Use "scalar" only if your terminal draws the components separately and
    # rows look misaligned.
    wide-emoji: cluster

    # ignore-patterns: Extra path patterns to skip during file discovery, in
    # addition to the built-in skips (.git, node_modules, .build, ...).
    # Inline list only — the config reader is flat (no "- item" blocks):
    # ignore-patterns: [vendor, "*.snap", archive]

    # mermaid: Render ```mermaid fenced blocks as ASCII/Unicode diagrams
    # (true/false). Falls back to a highlighted code block on parse failure.
    mermaid: true

    # mermaid-charset: Box-drawing characters for diagrams: unicode or ascii.
    mermaid-charset: unicode

    # file-list-view: Which list the file picker opens on — files (the default,
    # every markdown file in the project) or folders (the folder browser, one
    # level at a time). `d` switches between them while running either way.
    file-list-view: files

    # bare-render: What a bare file path does. false (the default) opens
    # `termdown notes.md` in the viewer; true renders it to stdout and exits.
    # `-o`/`--open` and `-r`/`--render` override this either way. A bare
    # *directory* opens the file picker regardless.
    bare-render: false

    # Custom viewer keys: key-<action>: <char> binds a key to a viewer action
    # (the default key keeps working too). Actions: scroll-down, scroll-up,
    # page-down, page-up, half-down, half-up, top, bottom, search, next-match,
    # prev-match, project-search, open-link, new-tab, theme, sidebar, wrap,
    # follow, banner, fold, fold-all, next-heading, prev-heading, edit, cursor,
    # toggle-task, contents, help, quit.
    # key-scroll-down: e

    # Precedence (highest wins, merged per key):
    #   1. CLI flags (--theme, --width, --mouse, --no-color, ...)
    #   2. project-local ./.termdown.yaml
    #   3. this global config
    #   4. built-in defaults
    """

    // MARK: - Load

    /// Load configuration. On first run, creates ~/.config/termdown/config.yaml
    /// with commented defaults. Always loads the global config first, then merges
    /// any project-local .termdown.yaml on top (project keys win).
    public static func load() -> AppConfig {
        let fm = FileManager.default

        // Create global config on first run; otherwise bring an older one up to
        // the current generation of shipped defaults.
        if !fm.fileExists(atPath: globalConfigPath.path) {
            createDefaultConfig()
        } else {
            migrate(globalConfigPath)
        }

        // 1. Load global config as the base.
        var base = loadFile(globalConfigPath) ?? AppConfig()

        // Also check legacy JSON global config and merge if present.
        let legacyJSON = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/termdown/config.json")
        if let legacy = loadLegacyJSON(legacyJSON) {
            base.merge(legacy)
        }

        // 2. Look for a project-local override, merge on top.
        if let local = projectLocal() {
            base.merge(local)
        }

        return base
    }

    // MARK: - Merge (project-local wins over global for any key it sets)

    /// Overwrite only the fields that `other` explicitly sets (non-nil).
    mutating func merge(_ other: AppConfig) {
        if let v = other.configVersion  { configVersion = v }
        if let v = other.theme          { theme = v }
        if let v = other.width          { width = v }
        if let v = other.noColor        { noColor = v }
        if let v = other.mouse          { mouse = v }
        if let v = other.mouseSelect    { mouseSelect = v }
        if let v = other.wideEmoji      { wideEmoji = v }
        if let v = other.ignorePatterns { ignorePatterns = v }
        if let v = other.mermaid        { mermaid = v }
        if let v = other.mermaidCharset { mermaidCharset = v }
        if let v = other.bareRender     { bareRender = v }
        if let v = other.fileListView   { fileListView = v }
        if let v = other.keyBindings {
            if keyBindings == nil { keyBindings = v }
            else { v.forEach { keyBindings?[$0.key] = $0.value } }   // merge per binding
        }
    }

    /// Parse one config file, or nil if it is missing or unreadable.
    public static func loadFile(_ url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parseYAML(data)
    }

    /// The project-local `./.termdown.yaml`, if this folder has one. Its keys win
    /// over the global file, which is why the settings view marks them: writing the
    /// global file for a key set here would look like it did nothing.
    public static func projectLocal() -> AppConfig? {
        loadFile(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".termdown.yaml"))
    }

    private static func loadLegacyJSON(_ url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    // MARK: - Minimal YAML parser
    //
    // Supports flat key: value mappings only — no nested objects or lists.
    // Handles: string values, quoted strings, integers, booleans (true/false/yes/no).
    // Lines starting with '#' or blank lines are ignored.

    static func parseYAML(_ data: Data) -> AppConfig? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var cfg = AppConfig()
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            var value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            // Strip inline comment (bare # not inside quotes).
            if let hashIdx = value.firstIndex(of: "#") {
                value = value[value.startIndex..<hashIdx]
                    .trimmingCharacters(in: .whitespaces)
            }
            // Strip surrounding quotes.
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'")  && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            guard !value.isEmpty else { continue }
            switch key {
            case "config-version", "configversion", "config_version":
                cfg.configVersion = Int(value)
            case "theme":
                cfg.theme = value
            case "width":
                cfg.width = Int(value)
            case "no-color", "nocolor", "no_color":
                cfg.noColor = parseBool(value)
            case "mouse":
                cfg.mouse = parseBool(value)
            case "mouse-select", "mouseselect", "mouse_select":
                cfg.mouseSelect = parseBool(value)
            case "wide-emoji", "wideemoji", "wide_emoji":
                cfg.wideEmoji = value
            case "mermaid":
                cfg.mermaid = parseBool(value)
            case "mermaid-charset", "mermaidcharset", "mermaid_charset":
                cfg.mermaidCharset = value.lowercased()
            case "bare-render", "barerender", "bare_render":
                cfg.bareRender = parseBool(value)
            case "file-list-view", "filelistview", "file_list_view":
                cfg.fileListView = value.lowercased()
            case "ignore-patterns", "ignorepatterns", "ignore_patterns":
                // Inline sequence: [a, b, c] or bare comma-separated list
                let inner = value.hasPrefix("[") ? String(value.dropFirst().dropLast()) : value
                let parts = inner.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces)
                              .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
                    .filter { !$0.isEmpty }
                cfg.ignorePatterns = parts.isEmpty ? nil : parts
            default:
                // Viewer key override: `key-<action>: <char>`.
                if key.hasPrefix("key-") {
                    let action = String(key.dropFirst(4))
                    if !action.isEmpty {
                        if cfg.keyBindings == nil { cfg.keyBindings = [:] }
                        cfg.keyBindings?[action] = value
                    }
                }
            }
        }
        return cfg
    }

    private static func parseBool(_ s: String) -> Bool {
        switch s.lowercased() {
        case "true", "yes", "on", "1": return true
        default: return false
        }
    }
}
