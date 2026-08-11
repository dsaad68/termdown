import Foundation
import termdownCore

/// An interactive, arrow-key driven file picker rendered in the terminal.
struct TerminalMenu {

    /// What the user chose to do from the file list.
    enum Action: Equatable {
        case open(Int)   // open the file at this original index
        case grep        // launch project-wide search
        case quit
    }

    let title: String
    var items: [String]
    /// Optional secondary text shown dimmed and right-aligned (e.g. mtime),
    /// indexed in parallel with `items`.
    var details: [String] = []

    /// Which list is showing and where in the folder hierarchy it stands. Held
    /// across `run()` calls, so coming back from the viewer lands you in the
    /// folder you were browsing rather than at the top of the whole project.
    var list = MenuList()

    /// Folder path shown in the second header row (abbreviated, e.g. ~/notes).
    var path: String = ""

    /// Whether mouse scroll events are enabled.
    var mouseEnabled: Bool = false

    /// Opens the settings view (`,`), returning once the user closes it. Provided by
    /// the app, which owns the render context a live setting has to reach.
    var onSettings: (() -> Void)?

    /// Called when the watched folder changes; returns the refreshed
    /// item/detail lists, or nil if nothing actually changed (e.g. a file's
    /// mtime was touched without the file list itself differing).
    var onFolderChanged: (() -> (items: [String], details: [String], tree: FolderTree)?)?

    /// Accent color (256) for fuzzy-matched characters.
    private static let accent = 39

    /// Show the menu and return the user's chosen action. When `context` is set
    /// (e.g. "New tab"), the launch wordmark is replaced with a slim header so the
    /// finder doesn't look like the whole app relaunching.
    mutating func run(initialSelection: Int = 0, context: String? = nil) -> Action {
        guard !items.isEmpty else { return .quit }

        var rows = list.rows(labels: items, details: details)
        var selected = 0
        var top = 0
        var query = ""
        var visible: [MenuList.Visible] = rows.map { .init(row: $0, indices: []) }
        // Filtering is modal: keys navigate the list until the user focuses the
        // search box with `/`, after which every printable key types into the
        // filter (so a query may contain j/k/g/q/c like any other letter).
        var searching = false
        var needsRedraw = true
        var lastRows = -1
        var lastCols = -1

        // Recompute the fuzzy filter from `query` and park the cursor on the
        // top match. Also used when the folder changes underneath an active filter.
        func applyFilter() {
            visible = FuzzyMatch.filterAndSort(rows, query: query, label: \.label)
                .map { MenuList.Visible(row: $0.item, indices: $0.indices) }
            selected = 0
            top = 0
        }

        /// Rebuild the rows after the list itself changes — a different mode, a
        /// different folder, or a rescan — keeping `keep` selected if it is still
        /// there (browsing up should land on the folder you came out of).
        func rebuild(keep: MenuList.RowKind? = nil) {
            rows = list.rows(labels: items, details: details)
            applyFilter()
            if let keep, let at = visible.firstIndex(where: { $0.row.kind == keep }) { selected = at }
        }

        /// Step into whatever the cursor is on. Nothing to open means the list moved,
        /// so it is rebuilt — landing on the first row that is not `../`, since
        /// selecting the way back out would make a second Enter undo the first.
        func stepInto(_ row: MenuList.Row) -> Int? {
            if let index = list.activate(row) { return index }
            query = ""
            searching = false
            rebuild()
            selected = list.firstEntry(in: visible.map(\.row))
            return nil
        }

        /// Leave the folder we are in for its parent, selecting the folder we came
        /// out of. A no-op in an un-narrowed file list and at the root.
        func upOneLevel() {
            let leaving = list.cwd
            guard list.up() else { return }
            query = ""
            rebuild(keep: .folder(leaving))
        }

        // `lastSelection` is an entry index, so find the row that stands for it.
        if let at = rows.firstIndex(where: { $0.kind == .file(initialSelection) }) { selected = at }

        Terminal.hideCursor()
        if mouseEnabled { Terminal.enableMouseTracking() }
        defer {
            if mouseEnabled { Terminal.disableMouseTracking() }
            Terminal.showCursor()
        }

        while true {
            let size = Terminal.size()
            // top border + 3 wordmark + subtitle + spacer + 3 search-box + separator.
            // Fixed: the breadcrumb is *inside* the list below, not part of this.
            let headerLines = 10
            let footerLines = 1  // bottom border
            let viewport = max(1, size.rows - headerLines - footerLines)
            // The breadcrumb row lives inside the bordered list, above the rows, so
            // it takes one of them — and pushes every clickable row down by one.
            let listRows = list.listRows(in: viewport)
            let rowsStart = headerLines + (list.showsBreadcrumbRow ? 1 : 0)

            if Terminal.didResize || size.rows != lastRows || size.cols != lastCols {
                Terminal.didResize = false
                lastRows = size.rows
                lastCols = size.cols
                needsRedraw = true
            }

            if Terminal.folderChanged {
                Terminal.folderChanged = false
                if let refreshed = onFolderChanged?() {
                    items = refreshed.items
                    details = refreshed.details
                    list.tree = refreshed.tree
                    rebuild()
                }
                needsRedraw = true
            }

            if selected < top { top = selected; needsRedraw = true }
            if selected >= top + listRows { top = selected - listRows + 1; needsRedraw = true }
            let maxTop = max(0, visible.count - listRows)
            top = max(0, min(top, maxTop))
            selected = max(0, min(selected, visible.count - 1))

            if needsRedraw {
                let frame = draw(selected: selected, top: top, viewport: viewport, rows: size.rows,
                                 cols: size.cols, query: query, searching: searching,
                                 visible: visible, total: rows.count { !$0.isUp },
                                 context: context)
                Terminal.render(frame)
                needsRedraw = false
            }

            guard let key = Terminal.readKey(timeoutMs: 150) else { continue }
            needsRedraw = true

            switch key {
            // ── Navigation, paging, mouse and open: these never collide with
            // typing, so they work whether or not the search box is focused. ──
            case .up:
                selected = selected > 0 ? selected - 1 : visible.count - 1
            case .down:
                selected = selected < visible.count - 1 ? selected + 1 : 0
            case .pageUp:
                selected = max(0, selected - listRows)
            case .pageDown:
                selected = min(visible.count - 1, selected + listRows)
            case .mouseScroll(let delta):
                // A flick queues an event per notch and each would repaint the
                // whole list; land on the final row and draw once.
                let d = Terminal.coalesceScroll(delta)
                selected = max(0, min(visible.count - 1, selected + d))
            case .mouseClick(_, let y):
                // Rows start below the header chrome and the breadcrumb row, when
                // there is one. A click selects the row; clicking the
                // already-selected row opens it (like Enter).
                let offset = y - 1 - rowsStart
                if offset >= 0, offset < listRows, top + offset < visible.count {
                    let idx = top + offset
                    if idx == selected {
                        if let index = stepInto(visible[idx].row) { return .open(index) }
                    } else {
                        selected = idx
                    }
                }
            case .enter:
                guard !visible.isEmpty else { return .quit }
                if let index = stepInto(visible[selected].row) { return .open(index) }

            // ── Navigation-mode keys (ignored while the search box is focused, so
            // those letters can be typed into a query instead). ──
            case .char("k") where !searching:
                selected = selected > 0 ? selected - 1 : visible.count - 1
            case .char("j") where !searching:
                selected = selected < visible.count - 1 ? selected + 1 : 0
            case .char("g") where !searching:
                selected = 0
            case .char("G") where !searching:
                selected = visible.count - 1
            case .char("q") where !searching, .char("Q") where !searching:
                return .quit
            case .char("\\") where !searching:
                return .grep
            case .char("?") where !searching:
                Terminal.showHelp(Terminal.menuHelpGroups)
            case .char(",") where !searching:
                onSettings?()
                Terminal.clearScreen()   // the settings view drew over the whole frame
            case .char("/") where !searching:
                // The search box searches the whole project, so it leaves the
                // folder browser; clearing the query brings it back.
                list.searchAllFiles()
                rebuild()
                searching = true

            // ── Folders ──
            case .char("d") where !searching:
                query = ""
                list.toggleMode()
                rebuild()
            case .left where !searching, .char("h") where !searching:
                upOneLevel()

            // ── Entering / leaving the search box ──
            case .escape:
                if searching {
                    searching = false          // leave the box, keep the filter & results
                    if query.isEmpty, list.restoreAfterSearch() { rebuild() }
                } else if !query.isEmpty {
                    query = ""                 // clear an active filter, stay in the list
                    if list.restoreAfterSearch() { rebuild() } else { applyFilter() }
                } else if list.clearScope() {
                    rebuild()                  // widen back to the whole project
                } else {
                    return .quit
                }
            case .backspace:
                if !searching {
                    upOneLevel()               // in the browser: out to the parent folder
                } else if !query.isEmpty {
                    query.removeLast(); applyFilter()
                } else {
                    searching = false          // backspace on an empty box leaves it
                    if list.restoreAfterSearch() { rebuild() }
                }

            // ── Typing into the focused search box ──
            case .char(let c) where searching && c.isASCII && !c.isWhitespace && c != "\n" && c != "\r":
                query.append(c); applyFilter()

            default:
                break
            }
        }
    }
}
