import Foundation
import termdownCore

/// What the file picker is currently listing, and where in the folder hierarchy
/// it is standing.
///
/// Split out from `TerminalMenu` as a plain value with no terminal in sight: the
/// navigation is a small state machine (descend, up, switch list, narrow to a
/// folder) and testing it through `run()` would need a TTY and a key stream.
struct MenuList {

    /// The two lists the picker can show. `files` is the recursive, fuzzy-filtered
    /// list termdown has always opened with; `folders` walks the hierarchy one
    /// level at a time.
    enum Mode: Equatable { case files, folders }

    /// What a row stands for. Hoisted out of `Row` rather than nested inside it
    /// so the type stays one level deep.
    enum RowKind: Equatable {
        /// A markdown file, by index into the scanned entries.
        case file(Int)
        /// A folder, by path relative to the scanned root.
        case folder(String)
    }

    /// One row of whichever list is showing.
    struct Row: Equatable {
        let kind: RowKind
        /// Text shown in the row — a path relative to the narrowed folder, or a
        /// folder name with a trailing `/`.
        let label: String
        /// Dimmed secondary column: an mtime for a file, a file count for a folder.
        let detail: String

        var isFolder: Bool { if case .folder = kind { return true }; return false }
    }

    /// A row as the picker shows it: the row itself plus the character positions
    /// the fuzzy filter matched, which the drawing highlights.
    struct Visible: Equatable {
        let row: Row
        let indices: [Int]
    }

    var mode: Mode = .files

    /// Folder the browser is standing in; `""` is the scanned root.
    var cwd = ""

    /// Folder the file list is narrowed to; `""` is every file. Set by leaving the
    /// browser, so `d`-navigate-`d` reads as "show me this folder's files".
    var scope = ""

    /// Where to put the browser back if the search box sends us to the file list
    /// and the query is then cleared.
    private var resumeFolders: (cwd: String, scope: String)?

    var tree = FolderTree(entries: [])

    /// Nothing to browse: the scan found no folders at all.
    var hasNoFolders: Bool { tree.isEmpty }

    // MARK: - Rows

    /// Build the rows for the current mode. `labels`/`details` are the full,
    /// root-relative file lists, indexed alike.
    func rows(labels: [String], details: [String]) -> [Row] {
        switch mode {
        case .files:
            return tree.fileIndices(under: scope).compactMap { index in
                guard index < labels.count else { return nil }
                // Shown relative to the folder we are narrowed to: repeating
                // `projects/notes/` on every row of a folder you just chose is
                // noise, and the fuzzy filter should match what is on screen.
                let label = scope.isEmpty
                    ? labels[index]
                    : String(labels[index].dropFirst(scope.count + 1))
                return Row(kind: .file(index), label: label,
                           detail: index < details.count ? details[index] : "")
            }
        case .folders:
            var out: [Row] = []
            if let parent = FolderTree.parent(of: cwd) {
                // A row for "up", so the way back is visible and clickable — the
                // keys for it (Backspace / ← / h) are not.
                out.append(Row(kind: .folder(parent), label: "../", detail: "up"))
            }
            out += tree.children(of: cwd).map { folder in
                Row(kind: .folder(folder.path), label: folder.name + "/",
                    detail: "\(folder.fileCount) file" + (folder.fileCount == 1 ? "" : "s"))
            }
            return out
        }
    }

    /// The folder shown after the root in the header, e.g. `/notes/projects`.
    var subPath: String {
        let shown = mode == .folders ? cwd : scope
        return shown.isEmpty ? "" : "/" + shown
    }

    /// Plural noun for the header count and the empty-list message.
    var noun: String { mode == .folders ? "folders" : "files" }

    /// The header's count: `8 files`, `3/8 files`, `1 folder`. Singular matters
    /// here because narrowing to one folder — or to one file — is the ordinary
    /// case now, not a rarity.
    func countText(shown: Int, total: Int) -> String {
        let noun = total == 1 ? String(noun.dropLast()) : noun
        return shown == total ? "\(total) \(noun)" : "\(shown)/\(total) \(noun)"
    }

    // MARK: - Navigation

    /// Act on Enter (or a second click). Returns the entry index to open, or nil
    /// when the row moved the list instead.
    ///
    /// A leaf folder hands you its files rather than an empty list: with only
    /// folders listed, descending into one that has none would otherwise be a
    /// dead end you have to back out of.
    mutating func activate(_ row: Row) -> Int? {
        switch row.kind {
        case .file(let index):
            return index
        case .folder(let path):
            resumeFolders = nil
            if path.isEmpty || !tree.children(of: path).isEmpty {
                cwd = path
            } else {
                cwd = path
                scope = path
                mode = .files
            }
            return nil
        }
    }

    /// Switch between the two lists. Leaving the browser narrows the file list to
    /// the folder you were standing in; entering it starts from that same folder,
    /// so the two keys are each other's inverse.
    mutating func toggleMode() {
        resumeFolders = nil
        switch mode {
        case .files:
            cwd = scope
            mode = .folders
        case .folders:
            scope = cwd
            mode = .files
        }
    }

    /// Up one level. False at the root, where there is nowhere to go — the caller
    /// leaves the selection where it is rather than flashing the same frame.
    mutating func up() -> Bool {
        guard mode == .folders, let parent = FolderTree.parent(of: cwd) else { return false }
        cwd = parent
        return true
    }

    /// The search box searches every file, so focusing it leaves the browser.
    /// Clearing the query puts it back where it was.
    mutating func searchAllFiles() {
        guard mode == .folders else { return }
        resumeFolders = (cwd: cwd, scope: scope)
        scope = ""
        mode = .files
    }

    /// Called when the filter is cleared: returns to the browser if the search box
    /// is what took us out of it. True when the list changed underneath.
    mutating func restoreAfterSearch() -> Bool {
        guard let resume = resumeFolders else { return false }
        resumeFolders = nil
        cwd = resume.cwd
        scope = resume.scope
        mode = .folders
        return true
    }

    /// Widen the file list back to the whole project. False when it already is —
    /// Esc then falls through to its next job rather than swallowing the key.
    mutating func clearScope() -> Bool {
        guard mode == .files, !scope.isEmpty else { return false }
        scope = ""
        return true
    }
}
