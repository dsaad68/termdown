import Foundation
import termdownCore

extension Pager {

    // MARK: - Incremental search input

    /// Abandon an incremental search: drop the query with its highlights and put
    /// the viewport back where `/` was pressed. Shared with the mouse path, so a
    /// click that dismisses the prompt means the same thing Escape does.
    mutating func cancelSearch() {
        searchMode = false
        searchQuery = ""; searchMatches = []; currentMatchIndex = 0
        top = searchOrigin
    }

    mutating func cancelGoto() {
        gotoMode = false; gotoInput = ""
    }

    mutating func handleSearchMode(_ key: Terminal.Key) {
        switch key {
        case .escape:
            cancelSearch()
        case .enter:
            searchMode = false
            if !searchMatches.isEmpty {
                centerTop(on: searchMatches[currentMatchIndex].lineIndex, viewport: contentRows)
            }
        case .backspace:
            if !searchQuery.isEmpty { searchQuery.removeLast() }
            runIncremental(viewport: contentRows)
        case .char(let c):
            if c.isASCII && c != "\n" && c != "\r" {
                searchQuery.append(c)
                runIncremental(viewport: contentRows)
            }
        default:
            break
        }
    }

    // MARK: - Goto-line input

    mutating func handleGotoMode(_ key: Terminal.Key) {
        switch key {
        case .escape:
            cancelGoto()
        case .backspace:
            if !gotoInput.isEmpty { gotoInput.removeLast() }
        case .enter:
            if let n = Int(gotoInput), n >= 1 {
                setCursor(max(0, min(n - 1, lines.count - 1)))
            }
            gotoMode = false; gotoInput = ""
        case .char(let c) where c.isNumber:
            gotoInput.append(c)
        default:
            break
        }
    }

    // MARK: - Theme picker (live preview + save)

    mutating func handleThemePicker(_ key: Terminal.Key) {
        let names = Theme.all.map { $0.name }
        switch key {
        case .up, .char("k"):
            themePickerSel = (themePickerSel - 1 + names.count) % names.count
            applyThemePreview(names[themePickerSel])
        case .down, .char("j"):
            themePickerSel = (themePickerSel + 1) % names.count
            applyThemePreview(names[themePickerSel])
        case .enter:
            currentThemeName = names[themePickerSel]
            onSaveTheme?(currentThemeName)
            themePickerMode = false
        case .escape, .char("q"):
            applyThemePreview(currentThemeName)   // restore the previously active theme
            themePickerMode = false
        default:
            break
        }
    }

    // MARK: - Mouse click → follow link

    /// Map a 1-based terminal click `(x, y)` to a link under the cursor and follow
    /// it. `y` selects the content row (`top + row`); `x` is mapped past the left
    /// chrome (sidebar or margin) and horizontal scroll into a content column,
    /// then matched against each link's `[column, column+length)` span.
    mutating func handleClick(x: Int, y: Int) {
        let row = y - 1
        guard row >= 0, row < contentRows else { return }   // ignore the status bar / gutter
        let lineIndex = top + row
        let contentCol = (x - 1) - chromeLeft + hscroll
        guard contentCol >= 0 else { return }               // a click in the sidebar/margin
        if let i = links.firstIndex(where: {
            $0.lineIndex == lineIndex && contentCol >= $0.column && contentCol < $0.column + $0.length
        }) {
            linkFocus = i
            openFocusedLink(inNewTab: false)
        }
    }

    /// Swap the active theme and force the document to re-render with it.
    mutating func applyThemePreview(_ name: String) {
        onPreviewTheme?(name)
        currentRenderWidth = -1   // make reflowIfNeeded re-render with the new theme
    }

    /// Picker rows: the theme names, with the saved one marked by a dot.
    func themePickerItems() -> [String] {
        Theme.all.map { ($0.name == currentThemeName ? "\u{25CF} " : "  ") + $0.name }
    }

    // MARK: - Sidebar focus mode (j/k/arrows navigate headings, Enter jumps)

    mutating func handleSidebarFocus(_ key: Terminal.Key) {
        switch key {
        case .up, .char("k"):
            sidebarCursor = max(0, sidebarCursor - 1)
        case .down, .char("j"):
            sidebarCursor = min(headings.count - 1, sidebarCursor + 1)
        case .pageUp:
            sidebarCursor = max(0, sidebarCursor - contentRows)
        case .pageDown:
            sidebarCursor = min(headings.count - 1, sidebarCursor + contentRows)
        case .home, .char("g"):
            sidebarCursor = 0
        case .end, .char("G"):
            sidebarCursor = max(0, headings.count - 1)
        case .enter:
            // Jump the document to the selected heading; stay focused.
            top = max(0, min(headings[sidebarCursor].lineIndex - Pager.scrolloff, maxTop))
        case .char("z"):
            // Fold/unfold the selected section; keep the cursor on it.
            if sidebarCursor < dispHeadingBaseIndex.count {
                let base = dispHeadingBaseIndex[sidebarCursor]
                if foldedHeadings.contains(base) { foldedHeadings.remove(base) }
                else { foldedHeadings.insert(base) }
                reapplyFolds()
                sidebarCursor = dispHeadingBaseIndex.firstIndex(of: base) ?? min(sidebarCursor, max(0, headings.count - 1))
                let anchor = baseHeadings[base].lineIndex
                if anchor < baseToDisp.count, baseToDisp[anchor] >= 0 {
                    top = max(0, min(baseToDisp[anchor] - Pager.scrolloff, max(0, lines.count - contentRows)))
                }
            }
        case .char("q"), .char("Q"):
            // Close the sidebar outright (Esc just steps out of focus).
            sidebarOn = false; sidebarFocus = false
            currentRenderWidth = -1   // sidebar gone -> content reflows wider
        case .escape, .char("s"), .char("S"):
            sidebarFocus = false
        default:
            break
        }
    }

    // MARK: - Main key handling

    /// Handle a key in the normal viewer mode. Returns `true` when the viewer
    /// should exit back to the file list.
    mutating func handleKey(_ key: Terminal.Key) -> Bool {
        // Apply user key rebindings (config `key-<action>`): translate a bound key
        // to its action's canonical key before dispatch. Only normal viewer keys
        // are remapped — text-entry modes are handled before this is reached.
        var key = key
        if case .char(let c) = key, let canonical = keyTranslation[c] {
            key = .char(canonical)
        }
        dropTextSelection(unless: key)
        switch key {
        case .up, .char("k"):
            navUp(1)
        case .down, .char("j"):
            navDown(1)
        case .shiftUp, .char("K"):
            extendSelection(by: -1)
        case .shiftDown, .char("J"):
            extendSelection(by: 1)
        case .char("v"):
            cursorVisible.toggle()
            if !cursorVisible { clearSelection() }
        case .left, .char("h"):
            hscroll = max(0, hscroll - Pager.hStep)
        case .right, .char("l"):
            hscroll = min(maxHscroll, hscroll + Pager.hStep)
        case .mouseScroll(let delta):
            top = max(0, min(maxTop, top + delta))   // cursor follows via clampCursorToView()
        case .mouseClick, .mouseDrag, .mouseRelease:
            handleMouseButton(key)
        case .pageDown, .char(" "), .char("f"):
            navDown(contentRows)
        case .pageUp, .char("b"):
            navUp(contentRows)
        case .char("d"):
            navDown(contentRows / 2)
        case .char("u"):
            navUp(contentRows / 2)
        case .home, .char("g"):
            navTop()
        case .end, .char("G"):
            navBottom()
        case .ctrlS:
            _ = saveToDisk()
        case .char("q"), .char("Q"), .char("c"), .escape:
            // Peel back one layer at a time: cursor/selection mode → outline
            // sidebar → extra tab → leave the viewer for the file list.
            if cursorVisible {
                cursorVisible = false; clearSelection()
            } else if sidebarOn {
                sidebarOn = false; sidebarFocus = false
                currentRenderWidth = -1   // sidebar gone -> content reflows wider
            } else if tabs.count > 1 {
                if guardDirty(.closeTab) { _ = closeActiveTab() }
            } else if guardDirty(.leaveViewer) {
                return true
            }
        case .char("/"):
            searchMode = true
            searchQuery = ""; searchMatches = []; currentMatchIndex = 0
            searchOrigin = top
        case .char("n"):
            jumpToMatch(1, viewport: contentRows)
        case .char("N"):
            jumpToMatch(-1, viewport: contentRows)
        case .char("\\"):
            if let onProjectSearch = onProjectSearch, let result = onProjectSearch() {
                navigate(to: result.url, query: result.query)
            }
        case .tab:
            if !links.isEmpty {
                let idx = ((linkFocus ?? -1) + 1) % links.count
                linkFocus = idx
                ensureVisible(links[idx].lineIndex, viewport: contentRows)
            }
        case .backTab:
            if !links.isEmpty {
                let idx = ((linkFocus ?? 0) - 1 + links.count) % links.count
                linkFocus = idx
                ensureVisible(links[idx].lineIndex, viewport: contentRows)
            }
        case .enter, .char("o"):
            openFocusedLink(inNewTab: false)
        case .shiftEnter, .char("O"):
            // Open the focused Markdown link in a new tab. `O` is the reliable
            // alias for terminals that send the same bytes for Enter/Shift+Enter.
            openFocusedLink(inNewTab: true)
        case .backspace:
            goBack()
        case .char("T"):
            // Open the file finder and load the picked document in a new tab.
            if let onNewTab = onNewTab {
                if let url = onNewTab() { openInNewTab(url) }
                // The finder showed the cursor and drew its own box; a full pager
                // redraw overwrites every row (render clears below), so no flashy
                // screen-clear is needed on the way back.
                Terminal.hideCursor()
                needsRedraw = true
            }
        case .char(let d) where d >= "1" && d <= "9":
            let idx = Int(String(d))! - 1
            if idx < tabs.count, idx != activeTab, guardDirty(.switchTab(idx)) { snapshot(); activate(idx) }
        case .char("}"):
            if tabs.count > 1, guardDirty(.switchTab((activeTab + 1) % tabs.count)) {
                snapshot(); activate((activeTab + 1) % tabs.count)
            }
        case .char("{"):
            if tabs.count > 1, guardDirty(.switchTab((activeTab - 1 + tabs.count) % tabs.count)) {
                snapshot(); activate((activeTab - 1 + tabs.count) % tabs.count)
            }
        case .char("x"):
            if guardDirty(.closeTab) { _ = closeActiveTab() }
        case .char("s"), .char("S"):
            if sidebarOn && !sidebarFocus && sidebarActive {
                // Sidebar already visible → enter focus mode, seed cursor to current section.
                sidebarFocus = true
                sidebarCursor = headings.lastIndex { $0.lineIndex <= top + Pager.scrolloff } ?? 0
            } else {
                sidebarOn.toggle()
                sidebarFocus = false
                currentRenderWidth = -1   // available width changes -> reflow
            }
        case .char("w"):
            wrapOn.toggle()
            hscroll = 0
            currentRenderWidth = -1
        case .char("+"), .char("="):
            let base = widthOverride ?? available
            widthOverride = min(base + 4, available)
            if wrapOn { currentRenderWidth = -1 }
        case .char("-"), .char("_"):
            let base = widthOverride ?? available
            widthOverride = max(base - 4, 20)
            if wrapOn { currentRenderWidth = -1 }
        case .char("F"):
            followMode.toggle()
            if followMode { top = maxTop }
        case .char("B"):
            // Toggle heading banners: flip the renderer flag and re-render.
            bannerOn.toggle()
            onToggleHeadingBanners?(bannerOn)
            currentRenderWidth = -1
        case .char(":"):
            gotoMode = true; gotoInput = ""
        case .char("p"):
            // Open the theme selector (live preview + save). Needs the app hooks.
            if onPreviewTheme != nil {
                themePickerMode = true
                themePickerSel = Theme.all.firstIndex { $0.name == currentThemeName } ?? 0
                applyThemePreview(Theme.all[themePickerSel].name)
            }
        case .ctrlL:
            Terminal.clearScreen()   // force a full repaint from scratch
            needsRedraw = true
        case .char("?"):
            Terminal.showHelp(Terminal.pagerHelpGroups)
        case .char("t"):
            handleContentsOverlay()
        case .char("]"):
            if let h = headings.first(where: { $0.lineIndex > cursorLine }) {
                setCursor(h.lineIndex)
            }
        case .char("["):
            if let h = headings.last(where: { $0.lineIndex < cursorLine }) {
                setCursor(h.lineIndex)
            }
        case .char("y"):
            // With a live selection, `y` copies it as raw markdown; otherwise it
            // falls back to copying the nearest code block. A mouse text
            // selection is character-precise, so it re-copies as rendered text.
            if let sel = textSelection {
                copyTextSelection(sel)
            } else if cursorVisible, let sel = selectionRange() {
                copySelection(sel, asMarkdown: true)
            } else if let block = nearestCodeBlock(codeBlocks, top: top, rows: contentRows), !block.text.isEmpty {
                Terminal.copyToClipboard(block.text)
                let n = block.text.split(separator: "\n", omittingEmptySubsequences: false).count
                copyFlashMsg = "copied code · \(n) line\(n == 1 ? "" : "s")"
                copyFlashUntil = Date().addingTimeInterval(1.5)
            } else {
                copyFlashMsg = "no code block in view"
                copyFlashUntil = Date().addingTimeInterval(1.5)
            }
        case .char("Y"):
            // With a live selection, `Y` copies it as rendered text; otherwise it
            // falls back to copying the focused / nearest link URL.
            if let sel = textSelection {
                copyTextSelection(sel)
            } else if cursorVisible, let sel = selectionRange() {
                copySelection(sel, asMarkdown: false)
            } else if let i = linkFocus ?? firstVisibleLink(top: top, rows: contentRows), i < links.count {
                Terminal.copyToClipboard(links[i].url)
                copyFlashMsg = "copied link · \(Ansi.truncate(links[i].url, to: 40))"
                copyFlashUntil = Date().addingTimeInterval(1.5)
            } else {
                copyFlashMsg = "no link in view"
                copyFlashUntil = Date().addingTimeInterval(1.5)
            }
        case .char("z"):
            foldCurrentSection()
        case .char("Z"):
            foldAllToggle()
        case .char("e"):
            beginEdit()
        default:
            break
        }
        return false
    }
}
