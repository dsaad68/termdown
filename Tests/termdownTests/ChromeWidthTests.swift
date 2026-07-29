import XCTest
@testable import termdown
@testable import termdownCore

/// Width invariants for the two pieces of chrome that had no coverage at all:
/// the modal overlays and project search. Autowrap is off, so a row wider than
/// the terminal clips at the right margin and takes the frame's border with it.
final class ChromeWidthTests: XCTestCase {

    // MARK: - Overlay geometry

    /// Every overlay row is drawn as `│ … │` plus a drop-shadow column, so the
    /// box plus its shadow must fit the screen. The shadow was never counted, so
    /// whenever the box hit its width cap every row came out `cols + 1` and the
    /// right border was clipped — in the help overlay that is the common case,
    /// not an edge case.
    func testOverlayBoxPlusShadowFitsTheScreen() {
        let items = ["a short one", String(repeating: "w", count: 200), "another entry"]
        let hints = ["", "Esc close", "Tab/\u{2192} switch \u{00B7} \u{2191}\u{2193} scroll \u{00B7} Esc close"]
        for cols in [20, 24, 30, 36, 40, 50, 60, 80, 120] {
            for hint in hints {
                for title in ["Help", "A rather long overlay title that will not fit"] {
                    let size = Terminal.Size(rows: 24, cols: cols, widthPx: 0, heightPx: 0)
                    let g = Terminal.listBoxGeometry(title: title, items: items, selected: 0,
                                                     hint: hint, size: size)
                    // +1 for the shadow column each row draws past the box.
                    XCTAssertLessThanOrEqual(
                        g.boxW + 1, cols,
                        "box \(g.boxW) + shadow exceeds \(cols) (title: '\(title)', hint: '\(hint)')")
                    XCTAssertGreaterThanOrEqual(g.startCol, 1)
                    XCTAssertLessThanOrEqual(g.startCol + g.boxW, cols + 1,
                                             "box runs past the right edge at \(cols)")
                }
            }
        }
    }

    /// The scroll counter is appended to the hint at paint time, so the box has
    /// to be sized with room for it — otherwise it is silently dropped at every
    /// width rather than merely overflowing at narrow ones.
    func testOverlayLeavesRoomForTheScrollCounter() {
        let themes = (1...28).map { "\u{25CF} theme-name-\($0)" }
        let hint = "\u{2191}\u{2193} preview \u{00B7} \u{21B5} save \u{00B7} Esc cancel"
        let size = Terminal.Size(rows: 24, cols: 100, widthPx: 0, heightPx: 0)
        let g = Terminal.listBoxGeometry(title: "Theme", items: themes, selected: 0,
                                         hint: hint, size: size)
        // "  12/28" is 7 columns; the budget allows 6 plus the hint itself.
        XCTAssertGreaterThanOrEqual(g.innerW, Ansi.width(hint) + 6,
                                    "no room for the scroll counter (innerW \(g.innerW))")
    }

    // MARK: - Project search

    private func hit(_ path: String, line: Int = 12, preview: String = "some matching text") -> LiveGrep.Hit {
        LiveGrep.Hit(url: URL(fileURLWithPath: "/root/\(path)"), relativePath: path,
                     lineNo: line, preview: preview)
    }

    /// `previewW` floored the preview at zero but never clamped the location, so
    /// a deep path plus a line number could exceed the terminal on its own — and
    /// the selected row wrapped it in `pad`, which cannot shrink.
    func testGrepResultRowsNeverExceedTheWidth() {
        let grep = LiveGrep(entries: [])
        let paths = [
            "a.md",
            "docs/guide.md",
            "docs/architecture/rendering/inline-flattener-and-friends.md",
            String(repeating: "deep/", count: 20) + "file.md",
        ]
        for cols in [20, 30, 40, 50, 80, 120] {
            for path in paths {
                for selected in [false, true] {
                    let row = grep.renderHit(hit(path, line: 123_456), selected: selected, cols: cols)
                    XCTAssertLessThanOrEqual(
                        Ansi.width(row), cols,
                        "row is \(Ansi.width(row)) at cols \(cols) (selected: \(selected)): \(Ansi.strip(row))")
                }
            }
        }
    }

    /// Eliding from the left keeps the filename, which identifies the hit far
    /// better than the repository root does.
    func testGrepElidesThePathFromTheLeft() {
        let grep = LiveGrep(entries: [])
        let row = Ansi.strip(grep.renderHit(hit("docs/architecture/rendering/inline-flattener.md"),
                                            selected: false, cols: 40))
        XCTAssertTrue(row.contains("inline-flattener.md") || row.contains("flattener.md"),
                      "the filename was the part cut: \(row)")
        XCTAssertLessThanOrEqual(Ansi.width(row), 40)
    }
}
