import Foundation
import termdownCore

/// A scrollable, full-screen viewer for pre-rendered ANSI lines.
///
/// `run()` drives the event loop; the per-document/runtime state below was
/// promoted from `run()` locals to stored properties so the navigation, tab,
/// search, fold, input and drawing logic could move into `Pager+*` files as
/// methods (sharing state through `self`) instead of nested closures.
struct Pager {

    // MARK: - Configuration (set by the caller before `run()`)

    var title: String
    var lines: [String]
    var headings: [HeadingInfo] = []
    var links: [LinkInfo] = []
    var fileURL: URL?

    /// Render a specific markdown file at a given content width. Used for the
    /// current document, live-reload, resize reflow, and in-app link/grep
    /// navigation. Returns nil if the file can't be read.
    var renderFile: ((URL, Int) -> RenderedDocument?)?

    /// Render fixed source (stdin) at a width, when there is no backing file.
    var renderSource: ((Int) -> RenderedDocument)?

    /// Render arbitrary markdown text at a width. Used to re-render in-memory
    /// (unsaved) edits without reading the file back from disk.
    var renderText: ((String, Int) -> RenderedDocument)?

    /// Launch the project-wide live-grep UI; returns a chosen file + query.
    var onProjectSearch: (() -> (url: URL, query: String)?)?

    /// Launch the file finder to open a document in a new tab; returns the chosen
    /// file URL, or nil if the user cancelled. Provided by the app (main.swift).
    var onNewTab: (() -> URL?)?

    /// Theme selector (`p`) hooks, provided by the app. `onPreviewTheme` swaps the
    /// active theme so the next render reflects it (used for live preview);
    /// `onSaveTheme` additionally persists the choice to the config file.
    var onPreviewTheme: ((String) -> Void)?
    var onSaveTheme: ((String) -> Void)?
    /// Toggle heading banners (`B`): the app flips the renderer flag so the next
    /// reflow re-renders headings as filled blocks.
    var onToggleHeadingBanners: ((Bool) -> Void)?
    /// Name of the theme currently in effect (seeds the picker, restored on cancel).
    var currentThemeName = "dark"

    /// Resolve a `[[wikilink]]` page name to a file URL among the discovered docs.
    /// Provided by the app (main.swift); nil targets render but don't navigate.
    var resolveWikilink: ((String) -> URL?)?

    /// User key → canonical key translation for rebindable viewer actions
    /// (built from `key-<action>` config; empty = defaults only).
    var keyTranslation: [Character: Character] = [:]

    /// A search query to apply immediately on open (e.g. from a grep result).
    var initialQuery: String?

    /// Explicit content width from `--width`.
    var fixedWidth: Int?

    /// Whether mouse scroll events are enabled.
    var mouseEnabled: Bool = false

    /// Whether drag-to-select is enabled (implies mouse tracking). Off by default
    /// because motion reporting takes click-drag away from the terminal's own
    /// text selection.
    var mouseSelectEnabled: Bool = false

    // MARK: - Layout chrome constants

    static let leftMargin = 2
    static let rightGutter = 2     // 1-col gap + 1-col scrollbar
    static let scrolloff = 3       // lines kept above a jump target
    static let sidebarWidth = 24
    static let minColsForSidebar = 60
    static let noWrapWidth = 100_000
    static let hStep = 8           // horizontal scroll step
    static let multiClickInterval = 0.4   // seconds; double/triple click window

    // MARK: - Runtime state (initialized in `run()`; see the doc comment above)

    // Scroll / redraw / geometry.
    var top = 0
    var hscroll = 0
    var needsRedraw = true
    var currentRenderWidth = -1
    var maxLineWidth = 0
    var lastRows = -1
    var lastCols = -1
    var contentRows = 0        // recomputed each loop iteration
    var available = 0
    var maxTop = 0
    var maxHscroll = 0
    var sidebarActive = false

    // Document / navigation.
    var currentURL: URL?
    var navStack: [URL] = []
    var titleText = ""
    var lastModDate: Date?
    var reloadFlashUntil: Date?

    // Layout toggles.
    var sidebarOn = false
    var sidebarFocus = false   // true = keyboard focus is in the sidebar
    var sidebarCursor = 0      // selected heading index when focused
    var wrapOn = true
    var widthOverride: Int?
    var followMode = false
    var bannerOn = false       // headings render as filled background blocks (toggle `B`)

    // Search.
    var plainLines: [String] = []
    var searchQuery = ""
    var searchMatches: [(lineIndex: Int, range: Range<Int>)] = []
    var currentMatchIndex = 0
    var searchMode = false
    var searchOrigin = 0

    // Link focus.
    var linkFocus: Int?

    // Base (unfolded) document + fold state. The display arrays
    // (self.lines/headings/links) are derived from these via reapplyFolds().
    var baseLines: [String] = []
    var baseHeadings: [HeadingInfo] = []
    var baseLinks: [LinkInfo] = []
    // Source-line mapping. `baseSourceSpans` is parallel to `baseLines`;
    // `dispSourceSpans` is parallel to the folded `lines`. `rawSource` is the exact
    // source string that produced the current view (used by the inline editor).
    var baseSourceSpans: [SourceSpan?] = []
    var dispSourceSpans: [SourceSpan?] = []
    var rawSource = ""
    var foldedHeadings = Set<Int>()        // folded heading indices (base space)
    var baseToDisp: [Int] = []             // base line → display line (-1 if hidden)
    var dispHeadingBaseIndex: [Int] = []   // display heading idx → base heading idx
    var codeBlocks: [CodeBlockInfo] = []   // yank-addressable code blocks (display space)
    var foldHiddenCount: [Int: Int] = [:]  // base heading idx → hidden line count

    // Line cursor: a highlighted "current line" (display-line index). Hidden by
    // default — `v` toggles cursor/selection mode; while shown, j/k move the
    // cursor (instead of scrolling) and it anchors selection and the editor.
    var cursorVisible = false
    var cursorLine = 0
    // Multi-line selection: when set, the selection spans the inclusive display
    // range between this anchor and `cursorLine`. Shift+arrows / Shift+J/K extend
    // it; a plain motion clears it.
    var selectionAnchor: Int?
    // Character-precise mouse selection (`mouse-select`). Independent of the
    // line selection above so the keyboard's `y`/`Y` behaviour is untouched.
    var textSelection: TextSelection?
    var dragAnchor: TextPoint?
    var dragMoved = false
    // Multi-click: a press within `multiClickInterval` on the same cell escalates
    // to word (2) then line (3) selection.
    var clickCount = 0
    var lastClickAt = Date.distantPast
    var lastClickPoint: TextPoint?
    // Edge autoscroll while a drag is held still: direction plus the last
    // reported pointer position, so the selection keeps extending.
    var autoScrollDir = 0
    var lastDragPoint: TextPoint?

    // Inline edit mode (activated by `e`): the cursor's block becomes an editable
    // raw-markdown field while the rest of the document stays rendered. On Enter
    // the change is written to the file; Esc cancels.
    var editMode = false
    var editFileSpan: SourceSpan?       // file-line range under edit (1-indexed, inclusive)
    var editDisplayStart = 0            // display row where the field is spliced in
    var editDisplayCount = 0            // number of display rows the field replaces
    var editBuffer: [String] = []       // raw source lines being edited
    var editCaretRow = 0                // caret line within editBuffer
    var editCaretCol = 0                // caret column within editBuffer[editCaretRow]
    // After a save re-renders the document, move the cursor back onto the block at
    // this 1-indexed source line (applied once the reflow lands).
    var pendingCursorSource: Int?

    // Unsaved-edit state. Inline edits update `rawSource` in memory and set
    // `isDirty`; the document then renders from memory until written with Ctrl-S.
    var isDirty = false
    // Save-confirmation prompt shown when leaving a document with unsaved changes.
    var savePromptMode = false
    var savePromptAction: DirtyAction?

    // Clipboard "copied" toast.
    var copyFlashUntil: Date?
    var copyFlashMsg = ""

    // Goto-line mode (activated by ':').
    var gotoMode = false
    var gotoInput = ""

    // Theme picker mode (activated by 'p'): live-previews as the selection moves.
    var themePickerMode = false
    var themePickerSel = 0

    // Pending query to apply after the next (re)render completes.
    var pendingQuery: String?
    var pendingApplied = false

    // Pending heading anchor (e.g. from [[Page#Heading]]) to jump to once the
    // freshly navigated document has rendered.
    var pendingAnchor: String?

    // Tabs. The live tab is whatever is in the runtime state above; `tabs` holds
    // the *other* tabs' saved state. snapshot() writes the live state into the
    // active slot before switching away; activate() loads a slot back.
    var tabs: [TabState] = []
    var activeTab = 0

    /// Display the content and block until the user exits (q / Esc).
    mutating func run() {
        Terminal.hideCursor()
        // `mouse-select` needs the pointer even when plain mouse mode is off, so
        // either setting turns tracking on; only the former asks for motion.
        let wantsMouse = mouseEnabled || mouseSelectEnabled
        if wantsMouse { Terminal.enableMouseTracking(drag: mouseSelectEnabled) }
        defer {
            if wantsMouse { Terminal.disableMouseTracking() }
            Terminal.showCursor()
        }

        // Initialize the runtime state from the configuration.
        currentURL = fileURL
        titleText = title
        widthOverride = fixedWidth
        plainLines = lines.map { Ansi.strip($0) }
        baseLines = lines
        baseHeadings = headings
        baseLinks = links
        pendingQuery = initialQuery
        lastModDate = currentURL.flatMap { mtime($0) }
        tabs = [liveTabState()]
        activeTab = 0

        while true {
            let size = Terminal.size()
            // The status bar is the only chrome row; with 2+ tabs it also carries
            // the tab strip on its left, so no extra row is reserved.
            contentRows = max(1, size.rows - 1)
            sidebarActive = sidebarOn && size.cols >= Pager.minColsForSidebar && !headings.isEmpty
            let chrome = sidebarActive ? (Pager.sidebarWidth + 2) : Pager.leftMargin
            available = max(20, size.cols - chrome - Pager.rightGutter)
            let renderWidth = wrapOn ? (widthOverride ?? available) : Pager.noWrapWidth

            if Terminal.didResize || size.cols != lastCols || size.rows != lastRows {
                Terminal.didResize = false
                lastCols = size.cols
                lastRows = size.rows
                needsRedraw = true
            }

            reflowIfNeeded(renderWidth: renderWidth)
            applyPendingCursor()
            applyPendingQuery()

            maxTop = max(0, lines.count - contentRows)
            if top > maxTop { top = maxTop; needsRedraw = true }
            maxHscroll = wrapOn ? 0 : max(0, maxLineWidth - available)
            if hscroll > maxHscroll { hscroll = maxHscroll; needsRedraw = true }
            clampCursorToView()   // keep the line cursor on-screen as scroll/fold change

            let now = Date()
            if let until = reloadFlashUntil, now >= until { reloadFlashUntil = nil; needsRedraw = true }
            if let until = copyFlashUntil, now >= until { copyFlashUntil = nil; needsRedraw = true }

            if needsRedraw {
                let strip = tabs.count >= 2 ? tabStrip(tabs, active: activeTab) : nil
                let frame = buildFrame(
                    top: top, contentRows: contentRows, cols: size.cols, maxTop: maxTop,
                    available: available, sidebarActive: sidebarActive, sidebarFocus: sidebarFocus,
                    sidebarCursor: sidebarCursor, wrapOn: wrapOn, hscroll: hscroll,
                    followMode: followMode, reloadFlashActive: reloadFlashUntil != nil, title: titleText,
                    searchQuery: searchQuery, searchMatches: searchMatches, currentMatchIndex: currentMatchIndex,
                    searchMode: searchMode, gotoMode: gotoMode, gotoInput: gotoInput, linkFocus: linkFocus,
                    copyFlash: copyFlashUntil != nil ? copyFlashMsg : nil, tabStrip: strip)
                Terminal.render(frame)
                // The theme picker floats over the live-previewed document.
                if themePickerMode {
                    Terminal.paintList(title: "Theme", items: themePickerItems(),
                                       selected: themePickerSel,
                                       hint: "\u{2191}\u{2193} preview · \u{21B5} save · Esc cancel")
                }
                needsRedraw = false
            }

            pollReload()

            // On idle, keep a held-at-the-edge drag scrolling: the terminal only
            // reports motion when the pointer actually moves.
            guard let key = Terminal.readKey(timeoutMs: 100) else { tickAutoScroll(); continue }
            needsRedraw = true

            // Mouse events reach the modal handlers first; each keyboard handler
            // below would otherwise swallow them in its `default` branch.
            if handleModalMouse(key) { continue }

            if editMode { handleEditMode(key); continue }
            if savePromptMode { if handleSavePrompt(key) { return }; continue }
            if searchMode { handleSearchMode(key); continue }
            if gotoMode { handleGotoMode(key); continue }
            if themePickerMode { handleThemePicker(key); continue }
            if sidebarFocus && sidebarActive { handleSidebarFocus(key); continue }
            if handleKey(key) { return }   // true => leave the viewer for the file list
        }
    }
}
