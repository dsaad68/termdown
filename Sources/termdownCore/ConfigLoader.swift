import Foundation

/// Configuration loaded from ~/.config/termdown/config.yaml (global) merged with
/// an optional project-local .termdown.yaml (which takes priority key-by-key).
public struct AppConfig: Codable {
    public var theme: String?
    public var width: Int?
    public var noColor: Bool?
    public var mouse: Bool?
    public var ignorePatterns: [String]?
    /// Viewer key overrides: action name → key (from `key-<action>: <char>`).
    public var keyBindings: [String: String]?

    public init() {}

    // MARK: - Default config file content

    static let globalConfigPath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/termdown/config.yaml")
    }()

    private static let defaultConfigContent = """
    # termdown configuration
    # ---------------------
    # theme: Color theme to use. Options: dark, light, mono, catppuccin, rose-pine,
    #        nord, tokyo-night, gruvbox, dracula, matte-rose, matte-slate, frost,
    #        mint, dusk, blossom, sand, coral
    theme: dark

    # width: Text column width. 0 = auto-detect from terminal size.
    # width: 80

    # no-color: Disable all ANSI colors (true/false).
    no-color: false

    # mouse: Enable mouse scroll in the viewer and file list (true/false).
    # Note: enabling mouse scroll prevents native text selection in the terminal.
    # In tmux, hold Option (macOS) or Shift to select text while mouse is on.
    mouse: false

    # ignore-patterns: Extra path patterns to skip during file discovery, in
    # addition to the built-in skips (.git, node_modules, .build, ...).
    # Inline list only — the config reader is flat (no "- item" blocks):
    # ignore-patterns: [vendor, "*.snap", archive]

    # Custom viewer keys: key-<action>: <char> binds a key to a viewer action
    # (the default key keeps working too). Actions: scroll-down/up, page-down/up,
    # half-down/up, top, bottom, search, next-match, prev-match, project-search,
    # open-link, new-tab, theme, sidebar, wrap, follow, banner, fold, fold-all,
    # next-heading, prev-heading, contents, help, quit.
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

        // Create global config on first run.
        if !fm.fileExists(atPath: globalConfigPath.path) {
            createDefaultConfig()
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
        let projectLocal = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent(".termdown.yaml")
        if let local = loadFile(projectLocal) {
            base.merge(local)
        }

        return base
    }

    // MARK: - Merge (project-local wins over global for any key it sets)

    /// Overwrite only the fields that `other` explicitly sets (non-nil).
    mutating func merge(_ other: AppConfig) {
        if let v = other.theme          { theme = v }
        if let v = other.width          { width = v }
        if let v = other.noColor        { noColor = v }
        if let v = other.mouse          { mouse = v }
        if let v = other.ignorePatterns { ignorePatterns = v }
        if let v = other.keyBindings {
            if keyBindings == nil { keyBindings = v }
            else { v.forEach { keyBindings?[$0.key] = $0.value } }   // merge per binding
        }
    }

    // MARK: - Helpers

    /// Persist the chosen `theme` to the global config, replacing the active
    /// `theme:` line in place (comments and other keys are preserved) or
    /// appending one if absent. Used by the in-app theme selector.
    public static func setTheme(_ name: String) {
        writeTheme(name, to: globalConfigPath)
    }

    /// Path-injectable core of `setTheme` so it can be tested without touching the
    /// user's real config.
    static func writeTheme(_ name: String, to url: URL) {
        let fm = FileManager.default
        var lines = (try? String(contentsOf: url, encoding: .utf8))
            .map { $0.components(separatedBy: "\n") } ?? []
        if let i = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("theme:") }) {
            lines[i] = "theme: \(name)"
        } else {
            lines.append("theme: \(name)")
        }
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func createDefaultConfig() {
        let fm = FileManager.default
        let dir = globalConfigPath.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? defaultConfigContent.write(to: globalConfigPath, atomically: true, encoding: .utf8)
    }

    private static func loadFile(_ url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parseYAML(data)
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
            case "theme":
                cfg.theme = value
            case "width":
                cfg.width = Int(value)
            case "no-color", "nocolor", "no_color":
                cfg.noColor = parseBool(value)
            case "mouse":
                cfg.mouse = parseBool(value)
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
