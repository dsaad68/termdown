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
    enum Mode: Equatable {
        case files, folders

        /// Resolve the `file-list-view` config value. Anything but an explicit
        /// `folders` — absent, misspelled, empty — is the file list, so a typo
        /// leaves the picker behaving the way it always has.
        init(configValue: String?) {
            self = configValue?.trimmingCharacters(in: .whitespaces).lowercased() == "folders"
                ? .folders : .files
        }
    }

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
        /// The `../` row. It is navigation rather than content, so it is left out
        /// of the header's count and never lands under the cursor on the way in.
        let isUp: Bool

        var isFolder: Bool { if case .folder = kind { return true }; return false }

        init(kind: RowKind, label: String, detail: String, isUp: Bool = false) {
            self.kind = kind
            self.label = label
            self.detail = detail
            self.isUp = isUp
        }
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
            // A narrowed list is standing inside a folder just as the browser is, so
            // it needs the same way back out — without this, the files of a leaf
            // folder were a room with no door for anyone using the mouse.
            var out: [Row] = []
            if !scope.isEmpty, let parent = FolderTree.parent(of: scope) {
                out.append(Row(kind: .folder(parent), label: "../", detail: "up", isUp: true))
            }
            return out + tree.fileIndices(under: scope).compactMap { index in
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
                out.append(Row(kind: .folder(parent), label: "../", detail: "up", isUp: true))
            }
            out += tree.children(of: cwd).map { folder in
                Row(kind: .folder(folder.path), label: folder.name + "/",
                    detail: "\(folder.fileCount) file" + (folder.fileCount == 1 ? "" : "s"))
            }
            return out
        }
    }

    /// The folder the list is standing in, split into components relative to the
    /// folder termdown was opened on. Empty at the root, where the drawing shows the
    /// opened folder's own name as the only crumb.
    ///
    /// The header keeps showing the opened path unchanged; this is *where inside it*
    /// you are, which is a different question and belongs in its own row.
    var breadcrumb: [String] {
        let shown = mode == .folders ? cwd : scope
        return shown.isEmpty ? [] : shown.split(separator: "/").map(String.init)
    }

    /// Whether the list area opens with a breadcrumb row. It sits above the rows,
    /// inside the bordered list, so it costs one of them.
    ///
    /// The browser always has one, the root included — it is the banner that says
    /// you are walking folders now, so it appears the moment `d` is pressed rather
    /// than one level in. The file list only earns one by being narrowed; unnarrowed
    /// it is the whole project, which the header already names.
    var showsBreadcrumbRow: Bool { mode == .folders || !scope.isEmpty }

    /// How many of the `viewport` rows are left for the list itself. The drawing and
    /// the loop's scroll/click arithmetic both go through this — a breadcrumb row
    /// counted in one and not the other puts every click one row out.
    func listRows(in viewport: Int) -> Int {
        max(1, viewport - (showsBreadcrumbRow ? 1 : 0))
    }

    /// Plural noun for the header count and the empty-list message.
    var noun: String { mode == .folders ? "folders" : "files" }

    /// Where the cursor should land after stepping *into* a folder: the first row
    /// that is not `../`. Landing on the up row pointed the cursor back the way you
    /// came, so Enter twice stepped in and straight back out again.
    func firstEntry(in rows: [Row]) -> Int {
        rows.firstIndex { !$0.isUp } ?? 0
    }

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
                // A folder row reached from the *file* list — its `../` — has to
                // switch lists as well as folders, or the click would change `cwd`
                // and leave the same files on screen.
                mode = .folders
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

    /// Up one level. False when there is nowhere to go — at the root, or in a file
    /// list that is not narrowed — so the caller leaves the selection where it is
    /// rather than flashing the same frame.
    ///
    /// From a narrowed file list, up means the browser at the level you chose the
    /// folder from: those files are "inside" that folder, and leaving them is the
    /// same gesture as leaving a folder in the browser.
    mutating func up() -> Bool {
        switch mode {
        case .folders:
            guard let parent = FolderTree.parent(of: cwd) else { return false }
            cwd = parent
        case .files:
            guard !scope.isEmpty, let parent = FolderTree.parent(of: scope) else { return false }
            cwd = parent
            mode = .folders
        }
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
