import Foundation
import termdownCore

extension Pager {

    /// A single open tab's source-of-truth state. The heavy derived arrays
    /// (rendered lines, headings, links, fold maps) are NOT stored — they are
    /// recomputed by forcing a reflow when a tab is activated, exactly as
    /// `navigate()` does for in-place document changes.
    struct TabState {
        var url: URL?
        var navStack: [URL]
        var title: String
        var top: Int
        var hscroll: Int
        var wrapOn: Bool
        var widthOverride: Int?
        var followMode: Bool
        var sidebarOn: Bool
        var sidebarFocus: Bool
        var sidebarCursor: Int
        var searchQuery: String
        var linkFocus: Int?
        var foldedHeadings: Set<Int>
        var lastModDate: Date?
    }

    /// A code block addressable for copy-to-clipboard: its line range in the
    /// (display) `lines` array plus the clean source text (ANSI + bar stripped).
    struct CodeBlockInfo {
        let range: Range<Int>
        let text: String
    }
}
