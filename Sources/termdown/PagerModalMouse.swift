import Foundation
import termdownCore

/// Mouse handling for the pager's modal states.
///
/// Every modal branch in `run()` consumes the key and `continue`s, so mouse
/// events never reached `handleKey` and were silently dropped in search, goto,
/// edit, the theme picker and sidebar focus. Each handler below returns true
/// when it consumed the event, leaving the caller's keyboard path untouched.
extension Pager {

    /// True when a modal state is active that has its own mouse handling.
    var hasModalMouse: Bool {
        editMode || searchMode || gotoMode || themePickerMode || savePromptMode
            || (sidebarFocus && sidebarActive)
    }

    /// Route a mouse event to whichever modal owns it. Returns false when the
    /// event should fall through to the normal `handleKey` path.
    mutating func handleModalMouse(_ key: Terminal.Key) -> Bool {
        switch key {
        case .mouseScroll(let delta):
            return modalScroll(delta)
        case .mouseClick(let x, let y):
            return modalClick(x: x, y: y)
        case .mouseDrag, .mouseRelease:
            // Drag-select belongs to the normal view; swallow it while modal so
            // a stray motion cannot start a selection behind an overlay.
            return hasModalMouse
        default:
            return false
        }
    }

    private mutating func modalScroll(_ delta: Int) -> Bool {
        if savePromptMode { return true }        // deliberately inert: no accidental answer
        if themePickerMode {
            guard !themePickerItems().isEmpty else { return true }
            let n = themePickerItems().count
            themePickerSel = max(0, min(n - 1, themePickerSel + delta))
            applyThemePreview(Theme.all[themePickerSel].name)
            return true
        }
        if sidebarFocus, sidebarActive {
            sidebarCursor = max(0, min(max(0, headings.count - 1), sidebarCursor + delta))
            return true
        }
        if editMode { return true }              // the field would scroll off screen
        if searchMode || gotoMode {
            // Scroll the document under the prompt; the query stays live.
            top = max(0, min(maxTop, top + delta))
            return true
        }
        return false
    }

    private mutating func modalClick(x: Int, y: Int) -> Bool {
        if savePromptMode { return true }        // only s/d/c may answer it
        if themePickerMode { return themePickerClick(x: x, y: y) }
        if editMode { return editClick(x: x, y: y) }
        if sidebarFocus, sidebarActive { return sidebarClick(x: x, y: y) }
        if searchMode || gotoMode { return promptClick(y: y) }
        return false
    }

    // MARK: - Theme picker

    private mutating func themePickerClick(x: Int, y: Int) -> Bool {
        let items = themePickerItems()
        let g = Terminal.listBoxGeometry(title: "Theme", items: items, selected: themePickerSel,
                                         hint: "\u{2191}\u{2193} preview \u{00B7} \u{21B5} save \u{00B7} Esc cancel")
        guard g.contains(x: x, y: y) else {
            // Outside the box cancels, restoring the theme the preview replaced.
            applyThemePreview(currentThemeName)   // restore what the preview replaced
            themePickerMode = false
            return true
        }
        guard let idx = g.itemIndex(atRow: y, count: items.count) else { return true }
        if idx == themePickerSel {
            // A second click on the highlighted row commits, like Enter.
            currentThemeName = Theme.all[themePickerSel].name
            onSaveTheme?(currentThemeName)
            themePickerMode = false
        } else {
            themePickerSel = idx
            applyThemePreview(Theme.all[themePickerSel].name)
        }
        return true
    }

    // MARK: - Inline editor

    /// Click to position the caret. `editCaretCol` is a character index into the
    /// raw source line while `selectionPoint` yields a display column, and the
    /// two only coincide on pure-ASCII text — convert, or a click on a line
    /// holding CJK or emoji drops the caret cells away from the pointer and the
    /// next keystroke edits the wrong place.
    private mutating func editClick(x: Int, y: Int) -> Bool {
        guard let p = selectionPoint(x: x, y: y) else { return true }
        let row = p.line - editDisplayStart
        guard row >= 0, row < editBuffer.count else { return true }
        editCaretRow = row
        editCaretCol = Ansi.characterIndex(editBuffer[row], atColumn: p.col)
        needsRedraw = true
        return true
    }

    // MARK: - Sidebar

    private mutating func sidebarClick(x: Int, y: Int) -> Bool {
        // A click in the content area hands focus back to the document.
        guard x - 1 < Pager.sidebarWidth else {
            sidebarFocus = false
            return false                          // let the normal path see it
        }
        guard let idx = sidebarHeadingIndex(atRow: y, top: top, contentRows: contentRows,
                                            sidebarFocus: true, sidebarCursor: sidebarCursor)
        else { return true }
        if idx == sidebarCursor {
            // Second click jumps the document, like Enter.
            top = max(0, min(headings[sidebarCursor].lineIndex - Pager.scrolloff, maxTop))
        } else {
            sidebarCursor = idx
        }
        return true
    }

    // MARK: - Search / goto prompts

    /// A click on a content row accepts the prompt and puts the cursor there —
    /// clicking a destination *is* the request. Clicking the status bar cancels.
    private mutating func promptClick(y: Int) -> Bool {
        let row = y - 1
        guard row >= 0, row < contentRows else {
            // Cancel exactly as Escape does. Only closing the prompt left the
            // abandoned query still highlighted, still bound to `n`/`N`, and
            // the viewport parked wherever the incremental search scrolled it.
            if searchMode { cancelSearch() } else { cancelGoto() }
            return true
        }
        let line = top + row
        if searchMode { searchMode = false } else { gotoMode = false }
        if line < lines.count { setCursor(line) }
        return true
    }
}
