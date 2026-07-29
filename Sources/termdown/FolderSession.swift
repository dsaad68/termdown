import Foundation
import termdownCore

/// Everything that needs a scanned folder: the file finder, project-wide grep,
/// wikilink resolution, new tabs, and opening a document in the pager.
///
/// A class because the pager's callbacks are escaping closures that have to see
/// — and mutate — the same `entries`/`menu`/`lastSelection` the picker loop
/// uses. This was previously top-level `main.swift` state that only existed
/// *after* the scan, which is precisely why a directly-opened file could not be
/// given folder features: `viewFile` closed over globals that did not exist yet.
final class FolderSession {
    private let root: URL
    private let env: AppEnvironment

    /// Built on first use. Opening a file directly must not pay for a recursive
    /// scan of its parent — for `termdown ~/notes.md` that is the whole home
    /// directory — before the document is on screen. Every folder feature is
    /// reached through a callback, so the scan can wait until one fires.
    private var scanned = false
    private var entries: [FileScanner.Entry] = []
    private var details: [String] = []
    private var menu = TerminalMenu(title: "termdown", items: [], details: [])
    private var grep = LiveGrep(entries: [])
    private var lastSelection = 0

    /// `announceScan` is set when the session was opened on a single file, so
    /// the first folder feature triggers the scan with the viewer already on
    /// screen. `termdown ~/notes.md` roots the session on the whole home
    /// directory, and walking it can take seconds — long enough that a silent
    /// freeze reads as a hang. The picker path scans before the alternate
    /// screen is up and needs no such notice.
    private let announceScan: Bool

    init(root: URL, env: AppEnvironment, announceScan: Bool = false) {
        self.root = root
        self.env = env
        self.announceScan = announceScan
    }

    // MARK: - Scanning

    /// Scan the folder (once), wire up the finder and grep, and start watching
    /// for changes.
    @discardableResult
    func scan() -> [FileScanner.Entry] {
        guard !scanned else { return entries }
        scanned = true

        if announceScan {
            Terminal.render(["", "  Scanning \(displayPath)\u{2026}", ""])
        }
        entries = FileScanner.scan(root: root, ignorePatterns: env.ignorePatterns)
        details = fileDetails(entries)

        menu = TerminalMenu(title: "termdown",
                            items: entries.map(\.relativePath),
                            details: details)
        menu.path = displayPath
        menu.mouseEnabled = env.mouseEnabled
        // `unowned` breaks the cycle: this closure is stored on `menu`, which is
        // a property of `self`. The process is short-lived so a leak would never
        // be noticed, which is exactly why it is worth spelling out.
        menu.onFolderChanged = { [unowned self] in
            refresh() ? (items: entries.map(\.relativePath), details: details) : nil
        }

        grep = LiveGrep(entries: entries.map { ($0.url, $0.relativePath) })
        grep.mouseEnabled = env.mouseEnabled

        // Watch the folder so newly added/removed files show up in the picker
        // without restarting termdown.
        FolderWatcher.start(root: root)
        return entries
    }

    var isEmpty: Bool { scan().isEmpty }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return root.path.hasPrefix(home)
            ? "~" + String(root.path.dropFirst(home.count))
            : root.path
    }

    /// Re-scan after `FolderWatcher` reports a change, syncing entries, details
    /// and grep only if the file list actually differs — an FSEvents firing can
    /// also be a same-file mtime touch with no list change.
    @discardableResult
    private func refresh() -> Bool {
        let rescanned = FileScanner.scan(root: root, ignorePatterns: env.ignorePatterns)
        guard rescanned.map(\.relativePath) != entries.map(\.relativePath) else { return false }
        entries = rescanned
        details = fileDetails(entries)
        grep.updateEntries(entries.map { ($0.url, $0.relativePath) })
        return true
    }

    // MARK: - Wikilinks

    /// Resolve a `[[wikilink]]` page name against the discovered files, matching
    /// by filename (with or without extension) or relative path, case
    /// insensitively.
    ///
    /// Static and pure so it can be tested without a folder on disk.
    static func resolveWikilink(_ name: String, in entries: [FileScanner.Entry]) -> URL? {
        let needle = name.lowercased()
        let needleStem = (needle as NSString).deletingPathExtension
        return entries.first { entry in
            let file = entry.url.lastPathComponent.lowercased()
            let stem = (file as NSString).deletingPathExtension
            let rel = entry.relativePath.lowercased()
            let relStem = (rel as NSString).deletingPathExtension
            return file == needle || stem == needleStem || rel == needle || relStem == needleStem
        }?.url
    }

    // MARK: - Viewing

    /// Open one document in the pager, which then handles in-app link and grep
    /// navigation. Returns when the user leaves the viewer.
    func view(_ url: URL, query: String? = nil) {
        var pager = Pager(title: url.lastPathComponent, lines: [])
        pager.fileURL = url
        pager.fixedWidth = env.width
        pager.mouseEnabled = env.mouseEnabled
        pager.mouseSelectEnabled = env.mouseSelectEnabled
        pager.initialQuery = query
        pager.keyTranslation = env.keyTranslation
        pager.renderFile = { [env] in env.render.renderFile($0, width: $1) }
        pager.renderText = { [env] in env.render.render($0, width: $1) }
        // Each of these forces the scan on first use, so a folder is only walked
        // when a folder feature is actually reached.
        pager.resolveWikilink = { FolderSession.resolveWikilink($0, in: self.scan()) }
        pager.onProjectSearch = {
            self.scan()
            return self.grep.run()
        }
        pager.onNewTab = { self.pickForNewTab() }
        // Theme selector (`p`): preview swaps the active theme live; save persists it.
        pager.currentThemeName = env.render.themeName
        pager.onPreviewTheme = { [env] in env.render.previewTheme($0) }
        pager.onSaveTheme = { [env] in env.render.saveTheme($0) }
        pager.bannerOn = env.render.headingBanners
        pager.onToggleHeadingBanners = { [env] in env.render.headingBanners = $0 }
        pager.run()
    }

    /// Reuse the file finder (and grep) to choose a document for a new tab;
    /// `.quit` means the user cancelled, so no tab is opened. The "New tab"
    /// context swaps the launch wordmark for a slim header, so it reads as a
    /// picker rather than the app relaunching.
    private func pickForNewTab() -> URL? {
        scan()
        switch menu.run(initialSelection: lastSelection, context: "New tab") {
        case .open(let index):
            lastSelection = index
            return entries[index].url
        case .grep:
            return grep.run()?.url
        case .quit:
            return nil
        }
    }

    // MARK: - Picker loop

    /// Finder → viewer → finder, until the user quits.
    func runPicker() {
        scan()
        while true {
            switch menu.run(initialSelection: lastSelection) {
            case .quit:
                return
            case .open(let index):
                lastSelection = index
                view(entries[index].url)
            case .grep:
                if let result = grep.run() {
                    view(result.url, query: result.query)
                }
            }
        }
    }
}
