import Foundation

/// The folder hierarchy implied by a set of scanned markdown files.
///
/// Derived from `FileScanner.Entry.relativePath` rather than from a second walk
/// of the disk, which is what makes it free: the scan has already skipped hidden
/// files, `node_modules` and every `ignore-patterns` entry, so the tree inherits
/// all of that. It also means a folder exists here only if it *leads to* a
/// markdown file — browsing can never walk into a subtree with nothing to read
/// at the end of it.
public struct FolderTree {

    /// One folder in the tree, as the picker needs to draw and enter it.
    public struct Folder: Equatable {
        /// Path relative to the scanned root, e.g. `notes/projects`.
        public let path: String
        /// Last component, as shown in the list.
        public let name: String
        /// Markdown files beneath it, at any depth.
        public let fileCount: Int
        /// Whether entering it would show anything — a leaf folder is a dead end,
        /// so the picker takes you to its files instead of an empty list.
        public let hasSubfolders: Bool
    }

    /// Direct subfolders of each folder, keyed by folder path (`""` = the root).
    private var childrenOf: [String: [String]] = [:]

    /// Markdown files beneath each folder, at any depth.
    private var countOf: [String: Int] = [:]

    /// Indices into the entry list, grouped by the folder each file sits in.
    private var filesIn: [String: [Int]] = [:]

    public init(entries: [FileScanner.Entry]) {
        var seen: Set<String> = []
        for (index, entry) in entries.enumerated() {
            var parts = entry.relativePath.split(separator: "/").map(String.init)
            parts.removeLast()  // the filename itself

            // Register every ancestor once, then bump the count of each — a file
            // four levels down is "beneath" all four of them.
            var path = ""
            filesIn["", default: []].append(index)
            countOf["", default: 0] += 1
            for part in parts {
                let parent = path
                path = path.isEmpty ? part : path + "/" + part
                if seen.insert(path).inserted {
                    childrenOf[parent, default: []].append(path)
                }
                countOf[path, default: 0] += 1
            }
            if !path.isEmpty { filesIn[path, default: []].append(index) }
        }
    }

    /// Whether the scan turned up no folders at all — a flat project, where
    /// there is nothing to browse.
    public var isEmpty: Bool { childrenOf[""] == nil }

    /// Direct subfolders of `path` (`""` = the root), sorted the way the file
    /// list sorts names.
    public func children(of path: String) -> [Folder] {
        (childrenOf[path] ?? [])
            .map { child in
                Folder(path: child,
                       name: String(child.dropFirst(path.isEmpty ? 0 : path.count + 1)),
                       fileCount: countOf[child] ?? 0,
                       hasSubfolders: childrenOf[child] != nil)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Indices of the markdown files beneath `path`, at any depth, in scan order.
    /// `""` returns every file, so a cleared scope needs no special case.
    public func fileIndices(under path: String) -> [Int] {
        guard !path.isEmpty else { return filesIn[""] ?? [] }
        var out = filesIn[path] ?? []
        for child in childrenOf[path] ?? [] { out += fileIndices(under: child) }
        return out.sorted()
    }

    /// The folder holding `path`, or nil at the root. `""` has no parent.
    public static func parent(of path: String) -> String? {
        guard !path.isEmpty else { return nil }
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return String(path[path.startIndex ..< slash])
    }
}
