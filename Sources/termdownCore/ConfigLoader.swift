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
    /// Viewer key overrides: action name → key (from `key-<action>: <char>`).
    public var keyBindings: [String: String]?

    public init() {}

    // MARK: - Default config file content

    static let globalConfigPath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/termdown/config.yaml")
    }()

    /// Bumped whenever a shipped default changes in a way existing configs should
    /// pick up. `migrate` compares it against the `config-version:` line in the
    /// user's file and upgrades once; see `migrate(_:)`.
    static let currentConfigVersion = 2

    private static let defaultConfigContent = """
    # termdown configuration
    # ---------------------
    # config-version: written by termdown so it knows which shipped defaults this
    # file has already seen. Leave it alone.
    config-version: 2

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

    // MARK: - Migration

    /// A default that changed after this config file was written, and the value
    /// the old template shipped — so a line still holding the old default can be
    /// told apart from one the user actually chose.
    private struct DefaultChange {
        let key: String
        let staleValue: String
        let newValue: String
        let comment: [String]
    }

    /// Defaults introduced in config-version 2: mouse scroll and drag-to-select
    /// both ship on now. A file predating the `mouse-select` key never had the
    /// line at all; one written by v0.1.7 has it set to the old default.
    private static let version2Changes: [DefaultChange] = [
        DefaultChange(key: "mouse", staleValue: "false", newValue: "true", comment: [
            "# mouse: Mouse scroll in the viewer and file list (true/false, default true).",
            "# Set false to hand the mouse back to the terminal entirely.",
        ]),
        DefaultChange(key: "mouse-select", staleValue: "false", newValue: "true", comment: [
            "# mouse-select: Drag with the mouse to select text, copied on release",
            "# (true/false, default true). This reports pointer motion, which replaces the",
            "# terminal's own click-drag selection — hold Shift (or Option on macOS) to",
            "# fall back to it, or set this to false.",
        ]),
    ]

    /// Bring an existing config up to `currentConfigVersion`, once. Adds keys the
    /// file has never seen and upgrades any line still holding a superseded
    /// default; a value the user has actually chosen is left alone. Comments,
    /// key order and unrelated keys are all preserved.
    ///
    /// Path-injectable for the same reason `writeTheme` is — tests must never
    /// touch the real config.
    static func migrate(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let version = parseYAML(Data(text.utf8))?.configVersion ?? 1
        guard version < currentConfigVersion else { return }

        var lines = text.components(separatedBy: "\n")
        for change in version2Changes {
            if let i = lines.firstIndex(where: { activeKey($0) == change.key }) {
                // Only rewrite a line that still holds the superseded default.
                if activeValue(lines[i]) == change.staleValue {
                    lines[i] = "\(change.key): \(change.newValue)"
                }
            } else {
                if lines.last?.isEmpty == false { lines.append("") }
                lines.append(contentsOf: change.comment)
                lines.append("\(change.key): \(change.newValue)")
            }
        }

        // Stamp last, so a crash mid-migration just replays next launch.
        if let i = lines.firstIndex(where: { activeKey($0) == "config-version" }) {
            lines[i] = "config-version: \(currentConfigVersion)"
        } else {
            if lines.last?.isEmpty == false { lines.append("") }
            lines.append("# config-version: written by termdown so it knows which shipped defaults")
            lines.append("# this file has already seen. Leave it alone.")
            lines.append("config-version: \(currentConfigVersion)")
        }

        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// The key a line sets, or nil for a blank or commented line. Mirrors what
    /// `parseYAML` considers active so migration and parsing never disagree.
    private static func activeKey(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
              let colon = trimmed.firstIndex(of: ":") else { return nil }
        return String(trimmed[trimmed.startIndex..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// The value a line sets, with any inline comment and surrounding quotes
    /// stripped — the same normalization `parseYAML` applies.
    private static func activeValue(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
              let colon = trimmed.firstIndex(of: ":") else { return nil }
        var value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        if let hash = value.firstIndex(of: "#") {
            value = String(value[value.startIndex..<hash]).trimmingCharacters(in: .whitespaces)
        }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'")), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        return value.lowercased()
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
