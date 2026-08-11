import Foundation

/// One config key as the settings view (`,`) presents it: what it is called, what
/// values it takes, how to move between them, and whether changing it does
/// anything before the next launch.
///
/// The list below is the single place that knowledge lives. The view draws from it,
/// the writer takes the spellings from it, and the tests walk it — so a key added
/// to `AppConfig` without a row here is missing from the view, rather than present
/// and subtly wrong.
public struct ConfigSetting {

    /// How a value is edited.
    public enum Kind: Equatable {
        /// `true`/`false`.
        case toggle
        /// One of a fixed list, in the order the view cycles them.
        case choice([String])
        /// A number, typed. `zero` is the word shown when it is 0 ("auto").
        case number(zero: String)
    }

    /// The key as written in the file, e.g. `mouse-select`.
    public let key: String

    /// Other spellings `parseYAML` accepts. The writer needs them, or it appends a
    /// second line for a key the file already sets — and since parsing is
    /// last-line-wins, the appended one would silently override the user's.
    public let aliases: [String]

    public let kind: Kind

    /// Row label, e.g. "Mouse select".
    public let label: String

    /// One line saying what the key does, shown under the cursor.
    public let blurb: String

    /// Whether changing it takes effect in this session. The rest are read once at
    /// startup — the view says so rather than letting a change look ignored.
    public let appliesLive: Bool

    /// The built-in default, shown when the file does not set the key.
    public let fallback: String

    /// The value after Space / `→` on this row.
    public func next(after value: String) -> String {
        switch kind {
        case .toggle:
            return value == "true" ? "false" : "true"
        case .choice(let options):
            guard let at = options.firstIndex(of: value) else { return options.first ?? value }
            return options[(at + 1) % options.count]
        case .number:
            return value
        }
    }

    /// The value after `←` on this row — cycling backwards, so a list you overshot
    /// does not have to be walked all the way round again.
    public func previous(before value: String) -> String {
        switch kind {
        case .toggle:
            return next(after: value)
        case .choice(let options):
            guard let at = options.firstIndex(of: value) else { return options.last ?? value }
            return options[(at - 1 + options.count) % options.count]
        case .number:
            return value
        }
    }

    /// How the value reads in the row: a number of 0 shows as its `zero` word.
    public func display(_ value: String) -> String {
        if case .number(let zero) = kind, value == "0" || value.isEmpty { return zero }
        return value
    }
}

// MARK: - The editable keys

public enum ConfigSettings {

    /// Every scalar key of the config file, in the order the view lists them:
    /// appearance first, then input, then rendering, then startup.
    ///
    /// `ignore-patterns` (a list) and `key-<action>` (open-ended) are deliberately
    /// absent — they are not one-of-a-few values and would need an editor of their
    /// own rather than a row.
    public static let editable: [ConfigSetting] = [
        ConfigSetting(key: "theme", aliases: [], kind: .choice(Theme.all.map(\.name)),
                      label: "Theme", blurb: "Content color palette",
                      appliesLive: true, fallback: "dark"),
        ConfigSetting(key: "no-color", aliases: ["nocolor", "no_color"], kind: .toggle,
                      label: "No color", blurb: "Disable every ANSI color",
                      appliesLive: true, fallback: "false"),
        ConfigSetting(key: "width", aliases: [], kind: .number(zero: "auto"),
                      label: "Width", blurb: "Text column width; auto follows the terminal",
                      appliesLive: false, fallback: "0"),
        ConfigSetting(key: "mouse", aliases: [], kind: .toggle,
                      label: "Mouse", blurb: "Scroll and click in the finder and viewer",
                      appliesLive: false, fallback: "true"),
        ConfigSetting(key: "mouse-select", aliases: ["mouseselect", "mouse_select"], kind: .toggle,
                      label: "Mouse select", blurb: "Drag to select text, copied on release",
                      appliesLive: false, fallback: "true"),
        ConfigSetting(key: "mermaid", aliases: [], kind: .toggle,
                      label: "Mermaid", blurb: "Render ```mermaid blocks as diagrams",
                      appliesLive: true, fallback: "true"),
        ConfigSetting(key: "mermaid-charset", aliases: ["mermaidcharset", "mermaid_charset"],
                      kind: .choice(["unicode", "ascii"]),
                      label: "Mermaid charset", blurb: "Box-drawing characters for diagrams",
                      appliesLive: true, fallback: "unicode"),
        ConfigSetting(key: "wide-emoji", aliases: ["wideemoji", "wide_emoji"],
                      kind: .choice(["cluster", "scalar"]),
                      label: "Wide emoji", blurb: "How emoji are measured; scalar is the legacy rule",
                      appliesLive: true, fallback: "cluster"),
        ConfigSetting(key: "file-list-view", aliases: ["filelistview", "file_list_view"],
                      kind: .choice(["files", "folders"]),
                      label: "File list view", blurb: "Which list the picker opens on",
                      appliesLive: false, fallback: "files"),
        ConfigSetting(key: "bare-render", aliases: ["barerender", "bare_render"], kind: .toggle,
                      label: "Bare render", blurb: "A bare file path renders to stdout instead of opening",
                      appliesLive: false, fallback: "false"),
    ]

    /// The setting for a key (any spelling), or nil if it is not editable here.
    public static func named(_ key: String) -> ConfigSetting? {
        let needle = key.lowercased()
        return editable.first { $0.key == needle || $0.aliases.contains(needle) }
    }
}

// MARK: - Reading a value back out of a loaded config

extension AppConfig {

    /// What this config sets for `setting`, or nil if it does not set it. Reading
    /// goes through the same table the view and the writer use, so a row can never
    /// display one key and write another.
    public func value(for setting: ConfigSetting) -> String? {
        switch setting.key {
        case "theme": return theme
        case "no-color": return noColor.map(String.init)
        case "width": return width.map(String.init)
        case "mouse": return mouse.map(String.init)
        case "mouse-select": return mouseSelect.map(String.init)
        case "mermaid": return mermaid.map(String.init)
        case "mermaid-charset": return mermaidCharset
        case "wide-emoji": return wideEmoji
        case "file-list-view": return fileListView
        case "bare-render": return bareRender.map(String.init)
        default: return nil
        }
    }

    /// The value the view shows: what the file sets, or the built-in default.
    public func effectiveValue(for setting: ConfigSetting) -> String {
        value(for: setting) ?? setting.fallback
    }
}
