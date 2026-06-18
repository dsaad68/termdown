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
    let items: [String]
    /// Optional secondary text shown dimmed and right-aligned (e.g. mtime),
    /// indexed in parallel with `items`.
    var details: [String] = []

    /// Folder path shown in the second header row (abbreviated, e.g. ~/notes).
    var path: String = ""

    /// Whether mouse scroll events are enabled.
    var mouseEnabled: Bool = false

    /// Accent color (256) for fuzzy-matched characters.
    private static let accent = 39

    /// Show the menu and return the user's chosen action. When `context` is set
    /// (e.g. "New tab"), the launch wordmark is replaced with a slim header so the
    /// finder doesn't look like the whole app relaunching.
    func run(initialSelection: Int = 0, context: String? = nil) -> Action {
        guard !items.isEmpty else { return .quit }

        // Fast lookup for the per-item secondary column.
        var detailFor: [String: String] = [:]
        if details.count == items.count {
            for (i, item) in items.enumerated() { detailFor[item] = details[i] }
        }

        var selected = min(max(initialSelection, 0), items.count - 1)
        var top = 0
        var query = ""
        var filteredItems: [(item: String, indices: [Int])] = items.map { ($0, []) }
        var firstEsc = false
        var needsRedraw = true
        var lastRows = -1
        var lastCols = -1

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

            if selected < top { top = selected; needsRedraw = true }
            if selected >= top + viewport { top = selected - viewport + 1; needsRedraw = true }
            let maxTop = max(0, filteredItems.count - viewport)
            top = max(0, min(top, maxTop))
            selected = max(0, min(selected, filteredItems.count - 1))

            if needsRedraw {
                let frame = draw(selected: selected, top: top, viewport: viewport, rows: size.rows,
                                 cols: size.cols, query: query, filteredItems: filteredItems,
                                 detailFor: detailFor, context: context)
                Terminal.render(frame)
                needsRedraw = false
            }

            guard let key = Terminal.readKey(timeoutMs: 150) else { continue }
            needsRedraw = true

            switch key {
            case .up, .char("k"):
                selected = selected > 0 ? selected - 1 : filteredItems.count - 1
            case .down, .char("j"):
                selected = selected < filteredItems.count - 1 ? selected + 1 : 0
            case .mouseScroll(let delta):
                let next = selected + delta
                selected = max(0, min(filteredItems.count - 1, next))
            case .mouseClick(_, let y):
                // File rows start just below the header chrome. A click selects the
                // row; clicking the already-selected row opens it (like Enter).
                let offset = y - 1 - headerLines
                if offset >= 0, offset < viewport {
                    let idx = top + offset
                    if idx < filteredItems.count {
                        if idx == selected {
                            if let original = items.firstIndex(of: filteredItems[idx].item) {
                                return .open(original)
                            }
                        } else {
                            selected = idx
                        }
                    }
                }
            case .pageUp:
                selected = max(0, selected - viewport)
            case .pageDown:
                selected = min(filteredItems.count - 1, selected + viewport)
            case .enter:
                if !filteredItems.isEmpty {
                    let selectedItem = filteredItems[selected].item
                    if let originalIndex = items.firstIndex(of: selectedItem) {
                        return .open(originalIndex)
                    }
                }
                return .quit
            case .char("\\"):
                return .grep
            case .char("q"), .char("Q"), .char("c"):
                return .quit
            case .escape:
                if query.isEmpty || firstEsc {
                    return .quit
                } else {
                    firstEsc = true
                    query = ""
                    filteredItems = items.map { ($0, []) }
                    selected = 0
                    top = 0
                }
            case .char("g"):
                selected = 0
            case .char("G"):
                selected = filteredItems.count - 1
            case .char("?"):
                Terminal.showHelp(Terminal.menuHelpGroups)
            case .backspace:
                firstEsc = false
                if !query.isEmpty {
                    query.removeLast()
                    if query.isEmpty {
                        filteredItems = items.map { ($0, []) }
                    } else {
                        filteredItems = FuzzyMatch.filterAndSort(items, query: query)
                    }
                    selected = 0
                    top = 0
                }
            case .char(let c):
                firstEsc = false
                if c.isASCII && !c.isWhitespace && c != "\n" && c != "\r" {
                    query.append(c)
                    filteredItems = FuzzyMatch.filterAndSort(items, query: query)
                    selected = 0
                    top = 0
                }
            default:
                break
            }
        }
    }
}
