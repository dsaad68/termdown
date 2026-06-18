import Foundation

/// Discovers markdown files recursively beneath a directory.
public enum FileScanner {

    public static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn", "mdx",
    ]

    public struct Entry {
        public let url: URL
        /// Path relative to the scanned root, used for display.
        public let relativePath: String
    }

    /// Recursively find markdown files under `root`, skipping hidden files and
    /// common noise directories (.git, node_modules, etc.). Results are sorted
    /// by relative path for stable display.
    ///
    /// `ignorePatterns` are additional directory or file name patterns to skip
    /// (simple substring match against the last path component).
    public static func scan(root: URL, ignorePatterns: [String] = []) -> [Entry] {
        let fm = FileManager.default
        var skipDirs: Set<String> = [
            ".git", "node_modules", ".build", "build", "Pods",
            ".venv", "venv", "__pycache__", ".next", "dist", "DerivedData",
        ]
        for p in ignorePatterns { skipDirs.insert(p) }

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let rootPath = root.standardizedFileURL.path
        var entries: [Entry] = []

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                if skipDirs.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values?.isRegularFile == true else { continue }
            guard markdownExtensions.contains(url.pathExtension.lowercased()) else { continue }

            let full = url.standardizedFileURL.path
            let rel: String
            if full.hasPrefix(rootPath + "/") {
                rel = String(full.dropFirst(rootPath.count + 1))
            } else {
                rel = url.lastPathComponent
            }
            entries.append(Entry(url: url, relativePath: rel))
        }

        entries.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        return entries
    }
}
