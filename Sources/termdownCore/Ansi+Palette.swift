import Foundation

/// 256-palette ↔ RGB conversion and the TUI chrome palette. Split out of
/// `Ansi.swift`, which sits on the 400-line lint ceiling.
extension Ansi {

    // MARK: - 256-palette ↔ RGB conversion

    /// Standard xterm 256-palette → RGB. 16–231 is the 6×6×6 color cube,
    /// 232–255 the grayscale ramp, 0–15 the conventional system colors.
    static func palette256RGB(_ n: Int) -> (Int, Int, Int) {
        if n >= 16 && n <= 231 {
            let i = n - 16
            let levels = [0, 95, 135, 175, 215, 255]
            return (levels[i / 36], levels[(i / 6) % 6], levels[i % 6])
        }
        if n >= 232 && n <= 255 {
            let v = 8 + 10 * (n - 232)
            return (v, v, v)
        }
        let sys: [(Int, Int, Int)] = [
            (0,0,0),(128,0,0),(0,128,0),(128,128,0),(0,0,128),(128,0,128),(0,128,128),(192,192,192),
            (128,128,128),(255,0,0),(0,255,0),(255,255,0),(0,0,255),(255,0,255),(0,255,255),(255,255,255),
        ]
        return sys[max(0, min(15, n))]
    }

    /// Nearest 256-palette index for an RGB triple (used when emitting `.rgb`
    /// colors on a 256-only terminal). Weighs the color cube against the
    /// grayscale ramp and picks whichever is closer.
    static func nearest256(_ r: Int, _ g: Int, _ b: Int) -> Int {
        let levels = [0, 95, 135, 175, 215, 255]
        func nearestLevel(_ v: Int) -> Int {
            var best = 0, bestD = Int.max
            for (i, l) in levels.enumerated() where abs(l - v) < bestD { bestD = abs(l - v); best = i }
            return best
        }
        let ri = nearestLevel(r), gi = nearestLevel(g), bi = nearestLevel(b)
        let (cr, cg, cb) = (levels[ri], levels[gi], levels[bi])
        let cubeDist = (cr-r)*(cr-r) + (cg-g)*(cg-g) + (cb-b)*(cb-b)
        let gray = (r + g + b) / 3
        let gIdx = max(0, min(23, (gray - 8 + 5) / 10))
        let gv = 8 + 10 * gIdx
        let grayDist = (gv-r)*(gv-r) + (gv-g)*(gv-g) + (gv-b)*(gv-b)
        return grayDist < cubeDist ? 232 + gIdx : 16 + 36 * ri + 6 * gi + bi
    }

    /// Fill an entire row with a background color, padding to `cols`.
    ///
    /// Styled segments inside `s` typically end with a full SGR reset
    /// (`ESC[0m`) which also clears the background — so a naive wrap would only
    /// tint the row up to the first reset. We re-assert the background after
    /// every internal reset so the fill stays continuous across the whole row.
    public static func bgRow(_ s: String, bg bgC: Color, cols: Int) -> String {
        guard colorEnabled else { return pad(s, to: cols) }
        let bgSeq = code(bg(bgC))
        let patched = s.replacingOccurrences(of: reset, with: reset + bgSeq)
        let padded = pad(patched, to: cols)
        return bgSeq + padded + reset
    }

    /// A left-edge accent bar (▌) used to mark selected / active rows.
    public static func bar(_ color: Color) -> String { Ansi.color("\u{258C}", color) }
    // MARK: - TUI Matte Pastel Palette
    //
    // A cohesive, matte pastel 256-color palette (Catppuccin / Rosé Pine
    // flavoured) used throughout the TUI chrome. Surfaces are layered matte
    // darks; accents are soft and desaturated so nothing shouts. Selection is
    // a subtle raised surface paired with a mauve accent bar — the modern look
    // shared by lazygit, yazi and helix — rather than a loud colour fill.

    public enum Pastel {
        // ── Surfaces (layered matte darks) ──
        public static let headerBg:    Color = 237   // raised title / header surface
        public static let panelBg:     Color = 236   // sidebar / panel surface
        public static let selectBg:    Color = 238   // matte selection surface
        // Overlay tints. Distinct from `selectBg` and from each other: several
        // can be live on one row, and `bgRange` carries no weight/attribute, so
        // the current match is told apart by colour rather than by bold.
        public static let searchBg:      Color = 60    // other search matches — dark lavender
        public static let searchCurBg:   Color = 97    // the current match — brighter
        public static let linkFocusBg:   Color = 24    // focused link — dark teal
        public static let outlineSelBg: Color = 60   // focused outline selection — dark lavender, echoes accent 183
        public static let statusBg:    Color = 237   // status bar (lighter segment)
        public static let statusDimBg: Color = 235   // status bar (darker segment)
        public static let sidebarBg:   Color = 236   // focused sidebar background
        public static let shadow:      Color = 233   // drop shadow

        // ── Text ──
        public static let headerFg:    Color = 253   // near-white headings
        public static let statusFg:    Color = 250   // status bar text
        public static let textDim:     Color = 245   // muted secondary text
        public static let selectFg:    Color = 231   // bright white on selection

        // ── Matte pastel accents ──
        public static let accent:      Color = 183   // mauve / lavender — primary
        public static let accentDim:   Color = 146   // muted lavender
        public static let pink:        Color = 218   // soft pink
        public static let tealAccent:  Color = 152   // soft teal — secondary emphasis
        public static let green:       Color = 151   // sage green
        public static let peach:       Color = 216   // soft peach
        public static let blue:        Color = 111   // soft blue
        public static let yellow:      Color = 223   // soft yellow

        // ── Roles ──
        public static let selectBar:   Color = 183   // mauve accent bar on active rows
        public static let selectorFg:  Color = 151   // green prompt caret
        public static let matchFg:     Color = 223   // fuzzy-match highlight (soft yellow)
        public static let border:      Color = 244   // brighter border accent
        public static let borderDim:   Color = 240   // subtle frame border
    }
}
