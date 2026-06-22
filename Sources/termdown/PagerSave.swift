import Foundation
import termdownCore

extension Pager {

    // MARK: - Unsaved changes (dirty state, save, leave-prompt)

    /// Gate a document-leaving action behind the unsaved-changes prompt. Returns
    /// true when the action may proceed now; false when it has been intercepted
    /// (the prompt is shown and the action deferred until the user chooses).
    mutating func guardDirty(_ action: DirtyAction) -> Bool {
        guard isDirty else { return true }
        savePromptAction = action
        savePromptMode = true
        needsRedraw = true
        return false
    }

    /// Write the in-memory source to disk and clear the dirty flag. Returns false
    /// if the write failed (the caller should keep the document open). A no-op
    /// (returns true) when there's nothing to save or no backing file.
    mutating func saveToDisk() -> Bool {
        guard isDirty, let url = currentURL else { return true }
        do {
            try rawSource.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            flash("save failed")
            return false
        }
        isDirty = false
        lastModDate = mtime(url)   // adopt our own write so pollReload won't reload
        flash("saved")
        return true
    }

    /// Handle a key while the unsaved-changes prompt is up. Returns true when the
    /// viewer should exit (the deferred action was "leave the viewer").
    mutating func handleSavePrompt(_ key: Terminal.Key) -> Bool {
        switch key {
        case .char("s"), .char("S"):
            savePromptMode = false
            guard saveToDisk() else { savePromptAction = nil; return false }
            return performDirtyAction()
        case .char("d"), .char("D"):
            isDirty = false            // discard the in-memory edits
            savePromptMode = false
            return performDirtyAction()
        case .char("c"), .char("C"), .escape:
            savePromptMode = false
            savePromptAction = nil
            needsRedraw = true
            return false
        default:
            needsRedraw = true
            return false
        }
    }

    /// Carry out the action that was deferred by the prompt. Returns true when it
    /// means leaving the viewer. By now `isDirty` is false, so the re-entrant
    /// navigate/goBack/activate calls proceed without re-prompting.
    private mutating func performDirtyAction() -> Bool {
        let action = savePromptAction
        savePromptAction = nil
        needsRedraw = true
        switch action {
        case .leaveViewer:
            return true
        case .switchTab(let i):
            if i < tabs.count { snapshot(); activate(i) }
            return false
        case .closeTab:
            _ = closeActiveTab()
            return false
        case .navigate(let url, let query):
            navigate(to: url, query: query)
            return false
        case .goBack:
            goBack()
            return false
        case nil:
            return false
        }
    }
}
