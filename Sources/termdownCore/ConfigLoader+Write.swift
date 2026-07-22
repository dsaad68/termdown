import Foundation

// Everything that *writes* the config file: the theme the picker persists, and
// the one-time migration that brings an older file up to the current generation
// of shipped keys.
//
// Split out of `ConfigLoader.swift`, which sits on the 400-line lint ceiling —
// the same reason `Ansi+Palette.swift` exists.

extension AppConfig {

    /// Persist the chosen `theme` to the global config, replacing the active
    /// `theme:` line in place (comments and other keys are preserved) or
    /// appending one if absent. Used by the in-app theme selector.
    public static func setTheme(_ name: String) {
        writeTheme(name, to: globalConfigPath)
    }

    /// Path-injectable core of `setTheme` so it can be tested without touching the
    /// user's real config.
    static func writeTheme(_ name: String, to url: URL) {
        var lines = (try? String(contentsOf: url, encoding: .utf8))
            .map { $0.components(separatedBy: "\n") } ?? []
        if let i = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("theme:") }) {
            lines[i] = "theme: \(name)"
        } else {
            lines.append("theme: \(name)")
        }
        write(lines.joined(separator: "\n"), to: url)
    }

    // MARK: - Migration

    /// A key introduced after an older config file was written, with the
    /// documentation block the template ships alongside it.
    ///
    /// Migration only ever *adds* keys. It used to also rewrite any line whose
    /// value matched the superseded default, treating that as "the user never
    /// touched this" — but a config file cannot tell those apart. A deliberate
    /// `mouse: false` and an untouched one are the same five characters, so the
    /// rule silently overrode explicit choices (and dropped the comment
    /// explaining them). A changed default now reaches existing users through
    /// the template for fresh installs and the release notes, not by editing
    /// files behind their back.
    private struct AddedKey {
        let key: String
        /// Other spellings `parseYAML` accepts. Without them the lookup misses a
        /// file that uses one and appends a duplicate — and since parsing is
        /// last-line-wins, the duplicate silently overrides the user's line.
        let aliases: [String]
        let value: String
        /// A key this one is subordinate to. When that key is explicitly off,
        /// the new key is added off too, so migration never switches on part of
        /// something the user has switched off.
        let subordinateTo: String?
        let comment: [String]
    }

    /// Keys introduced in config-version 2. `mouse` predates it but a config old
    /// enough may never have had the line; `mouse-select` is new in v0.1.8.
    private static let version2Keys: [AddedKey] = [
        AddedKey(key: "mouse", aliases: [], value: "true", subordinateTo: nil, comment: [
            "# mouse: Mouse scroll in the viewer and file list (true/false, default true).",
            "# Set false to hand the mouse back to the terminal entirely.",
        ]),
        AddedKey(key: "mouse-select", aliases: ["mouseselect", "mouse_select"], value: "true",
                 subordinateTo: "mouse", comment: [
            "# mouse-select: Drag with the mouse to select text, copied on release",
            "# (true/false, default true). This reports pointer motion, which replaces the",
            "# terminal's own click-drag selection — hold Shift (or Option on macOS) to",
            "# fall back to it, or set this to false.",
        ]),
    ]

    /// Bring an existing config up to `currentConfigVersion`, once: append the
    /// keys the file has never seen, then stamp the version so it does not run
    /// again. Every value already in the file keeps its spelling, its comment,
    /// its position and — above all — its value.
    ///
    /// Path-injectable for the same reason `writeTheme` is: tests must never
    /// touch the real config.
    static func migrate(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let version = parseYAML(Data(text.utf8))?.configVersion ?? 1
        guard version < currentConfigVersion else { return }

        var lines = text.components(separatedBy: "\n")

        /// The value the file sets for `key` under any of its spellings, matching
        /// `parseYAML`'s last-line-wins precedence.
        func value(of key: String, aliases: [String] = []) -> String? {
            let names = Set([key] + aliases)
            guard let i = lines.lastIndex(where: { activeKey($0).map(names.contains) ?? false })
            else { return nil }
            return activeValue(lines[i])
        }

        func append(_ comment: [String], _ setting: String) {
            if lines.last?.isEmpty == false { lines.append("") }
            lines.append(contentsOf: comment)
            lines.append(setting)
        }

        for added in version2Keys where value(of: added.key, aliases: added.aliases) == nil {
            let parentOff = added.subordinateTo
                .flatMap { value(of: $0) }
                .map { ["false", "no"].contains($0) } ?? false
            append(added.comment, "\(added.key): \(parentOff ? "false" : added.value)")
        }

        // Stamp last, so a crash mid-migration just replays next launch. This is
        // termdown's own bookkeeping key, not a setting, so rewriting it is fair.
        if let i = lines.firstIndex(where: { activeKey($0) == "config-version" }) {
            lines[i] = "config-version: \(currentConfigVersion)"
        } else {
            append([
                "# config-version: written by termdown so it knows which shipped defaults",
                "# this file has already seen. Leave it alone.",
            ], "config-version: \(currentConfigVersion)")
        }

        write(lines.joined(separator: "\n"), to: url)
    }

    /// Write to `url`, following a symlink instead of replacing it.
    ///
    /// `write(to:atomically:true)` writes a temporary file and renames it over
    /// the destination, which turns a symlinked `~/.config/termdown/config.yaml`
    /// — the ordinary dotfiles arrangement — into a regular file and orphans the
    /// tracked original, so every later edit in the user's dotfiles repo stops
    /// having any effect.
    private static func write(_ text: String, to url: URL) {
        let target = url.resolvingSymlinksInPath()
        try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? text.write(to: target, atomically: true, encoding: .utf8)
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

    static func createDefaultConfig() {
        let fm = FileManager.default
        let dir = globalConfigPath.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? defaultConfigContent.write(to: globalConfigPath, atomically: true, encoding: .utf8)
    }

}
