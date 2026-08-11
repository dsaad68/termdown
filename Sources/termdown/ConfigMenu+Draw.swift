import Foundation
import termdownCore

/// Rendering for the settings view: the framed panel, one row per key, and the
/// footer that explains the row under the cursor. Pure layout — no input handling
/// and no writes.
extension ConfigMenu {

    /// Column the values start in, so they line up down the panel.
    private static let valueColumn = 22

    /// How many rows the footer note may take before it is shortened instead.
    private static let blurbLines = 2

    /// A piece of chrome around the settings, and what it costs in rows.
    private enum Section: CaseIterable {
        case path, listRule, footerRule, blurb, hint

        /// `path` is a blank, the path and a blank; the note can run to two lines.
        func rows(noteLines: Int) -> Int {
            switch self {
            case .path: return 3
            case .blurb: return noteLines
            default: return 1
            }
        }

        /// Dropped in this order when the terminal is too short for all of it: the
        /// file path goes first (the values still work without it), the rule above
        /// the list last, since it is what separates the panel from its own header.
        static let dropOrder: [Section] = [.path, .blurb, .footerRule, .hint, .listRule]
    }

    /// Build the whole frame, exactly `rows` tall and `cols` wide.
    func draw(selected: Int, typing: String?, rows: Int, cols: Int) -> [String] {
        let P = Ansi.Pastel.self
        let bv = Ansi.color("\u{2502}", P.borderDim)
        let inner = max(0, cols - 2)
        let settings = ConfigSettings.editable
        var out: [String] = []

        // ── Top border, with the panel's name on it ──
        let legend = Ansi.wrap(" settings ", [1] + Ansi.fg(P.accent))
        let legendW = Ansi.width(legend) <= max(0, inner - 1) ? Ansi.width(legend) : 0
        out.append(Ansi.color("\u{256D}\u{2500}", P.borderDim)
                   + (legendW > 0 ? legend : "")
                   + Ansi.color(String(repeating: "\u{2500}", count: max(0, inner - 1 - legendW))
                                + "\u{256E}", P.borderDim))

        // ── How much chrome this height can carry. The panel is a fixed frame in a
        // terminal of any size, so the parts come off one at a time rather than the
        // whole thing running past the bottom of the screen. ──
        let setting = settings[min(selected, settings.count - 1)]
        let note = Self.noteLines(for: setting, overriddenLocally: overriddenLocally,
                                  width: max(0, inner - 4))
        var shown = Set(Section.allCases)
        func chrome() -> Int {
            2 + shown.reduce(0) { $0 + $1.rows(noteLines: note.count) }   // + the two borders
        }
        for section in Section.dropOrder where chrome() + 1 > rows { shown.remove(section) }

        // ── The file being edited. Every change lands here as it is made, so the
        // path is the most important thing on screen after the values themselves. ──
        if shown.contains(.path) {
            out.append(bv + String(repeating: " ", count: inner) + bv)
            let file = Ansi.color(Ansi.clip(Self.displayPath, to: max(0, inner - 4)), P.textDim)
            out.append(bv + Ansi.fit("   " + file, to: inner) + bv)
            out.append(bv + String(repeating: " ", count: inner) + bv)
        }
        if shown.contains(.listRule) {
            out.append(Ansi.color("\u{251C}" + String(repeating: "\u{2500}", count: inner)
                                  + "\u{2524}", P.borderDim))
        }

        // ── One row per setting, then blanks down to the footer ──
        let listRows = max(1, rows - chrome())
        let top = max(0, min(selected - listRows + 1, settings.count - listRows))
        for i in 0..<listRows {
            let index = top + i
            guard index < settings.count else {
                out.append(bv + String(repeating: " ", count: inner) + bv)
                continue
            }
            out.append(bv + row(settings[index], selected: index == selected,
                                typing: index == selected ? typing : nil, cols: inner) + bv)
        }

        // ── Footer: what the row under the cursor does, then the keys ──
        if shown.contains(.footerRule) {
            out.append(Ansi.color("\u{251C}" + String(repeating: "\u{2500}", count: inner)
                                  + "\u{2524}", P.borderDim))
        }
        if shown.contains(.blurb) {
            for line in note {
                out.append(bv + Ansi.fit("   " + Ansi.color(line, P.textDim), to: inner) + bv)
            }
        }

        let dot = Ansi.color("  \u{00B7}  ", P.borderDim)
        let keys = typing == nil
            ? [Ansi.color("\u{2191}\u{2193} move", P.textDim), Ansi.color("Space cycle", P.textDim),
               Ansi.color("\u{21B5} edit", P.textDim), Ansi.color("Esc close", P.textDim)]
            : [Ansi.color("digits", P.textDim), Ansi.color("\u{21B5} set", P.textDim),
               Ansi.color("empty = auto", P.textDim), Ansi.color("Esc cancel", P.textDim)]
        if shown.contains(.hint) {
            let hint = Ansi.fittedHint(keys, separator: dot, width: max(0, inner - 4))
            out.append(bv + Ansi.fit("   " + hint, to: inner) + bv)
        }
        out.append(Ansi.color("\u{2570}" + String(repeating: "\u{2500}", count: inner)
                              + "\u{256F}", P.borderDim))

        // Below four rows there is no arrangement of borders and a value that fits;
        // clipping is still better than a frame that runs off the screen and scrolls
        // every later redraw out of alignment.
        return out.count > rows ? Array(out.prefix(rows)) : out
    }

    /// One setting: label, value, and — on the right — whether it is live and which
    /// file has the last word.
    private func row(_ setting: ConfigSetting, selected: Bool, typing: String?,
                     cols: Int) -> String {
        let P = Ansi.Pastel.self
        let marker = selected ? Ansi.bar(P.selectBar) + " " : "  "
        let label = Ansi.pad(setting.label, to: min(Self.valueColumn, max(1, cols - 4)))

        let raw = typing.map { $0.isEmpty ? "auto" : $0 } ?? setting.display(value(of: setting))
        var shown = selected
            ? Ansi.wrap(raw, [1] + Ansi.fg(P.selectFg))
            : Ansi.color(raw, valueColor(setting, raw))
        if typing != nil { shown += Ansi.color("\u{2588}", P.accent) }

        // The marker on the right earns its space only when the row is wide enough
        // for the value it is annotating.
        let flag: String = if overriddenLocally.contains(setting.key) {
            "local"
        } else if setting.appliesLive {
            ""
        } else {
            "\u{21BB}"   // ↻ — read at startup, so this one waits for the next launch
        }
        let left = marker + Ansi.color(label, selected ? P.selectFg : P.textDim) + shown
        let leftW = Ansi.width(left)
        let flagW = Ansi.width(flag)
        let line = flagW > 0 && leftW + flagW + 3 <= cols
            ? left + String(repeating: " ", count: max(1, cols - leftW - flagW - 1))
                + Ansi.color(flag, selected ? P.accentDim : P.borderDim) + " "
            : left
        let row = Ansi.fit(line, to: cols)
        return selected ? Ansi.bgRow(row, bg: P.selectBg, cols: cols) : row
    }

    /// The footer note, wrapped to the width it has.
    ///
    /// A long blurb used to be cut mid-word — `takes ef…` — which is the one thing a
    /// line of explanation must not do. It wraps instead, and when even two lines are
    /// not enough the caveat is dropped rather than sliced: the row itself already
    /// carries `↻` or `local`, so nothing is lost that is not still on screen.
    static func noteLines(for setting: ConfigSetting, overriddenLocally: Set<String>,
                          width: Int) -> [String] {
        // One caveat at most, and the local file outranks the restart note: a key a
        // project file overrides will not take effect next launch either.
        let caveat: String = if overriddenLocally.contains(setting.key) {
            " \u{00B7} .termdown.yaml wins here"
        } else if !setting.appliesLive {
            " \u{00B7} takes effect next launch"
        } else {
            ""
        }
        let full = wrapped(setting.blurb + caveat, width: width)
        if full.count <= blurbLines { return full }
        let short = wrapped(setting.blurb, width: width)
        if short.count <= blurbLines { return short }
        // Narrower than the blurb itself can wrap into: clip the tail, which is the
        // only case left where something has to give.
        return Array(short.prefix(blurbLines - 1))
            + [Ansi.clip(short[blurbLines - 1], to: width)]
    }

    /// Break plain text into lines no wider than `width`, on spaces. A single word
    /// too long for the width is cut, since there is nowhere else to break it.
    private static func wrapped(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [""] }
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true).map(String.init) {
            let candidate = line.isEmpty ? word : line + " " + word
            if Ansi.width(candidate) <= width {
                line = candidate
            } else {
                if !line.isEmpty { lines.append(line) }
                line = Ansi.width(word) <= width ? word : Ansi.clip(word, to: width)
            }
        }
        if !line.isEmpty || lines.isEmpty { lines.append(line) }
        return lines
    }

    /// A value's color: the accent for something switched on or chosen, dim for an
    /// `off`, so the panel can be read down the value column alone.
    private func valueColor(_ setting: ConfigSetting, _ value: String) -> Ansi.Color {
        let P = Ansi.Pastel.self
        if case .toggle = setting.kind { return value == "true" ? P.green : P.borderDim }
        return P.tealAccent
    }

    /// `~/.config/…` rather than the absolute path: shorter, and the home directory
    /// is not information.
    static var displayPath: String {
        let path = AppConfig.globalConfigPath.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + String(path.dropFirst(home.count)) : path
    }
}
