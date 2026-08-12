import Foundation
import termdownCore

/// Viewer keys whose handling is more than one line: opening a new tab through the
/// finder, cycling tabs, and the settings view.
///
/// Split from `PagerInput.swift` for two reasons that pull the same way — that file
/// sits on the 400-line ceiling, and its `handleKey` switch sits on the
/// cyclomatic-complexity one, where every branch inside a case counts against the
/// switch that holds it. A case with a body belongs in a function with a name.
extension Pager {

    /// `T` — pick a document in the file finder and open it in a new tab.
    mutating func openNewTabFromFinder() {
        guard let onNewTab else { return }
        if let url = onNewTab() { openInNewTab(url) }
        // The finder showed the cursor and drew its own box; a full pager redraw
        // overwrites every row (render clears below), so no flashy screen-clear is
        // needed on the way back.
        Terminal.hideCursor()
        needsRedraw = true
    }

    /// `}` / `{` — the next or previous tab, wrapping round.
    mutating func cycleTab(by step: Int) {
        guard tabs.count > 1 else { return }
        let next = (activeTab + step + tabs.count) % tabs.count
        guard guardDirty(.switchTab(next)) else { return }
        snapshot()
        activate(next)
    }

    /// `,` — the settings view. It paints the whole screen, so the document has to be
    /// redrawn and re-rendered: a setting it changed (theme, mermaid) feeds the
    /// renderer.
    mutating func openSettings() {
        guard onSettings != nil else { return }
        onSettings?()
        Terminal.clearScreen()
        currentRenderWidth = -1
        needsRedraw = true
    }
}
