import XCTest
@testable import termdownCore

/// The framed card shared by code blocks and mermaid diagrams. Every row it
/// emits must be exactly the width it was given: autowrap is off in the viewer,
/// so an over-wide row pushes the frame's right border off-screen, and in the
/// pager it is fed to `Ansi.truncate`, which strips its styling entirely.
final class CodeCardTests: XCTestCase {
    private func renderer(_ width: Int) -> AnsiRenderer {
        AnsiRenderer(width: width, theme: .dark)
    }

    private func plainRender(_ md: String, width: Int) -> [String] {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = previous }
        return AnsiRenderer(width: width, theme: .dark).render(md).lines
    }

    // MARK: - The top rule carries arbitrary author text

    /// The card's label is the fence's info string, and a fence may legally
    /// carry a title, a filename, or highlighting directives. Unbounded, that
    /// text made the top rule wider than the card while every other row stayed
    /// exactly `width` — a broken frame, from ordinary markdown.
    func testTopRuleNeverExceedsTheWidthForALongInfoString() {
        let md = """
        ```json title="config/deployment/production-overrides.json" linenos
        {"a": 1}
        ```
        """
        for width in [20, 24, 40, 80, 120] {
            for (index, line) in plainRender(md, width: width).enumerated() {
                XCTAssertLessThanOrEqual(Ansi.width(line), width,
                                         "row \(index) overflowed at width \(width): \(line)")
            }
        }
    }

    /// Truncating the label must not cost the frame its corners.
    func testTruncatedHeaderStillClosesTheBox() {
        let md = """
        ```swift a-very-long-info-string-that-cannot-possibly-fit-in-the-card
        x
        ```
        """
        let top = plainRender(md, width: 30).first { $0.hasPrefix("\u{250C}") }
        let unwrapped = try? XCTUnwrap(top)
        XCTAssertEqual(Ansi.width(unwrapped ?? ""), 30)
        XCTAssertTrue((unwrapped ?? "").hasSuffix("\u{2510}"), "top rule lost its corner: \(unwrapped ?? "")")
        XCTAssertTrue((unwrapped ?? "").contains("\u{2026}"), "truncation should be marked: \(unwrapped ?? "")")
    }

    // MARK: - Narrow widths

    /// List indentation floors a nested block's content width at 4, which is
    /// less than the card's own chrome. The wrapper and the frame used to floor
    /// that differently, so the text was wrapped to fit and then sliced back to
    /// nothing — a card of pure ellipses. Below the frame's minimum the content
    /// is what matters, so the box is dropped rather than the text.
    func testTooNarrowToFrameKeepsTheContent() {
        for width in 1...4 {
            let rows = renderer(20).frameCard(label: "swift", bodyRows: ["ab", "cd"], width: width)
            XCTAssertEqual(rows.count, 2, "no border should be drawn at width \(width)")
            for row in rows {
                XCTAssertEqual(Ansi.width(row), width, "row is not exactly \(width): \(row)")
            }
        }
    }

    /// The smallest width that can still hold chrome plus one column.
    func testFiveColumnsIsEnoughToFrame() {
        let rows = renderer(20).frameCard(label: "swift", bodyRows: ["ab"], width: 5)
        XCTAssertEqual(rows.count, 3, "expected a top rule, one body row and a floor")
        for row in rows {
            XCTAssertEqual(Ansi.width(row), 5, "row is not exactly 5 columns: \(row)")
        }
    }

    /// A nested block must never come back empty.
    func testDeeplyNestedBlockStillShowsItsCode() {
        let md = """
        - a
          - b
            - c
              - d
                - e
                  - f
                    - g
                      - h

                        ```swift
                        let x = 42
                        ```
        """
        let rows = plainRender(md, width: 20)
        let body = rows.joined()
        XCTAssertTrue(body.contains("let"), "the code vanished:\n\(rows.joined(separator: "\n"))")
        XCTAssertTrue(body.contains("42"), "the code vanished:\n\(rows.joined(separator: "\n"))")
        for (index, row) in rows.enumerated() {
            XCTAssertLessThanOrEqual(Ansi.width(row), 20, "row \(index) overflowed: \(row)")
        }
    }

    // MARK: - The clipping marker

    /// `Ansi.horizontalSlice` substitutes a space for a double-width glyph the
    /// cut lands inside, so inspecting the sliced-off tail reported "only
    /// whitespace was lost" and the glyph was dropped with no marker — a card
    /// that looks complete while a character has been deleted from it.
    func testWideGlyphStraddlingTheEdgeIsMarked() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = previous }

        // inner = 16; the CJK glyph starts at column 15 and needs two columns.
        let row = String(repeating: "a", count: 15) + "\u{8A9E}"
        let card = renderer(20).frameCard(label: "", bodyRows: [row], width: 20)
        let body = Ansi.strip(card[1])

        XCTAssertEqual(Ansi.width(body), 20)
        XCTAssertFalse(body.contains("\u{8A9E}"), "a straddling glyph cannot be drawn")
        XCTAssertTrue(body.contains("\u{2026}"), "the loss must be marked: \(body)")
    }

    /// …and the marker still stays off rows whose overhang is only padding,
    /// which is what a mermaid canvas hands the card on most of its rows.
    func testPaddingOnlyOverhangIsStillUnmarked() {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = false
        defer { Ansi.colorEnabled = previous }

        let row = String(repeating: "a", count: 16) + "      "
        let card = renderer(20).frameCard(label: "", bodyRows: [row], width: 20)
        let body = Ansi.strip(card[1])

        XCTAssertEqual(Ansi.width(body), 20)
        XCTAssertFalse(body.contains("\u{2026}"), "only padding was cut: \(body)")
    }
}
