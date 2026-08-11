import Foundation
import MermaidRenderer
import termdownCore

/// The settings view (`,`): the config file's scalar keys, edited in place.
///
/// Every change is written to `~/.config/termdown/config.yaml` as it is made —
/// there is no save step, so there is nothing to lose by pressing Esc, and no
/// second state to keep in step with the file. Changing a value back is the undo.
///
/// Reachable from both the file list and the viewer, so it is a self-contained
/// screen rather than a mode of either: it takes the terminal, loops until Esc, and
/// hands it back for the caller to repaint.
struct ConfigMenu {

    /// What the app has to do to make a change visible without a restart. The keys
    /// that cannot (`width`, `mouse`, the startup ones) say so in the view instead.
    struct Hooks {
        /// Hand a live-applicable value to whoever owns it — the theme and the
        /// mermaid keys live on the app's render context, not in a global.
        var applyRenderSetting: ((ConfigSetting, String) -> Void)?
        /// A rendering key changed, so any cached render is stale.
        var invalidateRender: (() -> Void)?
    }

    private let hooks: Hooks

    /// The file every change is written to, and the one the header names.
    let path: URL

    /// Keys a project-local `.termdown.yaml` also sets. Those win over the global
    /// file, so the view marks them: writing here would otherwise look ignored.
    let overriddenLocally: Set<String>

    /// Current values, by setting key — read from the file at open, then kept in
    /// step as changes are written.
    private var values: [String: String]

    init(hooks: Hooks = Hooks(), path: URL = AppConfig.globalConfigPath,
         local: AppConfig? = AppConfig.projectLocal(), global: AppConfig? = nil) {
        self.hooks = hooks
        self.path = path
        let loaded = global ?? AppConfig.loadFile(path) ?? AppConfig()
        values = Dictionary(uniqueKeysWithValues: ConfigSettings.editable.map {
            ($0.key, loaded.effectiveValue(for: $0))
        })
        overriddenLocally = Set(ConfigSettings.editable
            .filter { local?.value(for: $0) != nil }
            .map(\.key))
    }

    /// Show the view and return when the user closes it.
    mutating func run() {
        var selected = 0
        var typing: String?          // digits entered on a `number` row
        var needsRedraw = true
        var lastRows = -1
        var lastCols = -1

        Terminal.hideCursor()
        defer { Terminal.showCursor() }

        while true {
            let size = Terminal.size()
            if Terminal.didResize || size.rows != lastRows || size.cols != lastCols {
                Terminal.didResize = false
                lastRows = size.rows
                lastCols = size.cols
                needsRedraw = true
            }
            if needsRedraw {
                Terminal.render(draw(selected: selected, typing: typing,
                                     rows: size.rows, cols: size.cols))
                needsRedraw = false
            }

            guard let key = Terminal.readKey(timeoutMs: 150) else { continue }
            needsRedraw = true
            let setting = ConfigSettings.editable[selected]

            // A number row swallows digits while it is being typed, so the keys
            // below only see it once the entry is committed or abandoned.
            if let entered = typing {
                switch key {
                case .char(let c) where c.isNumber:
                    typing = String((entered + String(c)).prefix(4))
                case .backspace:
                    typing = String(entered.dropLast())
                case .enter:
                    // An empty entry means "auto", which the file spells as 0.
                    set(entered.isEmpty ? "0" : entered, for: setting)
                    typing = nil
                case .escape:
                    typing = nil
                default:
                    break
                }
                continue
            }

            switch key {
            case .up, .char("k"):
                selected = (selected - 1 + ConfigSettings.editable.count) % ConfigSettings.editable.count
            case .down, .char("j"):
                selected = (selected + 1) % ConfigSettings.editable.count
            case .char("g"):
                selected = 0
            case .char("G"):
                selected = ConfigSettings.editable.count - 1

            // Space cycles in place — the quick flip. Enter opens a list for a
            // choice, because cycling 27 themes one key at a time is not editing.
            case .char(" "), .right, .char("l"):
                set(setting.next(after: value(of: setting)), for: setting)
            case .left, .char("h"):
                set(setting.previous(before: value(of: setting)), for: setting)
            case .enter:
                switch setting.kind {
                case .toggle:
                    set(setting.next(after: value(of: setting)), for: setting)
                case .choice(let options):
                    pick(from: options, for: setting)
                case .number:
                    typing = ""
                }

            case .escape, .char("q"), .char(","):
                return
            case .char("?"):
                Terminal.showHelp(Terminal.configHelpGroups)
            case .ctrlL:
                Terminal.clearScreen()
            default:
                break
            }
        }
    }

    // MARK: - Editing

    func value(of setting: ConfigSetting) -> String {
        values[setting.key] ?? setting.fallback
    }

    /// Write one value and apply it if it can be applied now. Internal rather than
    /// private because this is the whole job of the view, and `run()` — the only
    /// other caller — needs a TTY to reach it.
    mutating func set(_ value: String, for setting: ConfigSetting) {
        guard value != values[setting.key] else { return }
        values[setting.key] = value
        // Written to the file the view named in its header, which is also what makes
        // this testable: a view pointed at a temp file must not touch the real config.
        AppConfig.writeValue(value, for: setting, to: path)
        apply(value, for: setting)
    }

    /// The live half of a change. Only the rendering keys can be applied to a
    /// running session; the rest are read once at startup, and the view says so
    /// rather than letting the user think the change did nothing.
    private func apply(_ value: String, for setting: ConfigSetting) {
        switch setting.key {
        case "theme", "mermaid", "mermaid-charset":
            hooks.applyRenderSetting?(setting, value)
        case "no-color":
            Ansi.colorEnabled = value != "true"
        case "wide-emoji":
            // Both measurement tables move together: a diagram measured one way
            // inside a document measured the other has its borders off by a cell.
            Ansi.emojiWidthMode = value == "scalar" ? .scalar : .cluster
            DisplayWidth.emojiWidthMode = value == "scalar" ? .scalar : .cluster
        default:
            return  // not live: nothing to do until the next launch
        }
        hooks.invalidateRender?()
    }

    /// A list overlay for a choice with more values than a key press should cycle.
    private mutating func pick(from options: [String], for setting: ConfigSetting) {
        let current = value(of: setting)
        let rows = options.map { ($0 == current ? "\u{25CF} " : "  ") + $0 }
        let chosen = Terminal.showOverlay(title: setting.label, items: rows,
                                          selectable: true, hint: "\u{2191}\u{2193} move  \u{00B7}  "
                                              + "\u{21B5} choose  \u{00B7}  Esc cancel")
        Terminal.clearScreen()
        if let chosen, chosen < options.count { set(options[chosen], for: setting) }
    }
}
