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

    /// Folder path shown in the second header row (abbreviated, e.g. ~/notes).
    var path: String = ""

    /// Whether mouse scroll events are enabled.
    var mouseEnabled: Bool = false

    /// Called when the watched folder changes; returns the refreshed
    /// item/detail lists, or nil if nothing actually changed (e.g. a file's
    /// mtime was touched without the file list itself differing).
    var onFolderChanged: (() -> (items: [String], details: [String])?)?

    /// Accent color (256) for fuzzy-matched characters.
    private static let accent = 39

    /// Show the menu and return the user's chosen action. When `context` is set
    /// (e.g. "New tab"), the launch wordmark is replaced with a slim header so the
    /// finder doesn't look like the whole app relaunching.
    func run(initialSelection: Int = 0, context: String? = nil) -> Action {
        guard !items.isEmpty else { return .quit }

        // `run()` is non-mutating, so a folder-change refresh updates these
        // local shadows rather than `self.items`/`self.details` — the caller
        // re-seeds a fresh `TerminalMenu` before the next `run()` call anyway.
        var items = self.items
        var details = self.details

        // Fast lookup for the per-item secondary column.
        var detailFor: [String: String] = [:]
        func rebuildDetailFor() {
            detailFor = [:]
            if details.count == items.count {
                for (i, item) in items.enumerated() { detailFor[item] = details[i] }
            }
        }
        rebuildDetailFor()

        var selected = min(max(initialSelection, 0), items.count - 1)
        var top = 0
        var query = ""
        var filteredItems: [(item: String, indices: [Int])] = items.map { ($0, []) }
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
            filteredItems = query.isEmpty
                ? items.map { ($0, []) }
                : FuzzyMatch.filterAndSort(items, query: query)
            selected = 0
            top = 0
        }

        Terminal.hideCursor()
        if mouseEnabled { Terminal.enableMouseTracking() }
        defer {
            if mouseEnabled { Terminal.disableMouseTracking() }
            Terminal.showCursor()
        }

        while true {
            let size = Terminal.size()
            // top border + 3 wordmark + subtitle + spacer + 3 search-box + separator
            let headerLines = 10
            let footerLines = 1  // bottom border
            let viewport = max(1, size.rows - headerLines - footerLines)

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
                    rebuildDetailFor()
                    applyFilter()
                }
                needsRedraw = true
            }

            if selected < top { top = selected; needsRedraw = true }
            if selected >= top + viewport { top = selected - viewport + 1; needsRedraw = true }
            let maxTop = max(0, filteredItems.count - viewport)
            top = max(0, min(top, maxTop))
            selected = max(0, min(selected, filteredItems.count - 1))

            if needsRedraw {
                let frame = draw(selected: selected, top: top, viewport: viewport, rows: size.rows,
                                 cols: size.cols, query: query, searching: searching,
                                 filteredItems: filteredItems, detailFor: detailFor, context: context)
                Terminal.render(frame)
                needsRedraw = false
            }

            guard let key = Terminal.readKey(timeoutMs: 150) else { continue }
            needsRedraw = true

            switch key {
            // ── Navigation, paging, mouse and open: these never collide with
            // typing, so they work whether or not the search box is focused. ──
            case .up:
                selected = selected > 0 ? selected - 1 : filteredItems.count - 1
            case .down:
                selected = selected < filteredItems.count - 1 ? selected + 1 : 0
            case .pageUp:
                selected = max(0, selected - viewport)
            case .pageDown:
                selected = min(filteredItems.count - 1, selected + viewport)
            case .mouseScroll(let delta):
                selected = max(0, min(filteredItems.count - 1, selected + delta))
            case .mouseClick(_, let y):
                // File rows start just below the header chrome. A click selects the
                // row; clicking the already-selected row opens it (like Enter).
                let offset = y - 1 - headerLines
                if offset >= 0, offset < viewport, top + offset < filteredItems.count {
                    let idx = top + offset
                    if idx == selected, let original = items.firstIndex(of: filteredItems[idx].item) {
                        return .open(original)
                    }
                    selected = idx
                }
            case .enter:
                if !filteredItems.isEmpty,
                   let originalIndex = items.firstIndex(of: filteredItems[selected].item) {
                    return .open(originalIndex)
                }
                return .quit

            // ── Navigation-mode keys (ignored while the search box is focused, so
            // those letters can be typed into a query instead). ──
            case .char("k") where !searching:
                selected = selected > 0 ? selected - 1 : filteredItems.count - 1
            case .char("j") where !searching:
                selected = selected < filteredItems.count - 1 ? selected + 1 : 0
            case .char("g") where !searching:
                selected = 0
            case .char("G") where !searching:
                selected = filteredItems.count - 1
            case .char("q") where !searching, .char("Q") where !searching:
                return .quit
            case .char("\\") where !searching:
                return .grep
            case .char("?") where !searching:
                Terminal.showHelp(Terminal.menuHelpGroups)
            case .char("/") where !searching:
                searching = true

            // ── Entering / leaving the search box ──
            case .escape:
                if searching {
                    searching = false          // leave the box, keep the filter & results
                } else if query.isEmpty {
                    return .quit
                } else {
                    query = ""; applyFilter()  // clear an active filter, stay in the list
                }
            case .backspace:
                if searching, !query.isEmpty {
                    query.removeLast(); applyFilter()
                } else if searching {
                    searching = false          // backspace on an empty box leaves it
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
