extension Terminal {

    // MARK: - Help content (grouped into tabbed panes)

    /// File-list help, grouped by function for the tabbed `?` overlay.
    static let menuHelpGroups: [(name: String, items: [String])] = [
        ("Move", [
            "↑/↓ or j/k    Move selection",
            "g / G         Jump to first / last",
            "PgUp / PgDn   Move by a page",
        ]),
        ("Filter", [
            "Type          Filter by fuzzy match",
            "Backspace     Delete filter character",
            "Esc           Clear filter, then quit",
        ]),
        ("Open", [
            "Enter         Open selected file",
            "Click         Select; click again to open",
            "\\             Project-wide search (grep)",
            "q             Quit",
            "?             Show this help",
        ]),
    ]

    /// Viewer (pager) help, grouped by function for the tabbed `?` overlay.
    static let pagerHelpGroups: [(name: String, items: [String])] = [
        ("Move", [
            "↑/↓ or j/k       Scroll one line",
            "Space/PgDn, b    Scroll one page",
            "d / u            Scroll half a page",
            "←/→ or h/l       Scroll horizontally (no-wrap)",
            "g/Home, G/End    Top / bottom",
            ":N               Jump to line N",
            "] / [            Next / previous heading",
        ]),
        ("Search", [
            "/                Search (incremental)",
            "n / N            Next / previous match",
            "\\                Project-wide search (grep)",
        ]),
        ("Links", [
            "Tab / Shift-Tab  Cycle links",
            "Enter / o        Open focused link (in place)",
            "O / Shift-Enter  Open focused link in a new tab",
            "Click            Follow link under the cursor",
            "[[Page]]         Wikilink → open matching file",
            "Backspace        Navigate back",
            "Y                Copy focused / nearest link URL",
        ]),
        ("Tabs", [
            "T                Open a document in a new tab",
            "1–9              Jump to tab N",
            "} / {            Next / previous tab",
            "x                Close current tab",
        ]),
        ("View", [
            "p                Theme selector (live preview, Enter saves)",
            "B                Heading banners (h1–h4 as filled blocks)",
            "s                Toggle outline sidebar",
            "s (when open)    Focus sidebar (↑↓ move, Enter jump, z fold, q close)",
            "w                Toggle line wrap",
            "+ / -            Widen / narrow text",
            "F                Toggle follow mode",
        ]),
        ("Folds", [
            "z                Fold / unfold current section",
            "Z                Fold all / unfold all sections",
            "t                Contents / Open Tabs overlay (t switches panes)",
        ]),
        ("Misc", [
            "y                Copy code block nearest cursor",
            "Ctrl-L           Force redraw",
            "q / Esc          Close sidebar, else extra tab, else file list",
            "?                Show this help",
        ]),
    ]
}
