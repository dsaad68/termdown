import Foundation
import termdownCore

extension Pager {

    // MARK: - Document rendering & reload

    func mtime(_ url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    func renderCurrent(_ width: Int) -> RenderedDocument? {
        // Unsaved edits render from the in-memory source, not the file on disk.
        if isDirty, let rt = renderText { return rt(rawSource, width) }
        if let url = currentURL, let rf = renderFile { return rf(url, width) }
        if let rs = renderSource { return rs(width) }
        return nil
    }

    /// Re-render the current document when the target width changed (resize,
    /// wrap/width toggle, sidebar show/hide, navigation).
    mutating func reflowIfNeeded(renderWidth: Int) {
        guard renderWidth != currentRenderWidth else { return }
        if let doc = renderCurrent(renderWidth) {
            baseLines = doc.lines
            baseHeadings = doc.headings
            baseLinks = doc.links
            baseSourceSpans = doc.sourceSpans
            rawSource = doc.source
            foldedHeadings = foldedHeadings.filter { $0 < baseHeadings.count }
            reapplyFolds()
            if let lf = linkFocus, lf >= links.count { linkFocus = links.isEmpty ? nil : links.count - 1 }
            if !searchQuery.isEmpty { performSearch() }
        }
        currentRenderWidth = renderWidth
        needsRedraw = true
    }

    /// Apply a pending (initial / grep) query once the document is rendered.
    mutating func applyPendingQuery() {
        guard !pendingApplied else { return }
        pendingApplied = true
        // A [[Page#Heading]] jump deferred until the target document rendered.
        if let anchor = pendingAnchor {
            if let idx = headingIndex(forAnchor: "#" + anchor) {
                top = max(0, headings[idx].lineIndex - Pager.scrolloff)
            }
            pendingAnchor = nil
        }
        if let q = pendingQuery, !q.isEmpty {
            searchQuery = q
            performSearch()
            if !searchMatches.isEmpty {
                currentMatchIndex = 0
                centerTop(on: searchMatches[0].lineIndex, viewport: contentRows)
            }
        }
        pendingQuery = nil
        needsRedraw = true
    }

    /// Live-reload: reload when the current file's mtime advances. Suppressed while
    /// editing or holding unsaved changes so an external write can't clobber them.
    mutating func pollReload() {
        guard !editMode, !isDirty else { return }
        guard let url = currentURL, let lastMod = lastModDate,
              let newModDate = mtime(url), newModDate > lastMod else { return }
        if let doc = renderCurrent(currentRenderWidth) {
            baseLines = doc.lines
            baseHeadings = doc.headings
            baseLinks = doc.links
            baseSourceSpans = doc.sourceSpans
            rawSource = doc.source
            foldedHeadings.removeAll()   // heading indices may shift on edit
            reapplyFolds()
            if !searchQuery.isEmpty { performSearch() }
            let newMaxTop = max(0, lines.count - contentRows)
            top = followMode ? newMaxTop : min(top, newMaxTop)
        }
        lastModDate = newModDate
        reloadFlashUntil = Date().addingTimeInterval(1.5)
        needsRedraw = true
    }

    // MARK: - Search

    mutating func performSearch() {
        searchMatches = []
        currentMatchIndex = 0
        guard !searchQuery.isEmpty else { return }
        let lowerQuery = searchQuery.lowercased()
        for (lineIndex, line) in plainLines.enumerated() {
            let lowerLine = line.lowercased()
            var searchStart = lowerLine.startIndex
            while let range = lowerLine.range(of: lowerQuery, range: searchStart..<lowerLine.endIndex) {
                let lo = lowerLine.distance(from: lowerLine.startIndex, to: range.lowerBound)
                let hi = lowerLine.distance(from: lowerLine.startIndex, to: range.upperBound)
                searchMatches.append((lineIndex, lo..<hi))
                searchStart = range.upperBound
            }
        }
    }

    mutating func centerTop(on lineIndex: Int, viewport: Int) {
        let maxTop = max(0, plainLines.count - viewport)
        top = max(0, min(lineIndex - viewport / 2, maxTop))
    }

    mutating func ensureVisible(_ lineIndex: Int, viewport: Int) {
        if lineIndex < top + Pager.scrolloff || lineIndex >= top + viewport - Pager.scrolloff {
            let maxTop = max(0, plainLines.count - viewport)
            top = max(0, min(lineIndex - Pager.scrolloff, maxTop))
        }
    }

    // MARK: - Line cursor

    /// Move the line cursor by `delta` display rows.
    mutating func moveCursor(by delta: Int) { setCursor(cursorLine + delta) }

    /// Place the line cursor at `line`, scrolling the viewport to keep it visible
    /// with a scrolloff margin. At the scroll limits (short docs / the document
    /// ends) the cursor keeps moving inside the visible window, so every line stays
    /// reachable — this is the "anchor tracks scroll" model.
    mutating func setCursor(_ line: Int) {
        let last = max(0, lines.count - 1)
        cursorLine = max(0, min(last, line))
        let viewport = max(1, contentRows)
        let maxTopLocal = max(0, lines.count - viewport)
        let so = min(Pager.scrolloff, max(0, (viewport - 1) / 2))
        if cursorLine < top + so {
            top = cursorLine - so
        } else if cursorLine > top + viewport - 1 - so {
            top = cursorLine - viewport + 1 + so
        }
        top = max(0, min(top, maxTopLocal))
    }

    /// Clamp the line cursor into the current visible window. Called each frame so
    /// jumps that move `top` (search, heading nav, mouse scroll) pull the cursor
    /// along, and reflow/fold changes never leave it off-screen.
    mutating func clampCursorToView() {
        let last = max(0, lines.count - 1)
        cursorLine = max(0, min(cursorLine, last))
        if cursorLine < top { cursorLine = top }
        let lastVisible = min(top + contentRows - 1, last)
        if cursorLine > lastVisible { cursorLine = max(top, lastVisible) }
    }

    // MARK: - Cursor / selection mode

    /// Movement keys scroll the viewport while the cursor is hidden, and move the
    /// line cursor (clearing any selection) once it's shown.
    mutating func navDown(_ n: Int) {
        if cursorVisible { clearSelection(); moveCursor(by: n) } else { top = min(maxTop, top + n) }
    }

    mutating func navUp(_ n: Int) {
        if cursorVisible { clearSelection(); moveCursor(by: -n) } else { top = max(0, top - n) }
    }

    mutating func navTop() {
        if cursorVisible { clearSelection(); setCursor(0) } else { top = 0 }
    }

    mutating func navBottom() {
        if cursorVisible { clearSelection(); setCursor(max(0, lines.count - 1)) } else { top = maxTop }
    }

    mutating func clearSelection() { selectionAnchor = nil }

    /// Extend (or start) a line selection. Auto-enters cursor mode so Shift+arrows
    /// work straight from the scrolling view.
    mutating func extendSelection(by delta: Int) {
        cursorVisible = true
        if selectionAnchor == nil { selectionAnchor = cursorLine }
        moveCursor(by: delta)
    }

    /// The inclusive display-row range currently selected (the cursor's own line
    /// when there's no explicit anchor), or nil when the cursor is hidden.
    func selectionRange() -> ClosedRange<Int>? {
        guard cursorVisible else { return nil }
        let anchor = selectionAnchor ?? cursorLine
        let lo = min(anchor, cursorLine)
        let hi = max(anchor, cursorLine)
        guard lo >= 0, hi < lines.count else { return nil }
        return lo...hi
    }

    /// Copy the selected display rows — as raw markdown source, or as the rendered
    /// (ANSI-stripped) text — to the clipboard.
    mutating func copySelection(_ range: ClosedRange<Int>, asMarkdown: Bool) {
        let text = asMarkdown
            ? selectedMarkdown(range)
            : range.compactMap { $0 < plainLines.count ? plainLines[$0] : nil }.joined(separator: "\n")
        guard !text.isEmpty else { flash("nothing to copy"); return }
        Terminal.copyToClipboard(text)
        let n = range.count
        flash("copied \(n) line\(n == 1 ? "" : "s") · \(asMarkdown ? "markdown" : "text")")
        clearSelection()
    }

    /// The raw markdown source spanning a selected display range (the contiguous
    /// source lines its rows map to). Falls back to rendered text when the rows
    /// carry no source span (synthetic rows).
    func selectedMarkdown(_ range: ClosedRange<Int>) -> String {
        var lo = Int.max
        var hi = Int.min
        for d in range where d < dispSourceSpans.count {
            if let s = dispSourceSpans[d] { lo = min(lo, s.start); hi = max(hi, s.end) }
        }
        guard lo <= hi else {
            return range.compactMap { $0 < plainLines.count ? plainLines[$0] : nil }.joined(separator: "\n")
        }
        let srcLines = rawSource.components(separatedBy: "\n")
        let a = max(0, lo - 1)
        let b = min(srcLines.count - 1, hi - 1)
        guard a <= b else { return "" }
        return srcLines[a...b].joined(separator: "\n")
    }

    mutating func runIncremental(viewport: Int) {
        performSearch()
        guard !searchMatches.isEmpty else { return }
        if let i = searchMatches.firstIndex(where: { $0.lineIndex >= searchOrigin }) {
            currentMatchIndex = i
        } else {
            currentMatchIndex = 0
        }
        centerTop(on: searchMatches[currentMatchIndex].lineIndex, viewport: viewport)
    }

    mutating func jumpToMatch(_ direction: Int, viewport: Int) {
        guard !searchMatches.isEmpty else { return }
        if direction > 0 {
            currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        } else {
            currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        }
        centerTop(on: searchMatches[currentMatchIndex].lineIndex, viewport: viewport)
    }

    // MARK: - In-document navigation

    mutating func navigate(to url: URL, query: String?) {
        guard guardDirty(.navigate(url, query)) else { return }
        if let cur = currentURL { navStack.append(cur) }
        currentURL = url
        titleText = url.lastPathComponent
        currentRenderWidth = -1     // force reflow of the new document
        top = 0; hscroll = 0; linkFocus = nil; cursorLine = 0; cancelEdit()
        searchQuery = ""; searchMatches = []; currentMatchIndex = 0
        foldedHeadings.removeAll()
        lastModDate = mtime(url)
        pendingQuery = query
        pendingApplied = false
    }

    mutating func goBack() {
        guard let prev = navStack.last else { return }
        guard guardDirty(.goBack) else { return }
        navStack.removeLast()
        currentURL = prev
        titleText = prev.lastPathComponent
        currentRenderWidth = -1
        top = 0; hscroll = 0; linkFocus = nil; cursorLine = 0; cancelEdit()
        searchQuery = ""; searchMatches = []; currentMatchIndex = 0
        foldedHeadings.removeAll()
        lastModDate = mtime(prev)
        pendingQuery = nil
        pendingApplied = true
    }

    // MARK: - Tabs

    /// Snapshot the live runtime state into a `TabState`.
    func liveTabState() -> TabState {
        TabState(
            url: currentURL, navStack: navStack, title: titleText, top: top, hscroll: hscroll,
            wrapOn: wrapOn, widthOverride: widthOverride, followMode: followMode,
            sidebarOn: sidebarOn, sidebarFocus: sidebarFocus, sidebarCursor: sidebarCursor,
            searchQuery: searchQuery, linkFocus: linkFocus, foldedHeadings: foldedHeadings,
            lastModDate: lastModDate, cursorLine: cursorLine)
    }

    mutating func snapshot() {
        tabs[activeTab] = liveTabState()
    }

    mutating func activate(_ i: Int) {
        let t = tabs[i]
        activeTab = i
        currentURL = t.url; navStack = t.navStack; titleText = t.title
        top = t.top; hscroll = t.hscroll
        wrapOn = t.wrapOn; widthOverride = t.widthOverride; followMode = t.followMode
        sidebarOn = t.sidebarOn; sidebarFocus = t.sidebarFocus; sidebarCursor = t.sidebarCursor
        searchQuery = t.searchQuery; searchMatches = []; currentMatchIndex = 0
        linkFocus = t.linkFocus; foldedHeadings = t.foldedHeadings; lastModDate = t.lastModDate
        cursorLine = t.cursorLine
        searchMode = false; gotoMode = false; cancelEdit()
        currentRenderWidth = -1   // force reflow of the activated tab's document
        pendingApplied = true     // don't replay the initial query
    }

    /// Open `url` in a fresh tab, inheriting the current layout prefs (wrap,
    /// width, sidebar visibility) but with its own scroll / search / folds.
    mutating func openInNewTab(_ url: URL) {
        snapshot()
        tabs.append(TabState(
            url: url, navStack: [], title: url.lastPathComponent, top: 0, hscroll: 0,
            wrapOn: wrapOn, widthOverride: widthOverride, followMode: false,
            sidebarOn: sidebarOn, sidebarFocus: false, sidebarCursor: 0,
            searchQuery: "", linkFocus: nil, foldedHeadings: [], lastModDate: mtime(url),
            cursorLine: 0))
        activate(tabs.count - 1)
    }

    /// Follow the focused link, optionally into a new tab. In-app markdown
    /// links honour `inNewTab`; anchors and external URLs ignore it.
    mutating func openFocusedLink(inNewTab: Bool) {
        guard let lf = linkFocus, lf < links.count else { return }
        let url = links[lf].url
        if url.hasPrefix("wikilink:") {
            followWikilink(String(url.dropFirst("wikilink:".count)), inNewTab: inNewTab)
        } else if url.hasPrefix("#") {
            if let idx = headingIndex(forAnchor: url) {
                top = max(0, headings[idx].lineIndex - Pager.scrolloff)
            }
        } else if isExternalURL(url) {
            openExternal(url)
        } else if let base = currentURL?.deletingLastPathComponent(),
                  let target = resolveLink(url, base: base),
                  isMarkdownPath(target), FileManager.default.fileExists(atPath: target.path) {
            if inNewTab { openInNewTab(target) } else { navigate(to: target, query: nil) }
        } else {
            openExternal(url)
        }
    }

    /// Follow a `[[wikilink]]` destination of the form `Target#Heading`. An empty
    /// target is a same-document heading link; otherwise resolve the page name to
    /// a file and navigate, deferring any heading jump until it renders.
    mutating func followWikilink(_ spec: String, inNewTab: Bool) {
        let parts = spec.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let target = String(parts[0])
        let heading = parts.count > 1 ? String(parts[1]) : nil
        if target.isEmpty {
            if let h = heading, let idx = headingIndex(forAnchor: "#" + h) {
                top = max(0, headings[idx].lineIndex - Pager.scrolloff)
            }
            return
        }
        guard let dest = resolveWikilink?(target) else { return }   // unresolved → inert
        if inNewTab {
            openInNewTab(dest)
        } else {
            navigate(to: dest, query: nil)
            pendingAnchor = heading   // applied once the new doc renders
        }
    }

    /// Close the active tab. Returns false when it was the last tab (the caller
    /// should then leave the viewer for the file list).
    mutating func closeActiveTab() -> Bool {
        guard tabs.count > 1 else { return false }
        tabs.remove(at: activeTab)
        activate(min(activeTab, tabs.count - 1))
        return true
    }

    /// A two-pane overlay (driven by `t`): the document's outline (Contents) and
    /// the open documents (Open Tabs). `t` again cycles between the panes.
    mutating func handleContentsOverlay() {
        snapshot()   // so the Open Tabs list reflects the live state
        let contents = headings.map {
            String(repeating: "  ", count: max(0, $0.level - 1)) + $0.text
        }
        let openTabs = tabs.enumerated().map { (i, t) -> String in
            (i == activeTab ? "● " : "  ") + "\(i + 1)  " + (t.title.isEmpty ? "untitled" : t.title)
        }
        let panes = [(name: "Contents", items: contents),
                     (name: "Open Tabs", items: openTabs)]
        if let pick = Terminal.showTabbedOverlay(panes: panes, active: 0,
                      hint: "↑↓ select · t switch pane · Enter open · Esc close") {
            if pick.pane == 0 {
                top = max(0, headings[pick.item].lineIndex - Pager.scrolloff)
            } else if pick.item != activeTab {
                activate(pick.item)
            }
        }
    }
}
